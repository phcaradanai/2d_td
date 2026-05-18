package model

import "time"

// RuntimeInstance represents one game install tracked by the backend.
type RuntimeInstance struct {
	ID               int64
	RuntimeID        string
	InstallID        string
	RuntimeSessionID string
	PlayerID         *string
	BuildID          string
	Platform         string
	GameVersion      *string
	AccessMode       *string
	ConfigVersion    int
	ResolvedFrom     *string
	LastSeenAt       time.Time
	CreatedAt        time.Time
}

// RuntimeTag associates a tag word with a specific install/player/runtime.
type RuntimeTag struct {
	ID          int64
	TargetType  string
	TargetValue string
	Tag         string
	CreatedAt   time.Time
}
