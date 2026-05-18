package handler

import (
	"database/sql"
	"net/http"
	"time"

	"leaderboard/internal/model"
	"leaderboard/internal/repository"
	"leaderboard/internal/service"
)

// InstallHandler serves GET /api/admin/installs/{install_id}.
type InstallHandler struct {
	runtimeRepo *repository.RuntimeRepository
	accessRepo  *repository.AccessRepository
	resolver    *service.AccessResolver
}

func NewInstallHandler(rr *repository.RuntimeRepository, ar *repository.AccessRepository, res *service.AccessResolver) *InstallHandler {
	return &InstallHandler{runtimeRepo: rr, accessRepo: ar, resolver: res}
}

func (h *InstallHandler) GetInstall(w http.ResponseWriter, r *http.Request) {
	installID := r.PathValue("install_id")
	if installID == "" {
		apiError(w, http.StatusBadRequest, "missing_field", "install_id is required")
		return
	}

	// Get all runtime sessions for this install
	items, total, err := h.runtimeRepo.List(r.Context(), installID, "", "", 50, 0)
	if err != nil || total == 0 {
		if err == sql.ErrNoRows || total == 0 {
			apiError(w, http.StatusNotFound, "not_found", "Install not found")
		} else {
			apiError(w, http.StatusInternalServerError, "db_error", "Failed to fetch install")
		}
		return
	}

	// Latest runtime (first in list, ordered by last_seen DESC)
	latest := items[0]

	tags, _ := h.runtimeRepo.TagsForIdentity(r.Context(), installID, "", "")
	if tags == nil {
		tags = []string{}
	}

	overrides, _ := h.accessRepo.OverridesForIdentity(r.Context(), installID, latest.RuntimeID)

	identity := model.Identity{
		InstallID: installID,
		RuntimeID: latest.RuntimeID,
	}
	if latest.PlayerID != nil {
		identity.PlayerID = *latest.PlayerID
	}
	resolved, _ := h.resolver.Resolve(r.Context(), identity)

	type sessionRow struct {
		RuntimeID        string    `json:"runtime_id"`
		RuntimeSessionID string    `json:"runtime_session_id"`
		BuildID          string    `json:"build_id"`
		Platform         string    `json:"platform"`
		GameVersion      *string   `json:"game_version"`
		AccessMode       *string   `json:"access_mode"`
		LastSeenAt       time.Time `json:"last_seen_at"`
		CreatedAt        time.Time `json:"created_at"`
	}
	sessions := make([]sessionRow, 0, len(items))
	for _, inst := range items {
		sessions = append(sessions, sessionRow{
			RuntimeID:        inst.RuntimeID,
			RuntimeSessionID: inst.RuntimeSessionID,
			BuildID:          inst.BuildID,
			Platform:         inst.Platform,
			GameVersion:      inst.GameVersion,
			AccessMode:       inst.AccessMode,
			LastSeenAt:       inst.LastSeenAt,
			CreatedAt:        inst.CreatedAt,
		})
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"ok":        true,
		"install_id": installID,
		"latest":    latest,
		"sessions":  sessions,
		"tags":      tags,
		"overrides": overrides,
		"resolved":  resolved,
	})
}
