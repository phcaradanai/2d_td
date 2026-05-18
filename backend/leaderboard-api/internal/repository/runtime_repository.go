package repository

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"leaderboard/internal/model"
)

// RuntimeRepository handles persistence for runtime_instances and runtime_tags.
type RuntimeRepository struct {
	db *sql.DB
}

func NewRuntimeRepository(db *sql.DB) *RuntimeRepository {
	return &RuntimeRepository{db: db}
}

// Upsert inserts a new runtime instance or updates last_seen_at + session fields.
func (r *RuntimeRepository) Upsert(ctx context.Context, inst *model.RuntimeInstance) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO runtime_instances
			(runtime_id, install_id, runtime_session_id, player_id,
			 build_id, platform, game_version, last_seen_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,NOW())
		ON CONFLICT (runtime_id) DO UPDATE SET
			install_id         = EXCLUDED.install_id,
			runtime_session_id = EXCLUDED.runtime_session_id,
			player_id          = COALESCE(EXCLUDED.player_id, runtime_instances.player_id),
			build_id           = EXCLUDED.build_id,
			platform           = EXCLUDED.platform,
			game_version       = COALESCE(EXCLUDED.game_version, runtime_instances.game_version),
			last_seen_at       = NOW()`,
		inst.RuntimeID, inst.InstallID, inst.RuntimeSessionID,
		nullStr(inst.PlayerID), inst.BuildID, inst.Platform, nilStr(inst.GameVersion),
	)
	return err
}

// UpdateAccessMeta stores the resolved access metadata back onto the runtime row.
func (r *RuntimeRepository) UpdateAccessMeta(ctx context.Context, runtimeID, mode, resolvedFrom string, configVersion int) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE runtime_instances
		SET access_mode    = $2,
		    resolved_from  = $3,
		    config_version = $4,
		    last_seen_at   = NOW()
		WHERE runtime_id = $1`,
		runtimeID, mode, resolvedFrom, configVersion,
	)
	return err
}

// TouchByInstallID updates last_seen_at for every runtime sharing this install_id.
func (r *RuntimeRepository) TouchByInstallID(ctx context.Context, installID string) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE runtime_instances SET last_seen_at = NOW() WHERE install_id = $1`,
		installID)
	return err
}

// GetByRuntimeID fetches one runtime instance.
func (r *RuntimeRepository) GetByRuntimeID(ctx context.Context, runtimeID string) (*model.RuntimeInstance, error) {
	return r.scanOne(r.db.QueryRowContext(ctx, `
		SELECT id, runtime_id, install_id, runtime_session_id, player_id,
		       build_id, platform, game_version, access_mode, config_version,
		       resolved_from, last_seen_at, created_at
		FROM runtime_instances WHERE runtime_id = $1`, runtimeID))
}

// GetByInstallID returns the most-recently-seen runtime for this install_id.
func (r *RuntimeRepository) GetByInstallID(ctx context.Context, installID string) (*model.RuntimeInstance, error) {
	return r.scanOne(r.db.QueryRowContext(ctx, `
		SELECT id, runtime_id, install_id, runtime_session_id, player_id,
		       build_id, platform, game_version, access_mode, config_version,
		       resolved_from, last_seen_at, created_at
		FROM runtime_instances WHERE install_id = $1
		ORDER BY last_seen_at DESC LIMIT 1`, installID))
}

// List returns runtime instances with optional search/filter.
func (r *RuntimeRepository) List(ctx context.Context, q, tag, mode string, limit, offset int) ([]*model.RuntimeInstance, int, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}

	// Build WHERE clause
	where := "WHERE 1=1"
	args := []any{}
	n := 1

	if q != "" {
		like := "%" + q + "%"
		where += fmt.Sprintf(` AND (runtime_id ILIKE $%d OR install_id ILIKE $%d OR player_id ILIKE $%d OR build_id ILIKE $%d)`, n, n, n, n)
		args = append(args, like)
		n++
	}
	if mode != "" {
		where += fmt.Sprintf(` AND access_mode = $%d`, n)
		args = append(args, mode)
		n++
	}
	if tag != "" {
		where += fmt.Sprintf(` AND runtime_id IN (
			SELECT target_value FROM runtime_tags
			WHERE target_type='runtime_id' AND tag=$%d
			UNION
			SELECT ri2.runtime_id FROM runtime_instances ri2
			JOIN runtime_tags rt2 ON rt2.target_type='install_id' AND rt2.target_value=ri2.install_id
			WHERE rt2.tag=$%d
		)`, n, n)
		args = append(args, tag)
		n++
	}

	// Total count
	var total int
	countArgs := make([]any, len(args))
	copy(countArgs, args)
	if err := r.db.QueryRowContext(ctx,
		"SELECT COUNT(*) FROM runtime_instances "+where, countArgs...,
	).Scan(&total); err != nil {
		return nil, 0, err
	}

	// Paginated results
	args = append(args, limit, offset)
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, runtime_id, install_id, runtime_session_id, player_id,
		       build_id, platform, game_version, access_mode, config_version,
		       resolved_from, last_seen_at, created_at
		FROM runtime_instances `+where+`
		ORDER BY last_seen_at DESC
		LIMIT $`+fmt.Sprint(n)+` OFFSET $`+fmt.Sprint(n+1),
		args...,
	)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var items []*model.RuntimeInstance
	for rows.Next() {
		inst := &model.RuntimeInstance{}
		if err := rows.Scan(
			&inst.ID, &inst.RuntimeID, &inst.InstallID, &inst.RuntimeSessionID,
			&inst.PlayerID, &inst.BuildID, &inst.Platform, &inst.GameVersion,
			&inst.AccessMode, &inst.ConfigVersion, &inst.ResolvedFrom,
			&inst.LastSeenAt, &inst.CreatedAt,
		); err != nil {
			return nil, 0, err
		}
		items = append(items, inst)
	}
	return items, total, rows.Err()
}

