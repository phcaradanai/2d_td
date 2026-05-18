package handler

import (
	"crypto/rand"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"leaderboard/internal/model"
	"leaderboard/internal/repository"
	"leaderboard/internal/service"
)

// TokenHandler handles access token management and game-client redemption.
type TokenHandler struct {
	db          *sql.DB
	runtimeRepo *repository.RuntimeRepository
	accessRepo  *repository.AccessRepository
	resolver    *service.AccessResolver
}

func NewTokenHandler(db *sql.DB, rr *repository.RuntimeRepository, ar *repository.AccessRepository, res *service.AccessResolver) *TokenHandler {
	return &TokenHandler{db: db, runtimeRepo: rr, accessRepo: ar, resolver: res}
}

// ListTokens handles GET /api/admin/tokens
func (h *TokenHandler) ListTokens(w http.ResponseWriter, r *http.Request) {
	rows, err := h.db.QueryContext(r.Context(), `
		SELECT token_code, name, description, profile_key, grant_target_type,
		       max_redemptions, per_install_limit, expires_at, is_active,
		       redemption_count, created_at
		FROM access_tokens ORDER BY created_at DESC LIMIT 200`)
	if err != nil {
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to list tokens")
		return
	}
	defer rows.Close()

	type tokenRow struct {
		TokenCode       string     `json:"token_code"`
		Name            string     `json:"name"`
		Description     string     `json:"description"`
		ProfileKey      *string    `json:"profile_key"`
		GrantTargetType string     `json:"grant_target_type"`
		MaxRedemptions  int        `json:"max_redemptions"`
		PerInstallLimit int        `json:"per_install_limit"`
		ExpiresAt       *time.Time `json:"expires_at"`
		IsActive        bool       `json:"is_active"`
		RedemptionCount int        `json:"redemption_count"`
		CreatedAt       time.Time  `json:"created_at"`
	}
	items := []tokenRow{}
	for rows.Next() {
		var t tokenRow
		if err := rows.Scan(&t.TokenCode, &t.Name, &t.Description, &t.ProfileKey,
			&t.GrantTargetType, &t.MaxRedemptions, &t.PerInstallLimit,
			&t.ExpiresAt, &t.IsActive, &t.RedemptionCount, &t.CreatedAt,
		); err == nil {
			items = append(items, t)
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "items": items})
}

// GenerateTokens handles POST /api/admin/tokens/generate
func (h *TokenHandler) GenerateTokens(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name               string           `json:"name"`
		Description        string           `json:"description"`
		Prefix             string           `json:"prefix"`
		Count              int              `json:"count"`
		ProfileKey         *string          `json:"profile_key"`
		OverrideJSON       *json.RawMessage `json:"override_json"`
		GrantTargetType    string           `json:"grant_target_type"`
		MaxRedemptions     int              `json:"max_redemptions"`
		PerInstallLimit    int              `json:"per_install_limit"`
		GrantDurationHours *int             `json:"grant_duration_hours"`
		StartsAt           *time.Time       `json:"starts_at"`
		ExpiresAt          *time.Time       `json:"expires_at"`
		IsActive           bool             `json:"is_active"`
	}
	req.IsActive = true
	req.Count = 1
	req.MaxRedemptions = 1
	req.PerInstallLimit = 1
	req.GrantTargetType = "install_id"

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apiError(w, http.StatusBadRequest, "invalid_json", "Invalid request body")
		return
	}
	if req.Count < 1 {
		req.Count = 1
	}
	if req.Count > 500 {
		req.Count = 500
	}
	prefix := strings.ToUpper(strings.TrimSpace(req.Prefix))
	if prefix == "" {
		prefix = "TKN"
	}

	var overrideStr *string
	if req.OverrideJSON != nil {
		s := string(*req.OverrideJSON)
		overrideStr = &s
	}

	generated := make([]string, 0, req.Count)
	for i := 0; i < req.Count; i++ {
		code := prefix + "-" + randomCode(8)
		_, err := h.db.ExecContext(r.Context(), `
			INSERT INTO access_tokens
				(token_code, name, description, profile_key, override_json,
				 grant_target_type, max_redemptions, per_install_limit,
				 grant_duration_hours, starts_at, expires_at, is_active)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
			ON CONFLICT (token_code) DO NOTHING`,
			code, req.Name, req.Description, req.ProfileKey, overrideStr,
			req.GrantTargetType, req.MaxRedemptions, req.PerInstallLimit,
			req.GrantDurationHours, req.StartsAt, req.ExpiresAt, req.IsActive,
		)
		if err != nil {
			log.Printf("[tokens.Generate] insert error: %v", err)
			continue
		}
		generated = append(generated, code)
	}

	LogAudit(h.db, "tokens_generated", "token", strings.Join(generated, ","), "admin",
		map[string]any{"count": len(generated), "profile_key": req.ProfileKey})

	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "tokens": generated})
}

