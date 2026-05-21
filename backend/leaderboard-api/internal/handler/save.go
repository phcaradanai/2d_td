package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"leaderboard/internal/repository"
)

type SaveHandler struct {
	saveRepo *repository.SaveRepository
}

func NewSaveHandler(saveRepo *repository.SaveRepository) *SaveHandler {
	return &SaveHandler{saveRepo: saveRepo}
}

// GetSave handles GET /api/v1/game/save?install_id=xxx
func (h *SaveHandler) GetSave(w http.ResponseWriter, r *http.Request) {
	installID := strings.TrimSpace(r.URL.Query().Get("install_id"))
	if installID == "" {
		apiError(w, http.StatusBadRequest, "missing_field", "install_id is required")
		return
	}
	if len(installID) > 64 {
		apiError(w, http.StatusBadRequest, "invalid_field", "install_id too long")
		return
	}

	save, err := h.saveRepo.Get(r.Context(), installID)
	if err != nil {
		log.Printf("[save.Get] db error: %v", err)
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to load save")
		return
	}
	if save == nil {
		writeJSON(w, http.StatusOK, map[string]any{"ok": true, "found": false})
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"ok":         true,
		"found":      true,
		"save_json":  save.SaveJSON,
		"updated_at": save.UpdatedAt.Unix(),
	})
}

// PutSave handles PUT /api/v1/game/save
func (h *SaveHandler) PutSave(w http.ResponseWriter, r *http.Request) {
	var req struct {
		InstallID string `json:"install_id"`
		SaveJSON  string `json:"save_json"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apiError(w, http.StatusBadRequest, "invalid_json", "Invalid request body")
		return
	}

	req.InstallID = strings.TrimSpace(req.InstallID)
	if req.InstallID == "" {
		apiError(w, http.StatusBadRequest, "missing_field", "install_id is required")
		return
	}
	if len(req.InstallID) > 64 {
		apiError(w, http.StatusBadRequest, "invalid_field", "install_id too long")
		return
	}
	if len(req.SaveJSON) > 131072 { // 128 KB cap
		apiError(w, http.StatusBadRequest, "invalid_field", "save_json too large")
		return
	}

	// Validate save_json is valid JSON
	var tmp any
	if err := json.Unmarshal([]byte(req.SaveJSON), &tmp); err != nil {
		apiError(w, http.StatusBadRequest, "invalid_json", "save_json must be valid JSON")
		return
	}

	if err := h.saveRepo.Upsert(r.Context(), req.InstallID, req.SaveJSON); err != nil {
		log.Printf("[save.Put] db error: %v", err)
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to save")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}
