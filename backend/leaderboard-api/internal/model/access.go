package model

import (
	"encoding/json"
	"time"
)

// Identity holds the fields sent by the game client to identify itself.
type Identity struct {
	RuntimeID        string
	InstallID        string
	RuntimeSessionID string
	PlayerID         string
	BuildID          string
	Platform         string
	GameVersion      string
}

// AccessConfig is the resolved set of rules sent back to the game client.
type AccessConfig struct {
	Mode                   string          `json:"mode"`
	EnabledLevels          json.RawMessage `json:"enabled_levels"` // [1,2,3] or "all"
	MaxWave                int             `json:"max_wave"`
	AllowLeaderboardSubmit bool            `json:"allow_leaderboard_submit"`
	AllowSaveResume        bool            `json:"allow_save_resume"`
	AllowSandbox           bool            `json:"allow_sandbox"`
	AllowChallengeMode     bool            `json:"allow_challenge_mode"`
	MaintenanceEnabled     bool            `json:"maintenance_enabled"`
	ForceUpdate            bool            `json:"force_update"`
	Announcement           string          `json:"announcement"`
}

// DefaultDemoConfig returns a safe demo config used when nothing else matches.
func DefaultDemoConfig() *AccessConfig {
	return &AccessConfig{
		Mode:                   "demo",
		EnabledLevels:          json.RawMessage(`[1]`),
		MaxWave:                60,
		AllowLeaderboardSubmit: false,
		AllowSaveResume:        true,
		AllowSandbox:           false,
		AllowChallengeMode:     false,
		MaintenanceEnabled:     false,
		ForceUpdate:            false,
		Announcement:           "",
	}
}

// Entitlement describes purchase/unlock state returned alongside access config.
type Entitlement struct {
	FullVersionUnlocked bool `json:"full_version_unlocked"`
}

// ResolvedAccess is the complete result of access resolution.
type ResolvedAccess struct {
	ConfigVersion int
	ResolvedFrom  string
	ProfileKey    string
	Tags          []string
	Config        *AccessConfig
}

// AccessProfile is a named, reusable access config stored in the database.
type AccessProfile struct {
	ID         int64
	ProfileKey string
	Name       string
	ConfigJSON string
	IsActive   bool
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

// AccessOverride associates an access profile (and optional JSON patch) with
// a specific target (install_id, player_id, runtime_id, tag, build_id, or global).
type AccessOverride struct {
	ID           int64
	TargetType   string
	TargetValue  string
	ProfileKey   *string
	OverrideJSON *string
	Priority     int
	IsActive     bool
	StartsAt     *time.Time
	EndsAt       *time.Time
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// CanPlayLevel returns whether the given level ID is allowed by this config.
func (a *AccessConfig) CanPlayLevel(levelID int) bool {
	if a.Mode == "full" {
		return true
	}
	if len(a.EnabledLevels) == 0 {
		return levelID == 1
	}
	var s string
	if json.Unmarshal(a.EnabledLevels, &s) == nil {
		return s == "all"
	}
	var levels []int
	if json.Unmarshal(a.EnabledLevels, &levels) == nil {
		for _, l := range levels {
			if l == levelID {
				return true
			}
		}
	}
	return false
}