// UpdateToken handles PATCH /api/admin/tokens/{token_code}
func (h *TokenHandler) UpdateToken(w http.ResponseWriter, r *http.Request) {
	code := r.PathValue("token_code")
	var req struct {
		IsActive  bool `json:"is_active"`
	}
	req.IsActive = true
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apiError(w, http.StatusBadRequest, "invalid_json", "Invalid request body")
		return
	}
	_, err := h.db.ExecContext(r.Context(),
		`UPDATE access_tokens SET is_active=$2 WHERE token_code=$1`, code, req.IsActive)
	if err != nil {
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to update token")
		return
	}
	LogAudit(h.db, "token_updated", "token", code, "admin", map[string]any{"is_active": req.IsActive})
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// DeleteToken handles DELETE /api/admin/tokens/{token_code} (soft disable)
func (h *TokenHandler) DeleteToken(w http.ResponseWriter, r *http.Request) {
	code := r.PathValue("token_code")
	_, err := h.db.ExecContext(r.Context(),
		`UPDATE access_tokens SET is_active=FALSE WHERE token_code=$1`, code)
	if err != nil {
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to disable token")
		return
	}
	LogAudit(h.db, "token_disabled", "token", code, "admin", nil)
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// GetTokenRedemptions handles GET /api/admin/tokens/{token_code}/redemptions
func (h *TokenHandler) GetTokenRedemptions(w http.ResponseWriter, r *http.Request) {
	code := r.PathValue("token_code")
	rows, err := h.db.QueryContext(r.Context(), `
		SELECT id, token_code, install_id, runtime_id, player_id, redeemed_at
		FROM token_redemptions WHERE token_code=$1 ORDER BY redeemed_at DESC LIMIT 200`, code)
	if err != nil {
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to fetch redemptions")
		return
	}
	defer rows.Close()

	type row struct {
		ID         int64      `json:"id"`
		TokenCode  string     `json:"token_code"`
		InstallID  string     `json:"install_id"`
		RuntimeID  *string    `json:"runtime_id"`
		PlayerID   *string    `json:"player_id"`
		RedeemedAt time.Time  `json:"redeemed_at"`
	}
	items := []row{}
	for rows.Next() {
		var rd row
		if rows.Scan(&rd.ID, &rd.TokenCode, &rd.InstallID, &rd.RuntimeID, &rd.PlayerID, &rd.RedeemedAt) == nil {
			items = append(items, rd)
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "items": items})
}

// RedeemToken handles POST /api/v1/game/token/redeem (public game client endpoint)
func (h *TokenHandler) RedeemToken(w http.ResponseWriter, r *http.Request) {
	var req struct {
		TokenCode string `json:"token_code"`
		InstallID string `json:"install_id"`
		RuntimeID string `json:"runtime_id"`
		PlayerID  string `json:"player_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apiError(w, http.StatusBadRequest, "invalid_json", "Invalid request body")
		return
	}
	req.TokenCode = strings.TrimSpace(strings.ToUpper(req.TokenCode))
	req.InstallID = strings.TrimSpace(req.InstallID)
	if req.TokenCode == "" || req.InstallID == "" {
		apiError(w, http.StatusBadRequest, "missing_field", "token_code and install_id are required")
		return
	}

	// Fetch token
	var tk struct {
		ProfileKey         *string
		OverrideJSON       *string
		GrantTargetType    string
		MaxRedemptions     int
		PerInstallLimit    int
		GrantDurationHours *int
		ExpiresAt          *time.Time
		IsActive           bool
		RedemptionCount    int
	}
	err := h.db.QueryRowContext(r.Context(), `
		SELECT profile_key, override_json, grant_target_type,
		       max_redemptions, per_install_limit, grant_duration_hours,
		       expires_at, is_active, redemption_count
		FROM access_tokens WHERE token_code=$1`, req.TokenCode,
	).Scan(&tk.ProfileKey, &tk.OverrideJSON, &tk.GrantTargetType,
		&tk.MaxRedemptions, &tk.PerInstallLimit, &tk.GrantDurationHours,
		&tk.ExpiresAt, &tk.IsActive, &tk.RedemptionCount)
	if err == sql.ErrNoRows {
		apiError(w, http.StatusNotFound, "invalid_token", "Token not found")
		return
	}
	if err != nil {
		apiError(w, http.StatusInternalServerError, "db_error", "Token lookup failed")
		return
	}
	if !tk.IsActive {
		apiError(w, http.StatusForbidden, "token_inactive", "Token is no longer active")
		return
	}
	if tk.ExpiresAt != nil && time.Now().After(*tk.ExpiresAt) {
		apiError(w, http.StatusForbidden, "token_expired", "Token has expired")
		return
	}
	if tk.RedemptionCount >= tk.MaxRedemptions {
		apiError(w, http.StatusForbidden, "token_exhausted", "Token redemption limit reached")
		return
	}
	// Per-install limit
	var perInstallCount int
	h.db.QueryRowContext(r.Context(),
		`SELECT COUNT(*) FROM token_redemptions WHERE token_code=$1 AND install_id=$2`,
		req.TokenCode, req.InstallID).Scan(&perInstallCount) //nolint:errcheck
	if perInstallCount >= tk.PerInstallLimit {
		apiError(w, http.StatusForbidden, "already_redeemed", "Token already redeemed for this install")
		return
	}

	// Calculate optional expiry for the access override
	var endsAt *time.Time
	if tk.GrantDurationHours != nil {
		t := time.Now().Add(time.Duration(*tk.GrantDurationHours) * time.Hour)
		endsAt = &t
	}

	// Apply access override to install
	targetType := tk.GrantTargetType
	targetValue := req.InstallID
	if targetType == "player_id" && req.PlayerID != "" {
		targetValue = req.PlayerID
	}

	if err := h.accessRepo.UpsertByTarget(r.Context(), targetType, targetValue,
		tk.ProfileKey, tk.OverrideJSON, 5, true); err != nil {
		log.Printf("[tokens.Redeem] UpsertByTarget: %v", err)
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to apply access")
		return
	}
	// Set ends_at if duration is set
	if endsAt != nil {
		h.db.ExecContext(r.Context(), //nolint:errcheck
			`UPDATE runtime_access_overrides SET ends_at=$2, updated_at=NOW()
			 WHERE target_type=$3 AND target_value=$4 AND is_active=TRUE
			 ORDER BY id DESC LIMIT 1`,
			nil, endsAt, targetType, targetValue)
	}

	// Record redemption
	_, err = h.db.ExecContext(r.Context(), `
		INSERT INTO token_redemptions (token_code, install_id, runtime_id, player_id)
		VALUES ($1,$2,$3,$4)`,
		req.TokenCode, req.InstallID, nilStr2(req.RuntimeID), nilStr2(req.PlayerID))
	if err != nil {
		log.Printf("[tokens.Redeem] record redemption: %v", err)
	}
	// Increment count
	h.db.ExecContext(r.Context(), //nolint:errcheck
		`UPDATE access_tokens SET redemption_count = redemption_count + 1 WHERE token_code=$1`,
		req.TokenCode)

	LogAudit(h.db, "token_redeemed", "token", req.TokenCode, req.InstallID,
		map[string]any{"install_id": req.InstallID, "runtime_id": req.RuntimeID})

	// Return resolved access
	identity := model.Identity{InstallID: req.InstallID, RuntimeID: req.RuntimeID, PlayerID: req.PlayerID}
	resolved, _ := h.resolver.Resolve(r.Context(), identity)

	var cfg *model.AccessConfig
	if resolved != nil {
		cfg = resolved.Config
	} else {
		cfg = model.DefaultDemoConfig()
	}

	profileKey := ""
	if tk.ProfileKey != nil {
		profileKey = *tk.ProfileKey
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":          true,
		"profile_key": profileKey,
		"access":      cfg,
	})
}

// ── helpers ───────────────────────────────────────────────────────────────────

func randomCode(n int) string {
	b := make([]byte, n)
	rand.Read(b) //nolint:errcheck
	const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	for i := range b {
		b[i] = chars[int(b[i])%len(chars)]
	}
	return fmt.Sprintf("%s-%s", string(b[:4]), string(b[4:]))
}

func nilStr2(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}
