package model

import "time"

// RuntimeInstance represents one game install tracked by the backend.
type RuntimeInstance struct {
	ID               int64      `json:"id"`
	RuntimeID        string     `json:"runtime_id"`
	InstallID        string     `json:"install_id"`
	RuntimeSessionID string     `json:"runtime_session_id"`
	PlayerID         *string    `json:"player_id"`
	BuildID          string     `json:"build_id"`
	Platform         string     `json:"platform"`
	GameVersion      *string    `json:"game_version"`
	AccessMode       *string    `json:"access_mode"`
	ConfigVersion    int        `json:"config_version"`
	ResolvedFrom     *string    `json:"resolved_from"`
	LastSeenAt       time.Time  `json:"last_seen_at"`
	CreatedAt        time.Time  `json:"created_at"`
}

// RuntimeTag associates a tag word with a specific install/player/runtime.
type RuntimeTag struct {
	ID          int64     `json:"id"`
	TargetType  string    `json:"target_type"`
	TargetValue string    `json:"target_value"`
	Tag         string    `json:"tag"`
	CreatedAt   time.Time `json:"created_at"`
}