func (r *RuntimeRepository) scanOne(row *sql.Row) (*model.RuntimeInstance, error) {
	inst := &model.RuntimeInstance{}
	err := row.Scan(
		&inst.ID, &inst.RuntimeID, &inst.InstallID, &inst.RuntimeSessionID,
		&inst.PlayerID, &inst.BuildID, &inst.Platform, &inst.GameVersion,
		&inst.AccessMode, &inst.ConfigVersion, &inst.ResolvedFrom,
		&inst.LastSeenAt, &inst.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return inst, nil
}

// ── Tags ──────────────────────────────────────────────────────────────────────

func (r *RuntimeRepository) AddTag(ctx context.Context, targetType, targetValue, tag string) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO runtime_tags (target_type, target_value, tag)
		VALUES ($1, $2, $3)
		ON CONFLICT (target_type, target_value, tag) DO NOTHING`,
		targetType, targetValue, tag)
	return err
}

func (r *RuntimeRepository) RemoveTag(ctx context.Context, targetType, targetValue, tag string) error {
	_, err := r.db.ExecContext(ctx, `
		DELETE FROM runtime_tags
		WHERE target_type = $1 AND target_value = $2 AND tag = $3`,
		targetType, targetValue, tag)
	return err
}

// TagsForIdentity returns all tags associated with any of the identity fields.
func (r *RuntimeRepository) TagsForIdentity(ctx context.Context, installID, playerID, runtimeID string) ([]string, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT DISTINCT tag FROM runtime_tags
		WHERE (target_type='install_id'  AND target_value=$1)
		   OR (target_type='player_id'   AND target_value=$2 AND $2 <> '')
		   OR (target_type='runtime_id'  AND target_value=$3 AND $3 <> '')
		ORDER BY tag`,
		installID, playerID, runtimeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var tags []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		tags = append(tags, t)
	}
	return tags, rows.Err()
}

// TagsForRuntime returns tags for a single runtime row (by all identity fields).
func (r *RuntimeRepository) TagsForRuntime(ctx context.Context, inst *model.RuntimeInstance) ([]string, error) {
	pid := ""
	if inst.PlayerID != nil {
		pid = *inst.PlayerID
	}
	return r.TagsForIdentity(ctx, inst.InstallID, pid, inst.RuntimeID)
}

// ── helpers ───────────────────────────────────────────────────────────────────

func nullStr(s *string) interface{} {
	if s == nil || *s == "" {
		return nil
	}
	return *s
}

func nilStr(s *string) interface{} {
	if s == nil {
		return nil
	}
	return *s
}

func ptrTime(t time.Time) *time.Time { return &t }
var _ = ptrTime // suppress unused warning
