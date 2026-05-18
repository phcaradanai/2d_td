package handler

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"leaderboard/internal/model"
	"leaderboard/internal/repository"
	"leaderboard/internal/service"
)

// AdminHandler serves the admin REST API.
type AdminHandler struct {
	runtimeRepo *repository.RuntimeRepository
	accessRepo  *repository.AccessRepository
	resolver    *service.AccessResolver
}

func NewAdminHandler(rr *repository.RuntimeRepository, ar *repository.AccessRepository, resolver *service.AccessResolver) *AdminHandler {
	return &AdminHandler{runtimeRepo: rr, accessRepo: ar, resolver: resolver}
}

// ── Runtimes ─────────────────────────────────────────────────────────────────

// ListRuntimes handles GET /api/admin/runtimes
func (h *AdminHandler) ListRuntimes(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	limit, _ := strconv.Atoi(q.Get("limit"))
	offset, _ := strconv.Atoi(q.Get("offset"))
	if limit <= 0 {
		limit = 50
	}

	items, total, err := h.runtimeRepo.List(r.Context(),
		q.Get("q"), q.Get("tag"), q.Get("mode"), limit, offset)
	if err != nil {
		log.Printf("[admin.ListRuntimes] %v", err)
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to list runtimes")
		return
	}

	type row struct {
		RuntimeID     string    `json:"runtime_id"`
		InstallID     string    `json:"install_id"`
		PlayerID      *string   `json:"player_id"`
		BuildID       string    `json:"build_id"`
		Platform      string    `json:"platform"`
		GameVersion   *string   `json:"game_version"`
		AccessMode    *string   `json:"access_mode"`
		ConfigVersion int       `json:"config_version"`
		ResolvedFrom  *string   `json:"resolved_from"`
		Tags          []string  `json:"tags"`
		LastSeenAt    time.Time `json:"last_seen_at"`
		CreatedAt     time.Time `json:"created_at"`
	}

	rows := make([]row, 0, len(items))
	for _, inst := range items {
		tags, _ := h.runtimeRepo.TagsForRuntime(r.Context(), inst)
		if tags == nil {
			tags = []string{}
		}
		rows = append(rows, row{
			RuntimeID:     inst.RuntimeID,
			InstallID:     inst.InstallID,
			PlayerID:      inst.PlayerID,
			BuildID:       inst.BuildID,
			Platform:      inst.Platform,
			GameVersion:   inst.GameVersion,
			AccessMode:    inst.AccessMode,
			ConfigVersion: inst.ConfigVersion,
			ResolvedFrom:  inst.ResolvedFrom,
			Tags:          tags,
			LastSeenAt:    inst.LastSeenAt,
			CreatedAt:     inst.CreatedAt,
		})
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"ok":    true,
		"items": rows,
		"total": total,
	})
}

// GetRuntime handles GET /api/admin/runtimes/{runtime_id}
func (h *AdminHandler) GetRuntime(w http.ResponseWriter, r *http.Request) {
	runtimeID := r.PathValue("runtime_id")
	if runtimeID == "" {
		apiError(w, http.StatusBadRequest, "missing_field", "runtime_id is required")
		return
	}

	inst, err := h.runtimeRepo.GetByRuntimeID(r.Context(), runtimeID)
	if err == sql.ErrNoRows {
		apiError(w, http.StatusNotFound, "not_found", "Runtime not found")
		return
	}
	if err != nil {
		log.Printf("[admin.GetRuntime] %v", err)
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to fetch runtime")
		return
	}

	tags, _ := h.runtimeRepo.TagsForRuntime(r.Context(), inst)
	if tags == nil {
		tags = []string{}
	}

	overrides, _ := h.accessRepo.OverridesForIdentity(r.Context(), inst.InstallID, inst.RuntimeID)

	identity := model.Identity{
		RuntimeID: inst.RuntimeID,
		InstallID: inst.InstallID,
	}
	if inst.PlayerID != nil {
		identity.PlayerID = *inst.PlayerID
	}
	resolved, _ := h.resolver.Resolve(r.Context(), identity)

	writeJSON(w, http.StatusOK, map[string]any{
		"ok":        true,
		"runtime":   inst,
		"tags":      tags,
		"overrides": overrides,
		"resolved":  resolved,
	})
}

// SetRuntimeAccess handles PATCH /api/admin/runtimes/{runtime_id}/access
func (h *AdminHandler) SetRuntimeAccess(w http.ResponseWriter, r *http.Request) {
	runtimeID := r.PathValue("runtime_id")
	h.setAccessFor(w, r, "runtime_id", runtimeID)
}

// SetInstallAccess handles PATCH /api/admin/installations/{install_id}/access
func (h *AdminHandler) SetInstallAccess(w http.ResponseWriter, r *http.Request) {
	installID := r.PathValue("install_id")
	h.setAccessFor(w, r, "install_id", installID)
}

