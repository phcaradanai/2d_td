package handler

import (
	"database/sql"
	"encoding/json"
	"log"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"leaderboard/internal/config"
	"leaderboard/internal/model"
	"leaderboard/internal/ratelimit"
	"leaderboard/internal/service"
)

// Handler holds the DB and config needed by leaderboard endpoints.
type Handler struct {
	db       *sql.DB
	cfg      config.Config
	resolver *service.AccessResolver // optional; nil = no access checks
}

func New(db *sql.DB, cfg config.Config) *Handler {
	return &Handler{db: db, cfg: cfg}
}

// WithResolver attaches an access resolver for leaderboard validation.
func (h *Handler) WithResolver(r *service.AccessResolver) *Handler {
	h.resolver = r
	return h
}

// ---- request / response types ----

type submitReq struct {
	PlayerName      string                 `json:"player_name"`
	LevelID         string                 `json:"level_id"`
	WaveReached     int                    `json:"wave_reached"`
	Cleared         bool                   `json:"cleared"`
	LivesRemaining  int                    `json:"lives_remaining"`
	GoldRemaining   int                    `json:"gold_remaining"`
	InterestLevel   int                    `json:"interest_level"`
	RunTimeSeconds  int                    `json:"run_time_seconds"`
	Elements        map[string]interface{} `json:"elements"`
	ClientRunID     string                 `json:"client_run_id"`
	ClientCreatedAt int64                  `json:"client_created_at"`
	// Optional identity fields for access validation
	InstallID   string `json:"install_id,omitempty"`
	RuntimeID   string `json:"runtime_id,omitempty"`
	BuildID     string `json:"build_id,omitempty"`
}

type submitResp struct {
	OK    bool  `json:"ok"`
	Score int64 `json:"score"`
	Rank  int64 `json:"rank"`
}

type topItem struct {
	Rank           int64  `json:"rank"`
	PlayerName     string `json:"player_name"`
	LevelID        string `json:"level_id"`
	WaveReached    int    `json:"wave_reached"`
	Cleared        bool   `json:"cleared"`
	Score          int64  `json:"score"`
	LivesRemaining int    `json:"lives_remaining"`
	GoldRemaining  int    `json:"gold_remaining"`
	InterestLevel  int    `json:"interest_level"`
	RunTimeSeconds int    `json:"run_time_seconds"`
	CreatedAt      string `json:"created_at"`
}

type topResp struct {
	Items []topItem `json:"items"`
}

// ---- endpoints ----

func (h *Handler) Submit(w http.ResponseWriter, r *http.Request) {
	var req submitReq
	dec := json.NewDecoder(r.Body)
	if err := dec.Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid JSON")
		return
	}

	// Sanitize player name
	req.PlayerName = strings.TrimSpace(req.PlayerName)
	if req.PlayerName == "" {
		req.PlayerName = "Player"
	}
	if utf8.RuneCountInString(req.PlayerName) > 20 {
		req.PlayerName = string([]rune(req.PlayerName)[:20])
	}

	// Validate
	if strings.TrimSpace(req.LevelID) == "" {
		jsonError(w, http.StatusBadRequest, "level_id is required")
		return
	}
	if len(req.LevelID) > 64 {
		jsonError(w, http.StatusBadRequest, "level_id too long")
		return
	}

	// Access validation — if a resolver is attached, check leaderboard permission.
	if h.resolver != nil {
		identity := model.Identity{
			InstallID: strings.TrimSpace(req.InstallID),
			RuntimeID: strings.TrimSpace(req.RuntimeID),
			BuildID:   strings.TrimSpace(req.BuildID),
		}
		resolved, rerr := h.resolver.Resolve(r.Context(), identity)
		if rerr == nil {
			cfg := resolved.Config
			if !cfg.AllowLeaderboardSubmit {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusForbidden)
				json.NewEncoder(w).Encode(map[string]any{ //nolint:errcheck
					"ok": false,
					"error": map[string]string{
						"code":    "access_denied",
						"message": "Leaderboard submission is not allowed for this demo access.",
					},
				})
				return
			}
			if cfg.Mode != "full" && req.WaveReached > cfg.MaxWave {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusForbidden)
				json.NewEncoder(w).Encode(map[string]any{ //nolint:errcheck
					"ok": false,
					"error": map[string]string{
						"code":    "access_denied",
						"message": "Wave count exceeds demo limit.",
					},
				})
				return
			}
		}
	}

	// Clamp numeric fields
	maxWave := h.cfg.MaxLevel1Wave
	req.WaveReached = clamp(req.WaveReached, 0, maxWave)
	req.LivesRemaining = clamp(req.LivesRemaining, 0, 1<<20)
	req.GoldRemaining = clamp(req.GoldRemaining, 0, 1<<24)
	req.InterestLevel = clamp(req.InterestLevel, 0, 100)
	req.RunTimeSeconds = clamp(req.RunTimeSeconds, 0, 1<<24)

	score := calcScore(req.WaveReached, req.LivesRemaining, req.GoldRemaining,
		req.InterestLevel, req.Cleared, req.RunTimeSeconds, maxWave)

	// Dedup: if client_run_id was already stored, return existing result
	if req.ClientRunID != "" {
		var existingScore int64
		var existingID int64
		err := h.db.QueryRowContext(r.Context(),
			`SELECT id, score FROM leaderboard_scores WHERE client_run_id = $1`,
			req.ClientRunID,
		).Scan(&existingID, &existingScore)
		if err == nil {
			rank := h.rankFor(r, req.LevelID, existingScore)
			writeJSON(w, http.StatusOK, submitResp{OK: true, Score: existingScore, Rank: rank})
			return
		}
	}

	ip := ratelimit.ClientIP(r)
	if net.ParseIP(ip) == nil {
		ip = ""
	}
	ua := r.Header.Get("User-Agent")
	if len(ua) > 512 {
		ua = ua[:512]
	}

	elemJSON, _ := json.Marshal(req.Elements)
	if elemJSON == nil {
		elemJSON = []byte("{}")
	}

	var clientRunIDVal interface{} = nil
	if req.ClientRunID != "" {
		clientRunIDVal = req.ClientRunID
	}
	var clientCreatedAtVal interface{} = nil
	if req.ClientCreatedAt > 0 {
		clientCreatedAtVal = req.ClientCreatedAt
	}
	var ipVal interface{} = nil
	if ip != "" {
		ipVal = ip
	}

	var insertedID int64
	err := h.db.QueryRowContext(r.Context(), `
		INSERT INTO leaderboard_scores
			(player_name, level_id, wave_reached, cleared, score,
			 lives_remaining, gold_remaining, interest_level, run_time_seconds,
			 elements, client_run_id, client_created_at, ip_address, user_agent)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13::inet,$14)
		RETURNING id`,
		req.PlayerName, req.LevelID, req.WaveReached, req.Cleared, score,
		req.LivesRemaining, req.GoldRemaining, req.InterestLevel, req.RunTimeSeconds,
		string(elemJSON), clientRunIDVal, clientCreatedAtVal, ipVal, ua,
	).Scan(&insertedID)
	if err != nil {
		log.Printf("[submit] insert error: %v", err)
		jsonError(w, http.StatusInternalServerError, "failed to save score")
		return
	}

	rank := h.rankFor(r, req.LevelID, score)
	writeJSON(w, http.StatusOK, submitResp{OK: true, Score: score, Rank: rank})
}

