package repository

import (
	"context"
	"database/sql"
	"fmt"

	"leaderboard/internal/model"
)

// AccessRepository handles persistence for access_profiles and runtime_access_overrides.
type AccessRepository struct {
	db *sql.DB
}

func NewAccessRepository(db *sql.DB) *AccessRepository {
	return &AccessRepository{db: db}
}

// ── Profiles ─────────────────────────────────────────────────────────────────

func (r *AccessRepository) GetProfile(ctx context.Context, profileKey string) (*model.AccessProfile, error) {
	p := &model.AccessProfile{}
	err := r.db.QueryRowContext(ctx, `
		SELECT id, profile_key, name, config_json, is_active, created_at, updated_at
		FROM access_profiles WHERE profile_key = $1`, profileKey,
	).Scan(&p.ID, &p.ProfileKey, &p.Name, &p.ConfigJSON, &p.IsActive, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return p, nil
}

func (r *AccessRepository) ListProfiles(ctx context.Context) ([]*model.AccessProfile, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, profile_key, name, config_json, is_active, created_at, updated_at
		FROM access_profiles ORDER BY profile_key`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []*model.AccessProfile
	for rows.Next() {
		p := &model.AccessProfile{}
		if err := rows.Scan(&p.ID, &p.ProfileKey, &p.Name, &p.ConfigJSON, &p.IsActive, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, p)
	}
	return items, rows.Err()
}

func (r *AccessRepository) CreateProfile(ctx context.Context, profileKey, name, configJSON string) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO access_profiles (profile_key, name, config_json)
		VALUES ($1, $2, $3)`, profileKey, name, configJSON)
	return err
}

func (r *AccessRepository) UpdateProfile(ctx context.Context, profileKey, name, configJSON string, isActive bool) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE access_profiles
		SET name = $2, config_json = $3, is_active = $4, updated_at = NOW()
		WHERE profile_key = $1`, profileKey, name, configJSON, isActive)
	return err
}

// ── Overrides ─────────────────────────────────────────────────────────────────

// FindBestOverride returns the highest-priority active override for the given target.
func (r *AccessRepository) FindBestOverride(ctx context.Context, targetType, targetValue string) (*model.AccessOverride, error) {
	o := &model.AccessOverride{}
	err := r.db.QueryRowContext(ctx, `
		SELECT id, target_type, target_value, profile_key, override_json,
		       priority, is_active, starts_at, ends_at, created_at, updated_at
		FROM runtime_access_overrides
		WHERE target_type = $1
		  AND target_value = $2
		  AND is_active = TRUE
		  AND (starts_at IS NULL OR starts_at <= NOW())
		  AND (ends_at   IS NULL OR ends_at   >  NOW())
		ORDER BY priority ASC
		LIMIT 1`, targetType, targetValue,
	).Scan(
		&o.ID, &o.TargetType, &o.TargetValue, &o.ProfileKey, &o.OverrideJSON,
		&o.Priority, &o.IsActive, &o.StartsAt, &o.EndsAt, &o.CreatedAt, &o.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return o, nil
}

// FindBestTagOverride finds the best active override for any of the given tags.
func (r *AccessRepository) FindBestTagOverride(ctx context.Context, tags []string) (*model.AccessOverride, error) {
	if len(tags) == 0 {
		return nil, sql.ErrNoRows
	}
	// Build $1,$2,... placeholder
	placeholders := ""
	args := []any{}
	for i, t := range tags {
		if i > 0 {
			placeholders += ","
		}
		placeholders += fmt.Sprintf("$%d", i+1)
		args = append(args, t)
	}
	o := &model.AccessOverride{}
	err := r.db.QueryRowContext(ctx, `
		SELECT id, target_type, target_value, profile_key, override_json,
		       priority, is_active, starts_at, ends_at, created_at, updated_at
		FROM runtime_access_overrides
		WHERE target_type = 'tag'
		  AND target_value IN (`+placeholders+`)
		  AND is_active = TRUE
		  AND (starts_at IS NULL OR starts_at <= NOW())
		  AND (ends_at   IS NULL OR ends_at   >  NOW())
		ORDER BY priority ASC
		LIMIT 1`, args...,
	).Scan(
		&o.ID, &o.TargetType, &o.TargetValue, &o.ProfileKey, &o.OverrideJSON,
		&o.Priority, &o.IsActive, &o.StartsAt, &o.EndsAt, &o.CreatedAt, &o.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return o, nil
}

// UpsertOverride creates or replaces an override for a given target.
func (r *AccessRepository) UpsertOverride(ctx context.Context, o *model.AccessOverride) (int64, error) {
	var id int64
	err := r.db.QueryRowContext(ctx, `
		INSERT INTO runtime_access_overrides
			(target_type, target_value, profile_key, override_json, priority, is_active)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (id) DO UPDATE SET
			profile_key   = EXCLUDED.profile_key,
			override_json = EXCLUDED.override_json,
			priority      = EXCLUDED.priority,
			is_active     = EXCLUDED.is_active,
			updated_at    = NOW()
		RETURNING id`,
		o.TargetType, o.TargetValue, o.ProfileKey, o.OverrideJSON, o.Priority, o.IsActive,
	).Scan(&id)
	return id, err
}

// SetOverrideForTarget replaces any existing override for the target_type+target_value pair.
func (r *AccessRepository) SetOverrideForTarget(ctx context.Context, targetType, targetValue string, profileKey *string, overrideJSON *string, priority int, isActive bool) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO runtime_access_overrides
			(target_type, target_value, profile_key, override_json, priority, is_active)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (id) DO NOTHING`,
		targetType, targetValue, profileKey, overrideJSON, priority, isActive)
	if err != nil {
		return err
	}
	// If the above did nothing (no conflict on id since id is serial), check for existing by target
	var existing int64
	err = r.db.QueryRowContext(ctx,
		`SELECT id FROM runtime_access_overrides WHERE target_type=$1 AND target_value=$2 LIMIT 1`,
		targetType, targetValue).Scan(&existing)
	if err == sql.ErrNoRows {
		// Already inserted above
		return nil
	}
	if err != nil {
		return err
	}
	_, err = r.db.ExecContext(ctx, `
		UPDATE runtime_access_overrides
		SET profile_key   = $3,
		    override_json = $4,
		    priority      = $5,
		    is_active     = $6,
		    updated_at    = NOW()
		WHERE id = $1 AND target_type = $2`,
		existing, targetType, profileKey, overrideJSON, priority, isActive)
	return err
}

