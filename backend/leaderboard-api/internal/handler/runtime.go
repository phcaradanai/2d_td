package handler

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"leaderboard/internal/model"
	"leaderboard/internal/repository"
	"leaderboard/internal/service"
)

// RuntimeHandler handles game client runtime registration and heartbeat.
type RuntimeHandler struct {
	runtimeRepo *repository.RuntimeRepository
	resolver    *service.AccessResolver
}

func NewRuntimeHandler(rr *repository.RuntimeRepository, resolver *service.AccessResolver) *RuntimeHandler {
	return &RuntimeHandler{runtimeRepo: rr, resolver: resolver}
}

// Register handles POST /api/v1/game/runtime/register
func (h *RuntimeHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req struct {
		InstallID        string  `json:"install_id"`
		RuntimeSessionID string  `json:"runtime_session_id"`
		RuntimeID        string  `json:"runtime_id"`
		PlayerID         *string `json:"player_id"`
		BuildID          string  `json:"build_id"`
		Platform         string  `json:"platform"`
		GameVersion      string  `json:"game_version"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apiError(w, http.StatusBadRequest, "invalid_json", "Invalid request body")
		return
	}

	req.InstallID = strings.TrimSpace(req.InstallID)
	req.RuntimeSessionID = strings.TrimSpace(req.RuntimeSessionID)
	req.BuildID = strings.TrimSpace(req.BuildID)
	req.Platform = strings.TrimSpace(req.Platform)

	if req.InstallID == "" {
		apiError(w, http.StatusBadRequest, "missing_field", "install_id is required")
		return
	}
	if req.RuntimeSessionID == "" {
		apiError(w, http.StatusBadRequest, "missing_field", "runtime_session_id is required")
		return
	}

	// Generate runtime_id if not provided
	runtimeID := strings.TrimSpace(req.RuntimeID)
	if runtimeID == "" {
		b := make([]byte, 8)
		rand.Read(b) //nolint:errcheck
		runtimeID = "rt_" + hex.EncodeToString(b)
	}

	inst := &model.RuntimeInstance{
		RuntimeID:        runtimeID,
		InstallID:        req.InstallID,
		RuntimeSessionID: req.RuntimeSessionID,
		PlayerID:         req.PlayerID,
		BuildID:          req.BuildID,
		Platform:         req.Platform,
	}
	if req.GameVersion != "" {
		inst.GameVersion = &req.GameVersion
	}

	if err := h.runtimeRepo.Upsert(r.Context(), inst); err != nil {
		log.Printf("[runtime.Register] upsert: %v", err)
		apiError(w, http.StatusInternalServerError, "db_error", "Failed to register runtime")
		return
	}

	// Resolve access config
	identity := model.Identity{
		RuntimeID:        runtimeID,
		InstallID:        req.InstallID,
		RuntimeSessionID: req.RuntimeSessionID,
		BuildID:          req.BuildID,
		Platform:         req.Platform,
		GameVersion:      req.GameVersion,
	}
	if req.PlayerID != nil {
		identity.PlayerID = *req.PlayerID
	}

	resolved, err := h.resolver.Resolve(r.Context(), identity)
	if err != nil {
		log.Printf("[runtime.Register] resolve: %v", err)
		resolved = &model.ResolvedAccess{
			ConfigVersion: 1,
			ResolvedFrom:  "global_default",
			Tags:          []string{},
			Config:        model.DefaultDemoConfig(),
		}
	}

	// Persist resolved meta back
	if err := h.runtimeRepo.UpdateAccessMeta(r.Context(), runtimeID,
		resolved.Config.Mode, resolved.ResolvedFrom, resolved.ConfigVersion); err != nil {
		log.Printf("[runtime.Register] UpdateAccessMeta: %v", err)
	}

	tags := resolved.Tags
	if tags == nil {
		tags = []string{}
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"ok":            true,
		"runtime_id":    runtimeID,
		"config_version": resolved.ConfigVersion,
		"resolved_from": resolved.ResolvedFrom,
		"tags":          tags,
		"access":        resolved.Config,
	})
}

// Heartbeat handles POST /api/v1/game/runtime/heartbeat
func (h *RuntimeHandler) Heartbeat(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RuntimeID        string `json:"runtime_id"`
		InstallID        string `json:"install_id"`
		RuntimeSessionID string `json:"runtime_session_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apiError(w, http.StatusBadRequest, "invalid_json", "Invalid request body")
		return
	}
	if req.RuntimeID != "" {
		if err := h.runtimeRepo.UpdateAccessMeta(r.Context(), req.RuntimeID, "", "", 0); err != nil {
			log.Printf("[heartbeat] touch runtime: %v", err)
		}
	} else if req.InstallID != "" {
		if err := h.runtimeRepo.TouchByInstallID(r.Context(), req.InstallID); err != nil {
			log.Printf("[heartbeat] touch install: %v", err)
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}