func (h *Handler) GetTop(w http.ResponseWriter, r *http.Request) {
	levelID := strings.TrimSpace(r.URL.Query().Get("level_id"))
	if levelID == "" {
		levelID = "level_01"
	}

	limit := 50
	if ls := r.URL.Query().Get("limit"); ls != "" {
		if n, err := strconv.Atoi(ls); err == nil && n > 0 {
			limit = n
		}
	}
	if limit > 100 {
		limit = 100
	}

	rows, err := h.db.QueryContext(r.Context(), `
		SELECT
			player_name, level_id, wave_reached, cleared, score,
			lives_remaining, gold_remaining, interest_level, run_time_seconds,
			created_at
		FROM leaderboard_scores
		WHERE level_id = $1
		ORDER BY score DESC, wave_reached DESC, lives_remaining DESC,
		         run_time_seconds ASC, created_at ASC
		LIMIT $2`,
		levelID, limit,
	)
	if err != nil {
		log.Printf("[top] query error: %v", err)
		jsonError(w, http.StatusInternalServerError, "query failed")
		return
	}
	defer rows.Close()

	items := make([]topItem, 0, limit)
	var rank int64 = 1
	for rows.Next() {
		var it topItem
		var createdAt time.Time
		if err := rows.Scan(
			&it.PlayerName, &it.LevelID, &it.WaveReached, &it.Cleared, &it.Score,
			&it.LivesRemaining, &it.GoldRemaining, &it.InterestLevel, &it.RunTimeSeconds,
			&createdAt,
		); err != nil {
			log.Printf("[top] scan error: %v", err)
			continue
		}
		it.CreatedAt = createdAt.UTC().Format(time.RFC3339)
		it.Rank = rank
		items = append(items, it)
		rank++
	}
	if err := rows.Err(); err != nil {
		log.Printf("[top] rows error: %v", err)
	}

	writeJSON(w, http.StatusOK, topResp{Items: items})
}

// ---- helpers ----

func (h *Handler) rankFor(r *http.Request, levelID string, score int64) int64 {
	var rank int64
	err := h.db.QueryRowContext(r.Context(),
		`SELECT COUNT(*)+1 FROM leaderboard_scores WHERE level_id = $1 AND score > $2`,
		levelID, score,
	).Scan(&rank)
	if err != nil {
		return 0
	}
	return rank
}

func calcScore(wave, lives, gold, interest int, cleared bool, runTime, maxWave int) int64 {
	s := int64(wave)*10000 +
		int64(lives)*500 +
		int64(gold)*10 +
		int64(interest)*1000 -
		int64(runTime)
	if cleared && wave >= maxWave {
		s += 100000
	}
	if s < 0 {
		s = 0
	}
	return s
}

func clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

func jsonError(w http.ResponseWriter, code int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}