// UpsertByTarget inserts or updates a single override row for the given target.
// Because target_type+target_value is not a unique key (multiple overrides with
// different priorities can exist), this updates the lowest-priority existing row
// for that target, or inserts a new one when none exists.
func (r *AccessRepository) UpsertByTarget(ctx context.Context, targetType, targetValue string, profileKey *string, overrideJSON *string, priority int, isActive bool) error {
	var existingID int64
	err := r.db.QueryRowContext(ctx,
		`SELECT id FROM runtime_access_overrides WHERE target_type=$1 AND target_value=$2 ORDER BY priority ASC LIMIT 1`,
		targetType, targetValue).Scan(&existingID)

	if err == sql.ErrNoRows {
		// Insert new
		_, err = r.db.ExecContext(ctx, `
			INSERT INTO runtime_access_overrides
				(target_type, target_value, profile_key, override_json, priority, is_active)
			VALUES ($1, $2, $3, $4, $5, $6)`,
			targetType, targetValue, profileKey, overrideJSON, priority, isActive)
		return err
	}
	if err != nil {
		return err
	}
	// Update existing
	_, err = r.db.ExecContext(ctx, `
		UPDATE runtime_access_overrides
		SET profile_key   = $2,
		    override_json = $3,
		    priority      = $4,
		    is_active     = $5,
		    updated_at    = NOW()
		WHERE id = $1`,
		existingID, profileKey, overrideJSON, priority, isActive)
	return err
}

func (r *AccessRepository) ListOverrides(ctx context.Context) ([]*model.AccessOverride, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, target_type, target_value, profile_key, override_json,
		       priority, is_active, starts_at, ends_at, created_at, updated_at
		FROM runtime_access_overrides
		ORDER BY target_type, priority, id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []*model.AccessOverride
	for rows.Next() {
		o := &model.AccessOverride{}
		if err := rows.Scan(
			&o.ID, &o.TargetType, &o.TargetValue, &o.ProfileKey, &o.OverrideJSON,
			&o.Priority, &o.IsActive, &o.StartsAt, &o.EndsAt, &o.CreatedAt, &o.UpdatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, o)
	}
	return items, rows.Err()
}

func (r *AccessRepository) UpdateOverride(ctx context.Context, id int64, profileKey *string, overrideJSON *string, priority int, isActive bool) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE runtime_access_overrides
		SET profile_key   = $2,
		    override_json = $3,
		    priority      = $4,
		    is_active     = $5,
		    updated_at    = NOW()
		WHERE id = $1`, id, profileKey, overrideJSON, priority, isActive)
	return err
}

func (r *AccessRepository) SoftDeleteOverride(ctx context.Context, id int64) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE runtime_access_overrides SET is_active=FALSE, updated_at=NOW() WHERE id=$1`, id)
	return err
}

func (r *AccessRepository) OverridesForIdentity(ctx context.Context, installID, runtimeID string) ([]*model.AccessOverride, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, target_type, target_value, profile_key, override_json,
		       priority, is_active, starts_at, ends_at, created_at, updated_at
		FROM runtime_access_overrides
		WHERE is_active = TRUE
		  AND ((target_type='install_id' AND target_value=$1)
		    OR (target_type='runtime_id' AND target_value=$2))
		ORDER BY priority ASC`, installID, runtimeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []*model.AccessOverride
	for rows.Next() {
		o := &model.AccessOverride{}
		if err := rows.Scan(
			&o.ID, &o.TargetType, &o.TargetValue, &o.ProfileKey, &o.OverrideJSON,
			&o.Priority, &o.IsActive, &o.StartsAt, &o.EndsAt, &o.CreatedAt, &o.UpdatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, o)
	}
	return items, rows.Err()
}
