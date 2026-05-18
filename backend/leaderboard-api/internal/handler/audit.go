package handler

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"time"
)

// AuditHandler serves GET /api/admin/audit-logs.
type AuditHandler struct {
	db *sql.DB
}

func NewAuditHandler(db *sql.DB) *AuditHandler {
	return &AuditHandler{db: db}
}

func (h *AuditHandler) ListAuditLogs(w http.ResponseWriter, r *http.Request) {
	rows, err := h.db.QueryContext(r.Context(), `
		SELECT id, action, target_type, target_value, actor, metadata, created_at
		FROM audit_logs ORDER BY created_at DESC LIMIT 200`)
	if err != nil {
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to fetch audit logs")
		return
	}
	defer rows.Close()

	type auditRow struct {
		ID          int64      `json:"id"`
		Action      string     `json:"action"`
		TargetType  *string    `json:"target_type"`
		TargetValue *string    `json:"target_value"`
		Actor       string     `json:"actor"`
		Metadata    *string    `json:"metadata"`
		CreatedAt   time.Time  `json:"created_at"`
	}
	items := []auditRow{}
	for rows.Next() {
		var a auditRow
		if rows.Scan(&a.ID, &a.Action, &a.TargetType, &a.TargetValue, &a.Actor, &a.Metadata, &a.CreatedAt) == nil {
			items = append(items, a)
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "items": items})
}

// LogAudit is a fire-and-forget helper called by other handlers to record admin actions.
func LogAudit(db *sql.DB, action, targetType, targetValue, actor string, metadata any) {
	if db == nil {
		return
	}
	var metaStr *string
	if metadata != nil {
		if b, err := json.Marshal(metadata); err == nil {
			s := string(b)
			metaStr = &s
		}
	}
	var ttPtr, tvPtr *string
	if targetType != "" {
		ttPtr = &targetType
	}
	if targetValue != "" {
		tvPtr = &targetValue
	}
	_, err := db.Exec(`
		INSERT INTO audit_logs (action, target_type, target_value, actor, metadata)
		VALUES ($1, $2, $3, $4, $5)`,
		action, ttPtr, tvPtr, actor, metaStr)
	if err != nil {
		log.Printf("[audit] log error: %v", err)
	}
}
