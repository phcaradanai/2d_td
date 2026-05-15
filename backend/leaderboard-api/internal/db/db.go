package db

import (
	"database/sql"
	"fmt"

	_ "github.com/lib/pq"
)

func Connect(dsn string) (*sql.DB, error) {
	if dsn == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)
	if err := db.Ping(); err != nil {
		return nil, err
	}
	return db, nil
}

// Migrate creates the schema if it does not exist. Safe to call on every startup.
func Migrate(db *sql.DB) error {
	_, err := db.Exec(schema)
	return err
}

const schema = `
CREATE TABLE IF NOT EXISTS leaderboard_scores (
    id               BIGSERIAL PRIMARY KEY,
    player_name      VARCHAR(20)  NOT NULL,
    level_id         VARCHAR(64)  NOT NULL,
    wave_reached     INT          NOT NULL,
    cleared          BOOLEAN      NOT NULL DEFAULT FALSE,
    score            BIGINT       NOT NULL,
    lives_remaining  INT          NOT NULL,
    gold_remaining   INT          NOT NULL,
    interest_level   INT          NOT NULL,
    run_time_seconds INT          NOT NULL,
    elements         JSONB        NOT NULL DEFAULT '{}',
    client_run_id    VARCHAR(128),
    client_created_at BIGINT,
    ip_address       INET,
    user_agent       TEXT,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_leaderboard_top
ON leaderboard_scores (
    level_id,
    score            DESC,
    wave_reached     DESC,
    lives_remaining  DESC,
    run_time_seconds ASC,
    created_at       ASC
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_leaderboard_client_run_id
ON leaderboard_scores (client_run_id)
WHERE client_run_id IS NOT NULL;
`
