package handler

import (
	"database/sql"
	"log"
	"net/http"
	"time"
)

// DashboardHandler serves GET /api/admin/dashboard/summary.
type DashboardHandler struct {
	db *sql.DB
}

func NewDashboardHandler(db *sql.DB) *DashboardHandler {
	return &DashboardHandler{db: db}
}

type runtimeRow struct {
	RuntimeID   string    `json:"runtime_id"`
	InstallID   string    `json:"install_id"`
	PlayerID    *string   `json:"player_id"`
	BuildID     string    `json:"build_id"`
	Platform    string    `json:"platform"`
	AccessMode  *string   `json:"access_mode"`
	LastSeenAt  time.Time `json:"last_seen_at"`
}

type redemptionRow struct {
	TokenCode  string    `json:"token_code"`
	InstallID  string    `json:"install_id"`
	RedeemedAt time.Time `json:"redeemed_at"`
}

func (h *DashboardHandler) Summary(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	scalarInt := func(query string, args ...any) int {
		var n int
		if err := h.db.QueryRowContext(ctx, query, args...).Scan(&n); err != nil {
			log.Printf("[dashboard] scalar query error: %v (query: %s)", err, query)
		}
		return n
	}

	totalInstalls := scalarInt(`SELECT COUNT(DISTINCT install_id) FROM runtime_instances`)
	runtimeSessions := scalarInt(`SELECT COUNT(*) FROM runtime_instances`)
	active24h := scalarInt(`SELECT COUNT(DISTINCT install_id) FROM runtime_instances WHERE last_seen_at > NOW() - INTERVAL '24 hours'`)
	active7d := scalarInt(`SELECT COUNT(DISTINCT install_id) FROM runtime_instances WHERE last_seen_at > NOW() - INTERVAL '7 days'`)
	activeTokens := scalarInt(`SELECT COUNT(*) FROM access_tokens WHERE is_active = TRUE AND (expires_at IS NULL OR expires_at > NOW())`)
	totalRedemptions := scalarInt(`SELECT COUNT(*) FROM token_redemptions`)
	lbSubmissions := scalarInt(`SELECT COUNT(*) FROM leaderboard_scores`)

	// Mode breakdown
	modeRows, err := h.db.QueryContext(ctx, `
		SELECT COALESCE(access_mode,'unknown') AS mode, COUNT(DISTINCT install_id) AS cnt
		FROM runtime_instances
		GROUP BY access_mode`)
	modeBreakdown := map[string]int{}
	if err == nil {
		defer modeRows.Close()
		for modeRows.Next() {
			var mode string
			var cnt int
			if modeRows.Scan(&mode, &cnt) == nil {
				modeBreakdown[mode] = cnt
			}
		}
	}

	// Platform breakdown
	platRows, err := h.db.QueryContext(ctx, `
		SELECT COALESCE(platform,'unknown'), COUNT(DISTINCT install_id)
		FROM runtime_instances GROUP BY platform ORDER BY 2 DESC LIMIT 10`)
	platformBreakdown := map[string]int{}
	if err == nil {
		defer platRows.Close()
		for platRows.Next() {
			var k string
			var v int
			if platRows.Scan(&k, &v) == nil {
				platformBreakdown[k] = v
			}
		}
	}

	// Build breakdown
	buildRows, err := h.db.QueryContext(ctx, `
		SELECT COALESCE(build_id,'unknown'), COUNT(DISTINCT install_id)
		FROM runtime_instances GROUP BY build_id ORDER BY 2 DESC LIMIT 10`)
	buildBreakdown := map[string]int{}
	if err == nil {
		defer buildRows.Close()
		for buildRows.Next() {
			var k string
			var v int
			if buildRows.Scan(&k, &v) == nil {
				buildBreakdown[k] = v
			}
		}
	}

	// Recent installs
	recentInstalls := []runtimeRow{}
	riRows, err := h.db.QueryContext(ctx, `
		SELECT runtime_id, install_id, player_id, build_id, platform, access_mode, last_seen_at
		FROM runtime_instances ORDER BY created_at DESC LIMIT 10`)
	if err == nil {
		defer riRows.Close()
		for riRows.Next() {
			var row runtimeRow
			if riRows.Scan(&row.RuntimeID, &row.InstallID, &row.PlayerID,
				&row.BuildID, &row.Platform, &row.AccessMode, &row.LastSeenAt) == nil {
				recentInstalls = append(recentInstalls, row)
			}
		}
	}

	// Recent redemptions
	recentRedemptions := []redemptionRow{}
	rdRows, err := h.db.QueryContext(ctx, `
		SELECT token_code, install_id, redeemed_at
		FROM token_redemptions ORDER BY redeemed_at DESC LIMIT 10`)
	if err == nil {
		defer rdRows.Close()
		for rdRows.Next() {
			var row redemptionRow
			if rdRows.Scan(&row.TokenCode, &row.InstallID, &row.RedeemedAt) == nil {
				recentRedemptions = append(recentRedemptions, row)
			}
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"ok":                  true,
		"total_installs":      totalInstalls,
		"runtime_sessions":    runtimeSessions,
		"active_24h":          active24h,
		"active_7d":           active7d,
		"mode_breakdown":      modeBreakdown,
		"active_tokens":       activeTokens,
		"total_redemptions":   totalRedemptions,
		"leaderboard_submissions": lbSubmissions,
		"platform_breakdown":  platformBreakdown,
		"build_breakdown":     buildBreakdown,
		"recent_installs":     recentInstalls,
		"recent_redemptions":  recentRedemptions,
	})
}
