package service

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"

	"leaderboard/internal/model"
	"leaderboard/internal/repository"
)

// AccessResolver resolves the effective access config for a game client identity.
//
// Priority order (first match wins):
//  1. player_id override
//  2. install_id override
//  3. runtime_id override
//  4. tag override  (best matching tag)
//  5. build_id override
//  6. global override
//  7. default profile (cfg.DefaultAccessProfile)
type AccessResolver struct {
	runtimeRepo      *repository.RuntimeRepository
	accessRepo       *repository.AccessRepository
	defaultProfileKey string
}

func NewAccessResolver(rr *repository.RuntimeRepository, ar *repository.AccessRepository, defaultProfileKey string) *AccessResolver {
	return &AccessResolver{
		runtimeRepo:      rr,
		accessRepo:       ar,
		defaultProfileKey: defaultProfileKey,
	}
}

// Resolve returns the access config for the given identity.
func (s *AccessResolver) Resolve(ctx context.Context, id model.Identity) (*model.ResolvedAccess, error) {
	// Fetch tags for this identity first (needed for tag-based override lookup)
	tags, err := s.runtimeRepo.TagsForIdentity(ctx, id.InstallID, id.PlayerID, id.RuntimeID)
	if err != nil {
		log.Printf("[resolver] tags lookup error: %v", err)
		tags = nil
	}

	// Ordered priority checks (outer order = fixed cross-type priority)
	type check struct {
		targetType  string
		targetValue string
	}
	checks := []check{}
	if id.PlayerID != "" {
		checks = append(checks, check{"player_id", id.PlayerID})
	}
	if id.InstallID != "" {
		checks = append(checks, check{"install_id", id.InstallID})
	}
	if id.RuntimeID != "" {
		checks = append(checks, check{"runtime_id", id.RuntimeID})
	}
	// Tags checked as a group — best priority wins across all matching tags
	if len(tags) > 0 {
		if o, err := s.accessRepo.FindBestTagOverride(ctx, tags); err == nil {
			return s.buildResult(ctx, o, tags)
		}
	}
	if id.BuildID != "" {
		checks = append(checks, check{"build_id", id.BuildID})
	}
	checks = append(checks, check{"global", "global"})

	for _, c := range checks {
		if c.targetValue == "" {
			continue
		}
		o, err := s.accessRepo.FindBestOverride(ctx, c.targetType, c.targetValue)
		if err == sql.ErrNoRows {
			continue
		}
		if err != nil {
			log.Printf("[resolver] FindBestOverride(%s,%s): %v", c.targetType, c.targetValue, err)
			continue
		}
		return s.buildResult(ctx, o, tags)
	}

	// Default: load the configured default profile
	return s.defaultResult(ctx, tags)
}

// buildResult constructs a ResolvedAccess from an override row.
func (s *AccessResolver) buildResult(ctx context.Context, o *model.AccessOverride, tags []string) (*model.ResolvedAccess, error) {
	baseJSON := "{}"
	if o.ProfileKey != nil && *o.ProfileKey != "" {
		profile, err := s.accessRepo.GetProfile(ctx, *o.ProfileKey)
		if err == nil {
			baseJSON = profile.ConfigJSON
		} else {
			log.Printf("[resolver] profile %q not found: %v", *o.ProfileKey, err)
		}
	}

	merged, err := mergeJSON(baseJSON, o.OverrideJSON)
	if err != nil {
		return nil, fmt.Errorf("merge configs: %w", err)
	}

	profileKey := ""
	if o.ProfileKey != nil {
		profileKey = *o.ProfileKey
	}

	return &model.ResolvedAccess{
		ConfigVersion: int(o.ID),
		ResolvedFrom:  o.TargetType + "_override",
		ProfileKey:    profileKey,
		Tags:          tags,
		Config:        merged,
	}, nil
}

// defaultResult falls back to the configured default profile.
func (s *AccessResolver) defaultResult(ctx context.Context, tags []string) (*model.ResolvedAccess, error) {
	profile, err := s.accessRepo.GetProfile(ctx, s.defaultProfileKey)
	if err != nil {
		log.Printf("[resolver] default profile %q not found, using hard defaults: %v", s.defaultProfileKey, err)
		return &model.ResolvedAccess{
			ConfigVersion: 1,
			ResolvedFrom:  "global_default",
			ProfileKey:    s.defaultProfileKey,
			Tags:          tags,
			Config:        model.DefaultDemoConfig(),
		}, nil
	}

	cfg, err := parseConfig(profile.ConfigJSON)
	if err != nil {
		return nil, fmt.Errorf("parse default profile: %w", err)
	}
	return &model.ResolvedAccess{
		ConfigVersion: int(profile.ID),
		ResolvedFrom:  "global_default",
		ProfileKey:    profile.ProfileKey,
		Tags:          tags,
		Config:        cfg,
	}, nil
}

// mergeJSON merges override JSON fields on top of base JSON and parses result.
func mergeJSON(base string, override *string) (*model.AccessConfig, error) {
	baseMap := make(map[string]interface{})
	if err := json.Unmarshal([]byte(base), &baseMap); err != nil {
		// Fallback: ignore bad base
		baseMap = make(map[string]interface{})
	}
	if override != nil && *override != "" {
		overMap := make(map[string]interface{})
		if err := json.Unmarshal([]byte(*override), &overMap); err == nil {
			for k, v := range overMap {
				baseMap[k] = v
			}
		}
	}
	merged, err := json.Marshal(baseMap)
	if err != nil {
		return nil, err
	}
	return parseConfig(string(merged))
}

func parseConfig(jsonStr string) (*model.AccessConfig, error) {
	cfg := model.DefaultDemoConfig()
	if err := json.Unmarshal([]byte(jsonStr), cfg); err != nil {
		return nil, err
	}
	if len(cfg.EnabledLevels) == 0 {
		cfg.EnabledLevels = json.RawMessage(`[1]`)
	}
	return cfg, nil
}
