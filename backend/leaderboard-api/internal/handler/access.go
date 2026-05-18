package handler

import (
	"log"
	"net/http"
	"strings"

	"leaderboard/internal/model"
	"leaderboard/internal/repository"
	"leaderboard/internal/service"
)

// AccessHandler handles GET /api/v1/game/access
type AccessHandler struct {
	runtimeRepo *repository.RuntimeRepository
	resolver    *service.AccessResolver
}

func NewAccessHandler(rr *repository.RuntimeRepository, resolver *service.AccessResolver) *AccessHandler {
	return &AccessHandler{runtimeRepo: rr, resolver: resolver}
}

func (h *AccessHandler) GetAccess(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	identity := model.Identity{
		RuntimeID:        strings.TrimSpace(q.Get("runtime_id")),
		InstallID:        strings.TrimSpace(q.Get("install_id")),
		RuntimeSessionID: strings.TrimSpace(q.Get("runtime_session_id")),
		PlayerID:         strings.TrimSpace(q.Get("player_id")),
		BuildID:          strings.TrimSpace(q.Get("build_id")),
		Platform:         strings.TrimSpace(q.Get("platform")),
		GameVersion:      strings.TrimSpace(q.Get("game_version")),
	}

	if identity.InstallID == "" && identity.RuntimeID == "" {
		apiError(w, http.StatusBadRequest, "missing_field", "install_id or runtime_id is required")
		return
	}

	// Touch last_seen_at
	if identity.RuntimeID != "" {
		h.runtimeRepo.UpdateAccessMeta(r.Context(), identity.RuntimeID, "", "", 0) //nolint:errcheck
	} else if identity.InstallID != "" {
		h.runtimeRepo.TouchByInstallID(r.Context(), identity.InstallID) //nolint:errcheck
	}

	resolved, err := h.resolver.Resolve(r.Context(), identity)
	if err != nil {
		log.Printf("[access.GetAccess] resolve: %v", err)
		resolved = &model.ResolvedAccess{
			ConfigVersion: 1,
			ResolvedFrom:  "global_default",
			Tags:          []string{},
			Config:        model.DefaultDemoConfig(),
		}
	}

	// Persist resolved meta back if runtime_id is known
	if identity.RuntimeID != "" {
		h.runtimeRepo.UpdateAccessMeta(r.Context(), identity.RuntimeID, //nolint:errcheck
			resolved.Config.Mode, resolved.ResolvedFrom, resolved.ConfigVersion)
	}

	tags := resolved.Tags
	if tags == nil {
		tags = []string{}
	}

	full := resolved.Config.Mode == "full"
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":             true,
		"config_version": resolved.ConfigVersion,
		"resolved_from":  resolved.ResolvedFrom,
		"tags":           tags,
		"access":         resolved.Config,
		"entitlement": map[string]any{
			"full_version_unlocked": full,
		},
	})
}
