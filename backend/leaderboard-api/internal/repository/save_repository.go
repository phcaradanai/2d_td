package repository

import (
	"context"
	"database/sql"
	"time"
)

type SaveRepository struct {
	db *sql.DB
}

func NewSaveRepository(db *sql.DB) *SaveRepository {
	return &SaveRepository{db: db}
}

type PlayerSave struct {
	InstallID string
	SaveJSON  string
	UpdatedAt time.Time
}

func (r *SaveRepository) Get(ctx context.Context, installID string) (*PlayerSave, error) {
	var s PlayerSave
	err := r.db.QueryRowContext(ctx,
		`SELECT install_id, save_json, updated_at FROM player_saves WHERE install_id = $1`,
		installID,
	).Scan(&s.InstallID, &s.SaveJSON, &s.UpdatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *SaveRepository) Upsert(ctx context.Context, installID, saveJSON string) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO player_saves (install_id, save_json, updated_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (install_id) DO UPDATE
		SET save_json  = EXCLUDED.save_json,
		    updated_at = NOW()
	`, installID, saveJSON)
	return err
}