func (h *AdminHandler) setAccessFor(w http.ResponseWriter, r *http.Request, targetType, targetValue string) {
	if targetValue == "" {
		apiError(w, http.StatusBadRequest, "missing_field", targetType+" is required")
		return
	}

	var req struct {
		ProfileKey   *string          `json:"profile_key"`
		OverrideJSON *json.RawMessage `json:"override_json"`
		Priority     int              `json:"priority"`
		IsActive     *bool            `json:"is_active"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apiError(w, http.StatusBadRequest, "invalid_json", "Invalid request body")
		return
	}
	if req.Priority <= 0 {
		req.Priority = 10
	}
	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	var overrideStr *string
	if req.OverrideJSON != nil {
		s := string(*req.OverrideJSON)
		overrideStr = &s
	}

	if err := h.accessRepo.UpsertByTarget(r.Context(),
		targetType, targetValue,
		req.ProfileKey, overrideStr,
		req.Priority, isActive,
	); err != nil {
		log.Printf("[admin.setAccessFor] %v", err)
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to set access")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"ok":           true,
		"target_type":  targetType,
		"target_value": targetValue,
		"is_active":    isActive,
	})
}

// ── Tags ──────────────────────────────────────────────────────────────────────

type tagReq struct {
	TargetType  string `json:"target_type"`
	TargetValue string `json:"target_value"`
	Tag         string `json:"tag"`
}

// AddTag handles POST /api/admin/tags
func (h *AdminHandler) AddTag(w http.ResponseWriter, r *http.Request) {
	var req tagReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apiError(w, http.StatusBadRequest, "invalid_json", "Invalid request body")
		return
	}
	req.Tag = strings.TrimSpace(strings.ToLower(req.Tag))
	if req.TargetType == "" || req.TargetValue == "" || req.Tag == "" {
		apiError(w, http.StatusBadRequest, "missing_field", "target_type, target_value, and tag are required")
		return
	}
	if err := h.runtimeRepo.AddTag(r.Context(), req.TargetType, req.TargetValue, req.Tag); err != nil {
		log.Printf("[admin.AddTag] %v", err)
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to add tag")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// RemoveTag handles DELETE /api/admin/tags
func (h *AdminHandler) RemoveTag(w http.ResponseWriter, r *http.Request) {
	var req tagReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apiError(w, http.StatusBadRequest, "invalid_json", "Invalid request body")
		return
	}
	if err := h.runtimeRepo.RemoveTag(r.Context(), req.TargetType, req.TargetValue, req.Tag); err != nil {
		log.Printf("[admin.RemoveTag] %v", err)
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to remove tag")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// ── Profiles ─────────────────────────────────────────────────────────────────

// ListProfiles handles GET /api/admin/access-profiles
func (h *AdminHandler) ListProfiles(w http.ResponseWriter, r *http.Request) {
	items, err := h.accessRepo.ListProfiles(r.Context())
	if err != nil {
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to list profiles")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "items": items})
}

// CreateProfile handles POST /api/admin/access-profiles
func (h *AdminHandler) CreateProfile(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ProfileKey string          `json:"profile_key"`
		Name       string          `json:"name"`
		ConfigJSON json.RawMessage `json:"config_json"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apiError(w, http.StatusBadRequest, "invalid_json", "Invalid request body")
		return
	}
	if req.ProfileKey == "" || req.Name == "" {
		apiError(w, http.StatusBadRequest, "missing_field", "profile_key and name are required")
		return
	}
	if err := h.accessRepo.CreateProfile(r.Context(), req.ProfileKey, req.Name, string(req.ConfigJSON)); err != nil {
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to create profile")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// UpdateProfile handles PATCH /api/admin/access-profiles/{profile_key}
func (h *AdminHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	profileKey := r.PathValue("profile_key")
	var req struct {
		Name       string          `json:"name"`
		ConfigJSON json.RawMessage `json:"config_json"`
		IsActive   bool            `json:"is_active"`
	}
	req.IsActive = true
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apiError(w, http.StatusBadRequest, "invalid_json", "Invalid request body")
		return
	}
	if err := h.accessRepo.UpdateProfile(r.Context(), profileKey, req.Name, string(req.ConfigJSON), req.IsActive); err != nil {
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to update profile")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// ── Overrides ─────────────────────────────────────────────────────────────────

// ListOverrides handles GET /api/admin/overrides
func (h *AdminHandler) ListOverrides(w http.ResponseWriter, r *http.Request) {
	items, err := h.accessRepo.ListOverrides(r.Context())
	if err != nil {
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to list overrides")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "items": items})
}

// UpdateOverride handles PATCH /api/admin/overrides/{id}
func (h *AdminHandler) UpdateOverride(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		apiError(w, http.StatusBadRequest, "invalid_id", "Invalid override ID")
		return
	}
	var req struct {
		ProfileKey   *string          `json:"profile_key"`
		OverrideJSON *json.RawMessage `json:"override_json"`
		Priority     int              `json:"priority"`
		IsActive     bool             `json:"is_active"`
	}
	req.IsActive = true
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apiError(w, http.StatusBadRequest, "invalid_json", "Invalid request body")
		return
	}
	if req.Priority <= 0 {
		req.Priority = 100
	}
	var overrideStr *string
	if req.OverrideJSON != nil {
		s := string(*req.OverrideJSON)
		overrideStr = &s
	}
	if err := h.accessRepo.UpdateOverride(r.Context(), id, req.ProfileKey, overrideStr, req.Priority, req.IsActive); err != nil {
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to update override")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// DeleteOverride handles DELETE /api/admin/overrides/{id} (soft delete)
func (h *AdminHandler) DeleteOverride(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		apiError(w, http.StatusBadRequest, "invalid_id", "Invalid override ID")
		return
	}
	if err := h.accessRepo.SoftDeleteOverride(r.Context(), id); err != nil {
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to delete override")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// ── helpers ───────────────────────────────────────────────────────────────────

func apiError(w http.ResponseWriter, code int, errCode, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]any{ //nolint:errcheck
		"ok": false,
		"error": map[string]string{
			"code":    errCode,
			"message": message,
		},
	})
}
