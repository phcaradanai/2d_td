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

// Seed inserts default access profiles if they do not already exist.
func Seed(db *sql.DB) error {
	_, err := db.Exec(seedSQL)
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

-- ── Runtime Identity ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS runtime_instances (
    id                 BIGSERIAL    PRIMARY KEY,
    runtime_id         VARCHAR(64)  UNIQUE NOT NULL,
    install_id         VARCHAR(64)  NOT NULL,
    runtime_session_id VARCHAR(64)  NOT NULL,
    player_id          VARCHAR(100),
    build_id           VARCHAR(100) NOT NULL DEFAULT '',
    platform           VARCHAR(50)  NOT NULL DEFAULT '',
    game_version       VARCHAR(50),
    access_mode        VARCHAR(50),
    config_version     INT          NOT NULL DEFAULT 1,
    resolved_from      VARCHAR(100),
    last_seen_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ri_install_id    ON runtime_instances (install_id);
CREATE INDEX IF NOT EXISTS idx_ri_player_id     ON runtime_instances (player_id);
CREATE INDEX IF NOT EXISTS idx_ri_runtime_id    ON runtime_instances (runtime_id);
CREATE INDEX IF NOT EXISTS idx_ri_build_id      ON runtime_instances (build_id);
CREATE INDEX IF NOT EXISTS idx_ri_last_seen     ON runtime_instances (last_seen_at DESC);

-- ── Access Profiles ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS access_profiles (
    id          BIGSERIAL     PRIMARY KEY,
    profile_key VARCHAR(100)  UNIQUE NOT NULL,
    name        VARCHAR(100)  NOT NULL,
    config_json TEXT          NOT NULL,
    is_active   BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ── Runtime Access Overrides ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS runtime_access_overrides (
    id            BIGSERIAL     PRIMARY KEY,
    target_type   VARCHAR(50)   NOT NULL,
    target_value  VARCHAR(128)  NOT NULL,
    profile_key   VARCHAR(100),
    override_json TEXT,
    priority      INT           NOT NULL DEFAULT 100,
    is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
    starts_at     TIMESTAMPTZ,
    ends_at       TIMESTAMPTZ,
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_rao_target ON runtime_access_overrides (target_type, target_value);
CREATE INDEX IF NOT EXISTS idx_rao_active ON runtime_access_overrides (is_active);

-- ── Runtime Tags ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS runtime_tags (
    id           BIGSERIAL    PRIMARY KEY,
    target_type  VARCHAR(50)  NOT NULL,
    target_value VARCHAR(128) NOT NULL,
    tag          VARCHAR(100) NOT NULL,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (target_type, target_value, tag)
);
CREATE INDEX IF NOT EXISTS idx_rt_tag ON runtime_tags (tag);

-- ── Access Tokens ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS access_tokens (
    token_code           VARCHAR(64)  PRIMARY KEY,
    name                 VARCHAR(100) NOT NULL DEFAULT '',
    description          TEXT         NOT NULL DEFAULT '',
    profile_key          VARCHAR(100),
    override_json        TEXT,
    grant_target_type    VARCHAR(50)  NOT NULL DEFAULT 'install_id',
    max_redemptions      INT          NOT NULL DEFAULT 1,
    per_install_limit    INT          NOT NULL DEFAULT 1,
    grant_duration_hours INT,
    starts_at            TIMESTAMPTZ,
    expires_at           TIMESTAMPTZ,
    is_active            BOOLEAN      NOT NULL DEFAULT TRUE,
    redemption_count     INT          NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS token_redemptions (
    id          BIGSERIAL    PRIMARY KEY,
    token_code  VARCHAR(64)  NOT NULL,
    install_id  VARCHAR(64)  NOT NULL,
    runtime_id  VARCHAR(64),
    player_id   VARCHAR(100),
    redeemed_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_tr_token   ON token_redemptions (token_code);
CREATE INDEX IF NOT EXISTS idx_tr_install ON token_redemptions (install_id);

-- ── Player Cloud Saves ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS player_saves (
    id          BIGSERIAL    PRIMARY KEY,
    install_id  VARCHAR(64)  UNIQUE NOT NULL,
    save_json   TEXT         NOT NULL DEFAULT '{}',
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ps_install ON player_saves (install_id);

-- ── Audit Logs ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
    id           BIGSERIAL     PRIMARY KEY,
    action       VARCHAR(100)  NOT NULL,
    target_type  VARCHAR(50),
    target_value VARCHAR(128),
    actor        VARCHAR(100)  NOT NULL DEFAULT 'admin',
    metadata     TEXT,
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_al_created ON audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_al_action  ON audit_logs (action);
`

const seedSQL = `
INSERT INTO access_profiles (profile_key, name, config_json) VALUES
('demo',
 'Demo — Level 1 only',
 '{"mode":"demo","enabled_levels":[1],"max_wave":60,"allow_leaderboard_submit":false,"allow_save_resume":true,"allow_sandbox":false,"allow_challenge_mode":false,"maintenance_enabled":false,"force_update":false,"announcement":""}')
ON CONFLICT (profile_key) DO NOTHING;

INSERT INTO access_profiles (profile_key, name, config_json) VALUES
('full',
 'Full Game',
 '{"mode":"full","enabled_levels":"all","max_wave":60,"allow_leaderboard_submit":true,"allow_save_resume":true,"allow_sandbox":true,"allow_challenge_mode":true,"maintenance_enabled":false,"force_update":false,"announcement":""}')
ON CONFLICT (profile_key) DO NOTHING;

INSERT INTO access_profiles (profile_key, name, config_json) VALUES
('demo_level_1_wave_20',
 'Demo — Level 1, Wave 20 cap',
 '{"mode":"demo","enabled_levels":[1],"max_wave":20,"allow_leaderboard_submit":false,"allow_save_resume":true,"allow_sandbox":false,"allow_challenge_mode":false,"maintenance_enabled":false,"force_update":false,"announcement":""}')
ON CONFLICT (profile_key) DO NOTHING;

INSERT INTO access_profiles (profile_key, name, config_json) VALUES
('demo_level_1_2_wave_20',
 'Demo — Levels 1–2, Wave 20 cap',
 '{"mode":"demo","enabled_levels":[1,2],"max_wave":20,"allow_leaderboard_submit":false,"allow_save_resume":true,"allow_sandbox":false,"allow_challenge_mode":false,"maintenance_enabled":false,"force_update":false,"announcement":""}')
ON CONFLICT (profile_key) DO NOTHING;

INSERT INTO access_profiles (profile_key, name, config_json) VALUES
('qa_full',
 'QA — Full access + sandbox',
 '{"mode":"full","enabled_levels":"all","max_wave":60,"allow_leaderboard_submit":true,"allow_save_resume":true,"allow_sandbox":true,"allow_challenge_mode":true,"maintenance_enabled":false,"force_update":false,"announcement":""}')
ON CONFLICT (profile_key) DO NOTHING;
`
