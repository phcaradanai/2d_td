package repository

import (
	"database/sql"
	"leaderboard/internal/model"
)

type FileRepository interface {
	Save(f *model.UploadedFile) error
	List() ([]model.UploadedFile, error)
	GetByID(id int64) (*model.UploadedFile, error)
	Delete(id int64) error
}

type fileRepository struct {
	db *sql.DB
}

func NewFileRepository(db *sql.DB) FileRepository {
	return &fileRepository{db: db}
}

func (r *fileRepository) Save(f *model.UploadedFile) error {
	query := `
		INSERT INTO uploaded_files (filename, object_name, download_url, size_bytes)
		VALUES ($1, $2, $3, $4)
		RETURNING id, created_at
	`
	err := r.db.QueryRow(query, f.Filename, f.ObjectName, f.DownloadURL, f.SizeBytes).Scan(&f.ID, &f.CreatedAt)
	return err
}

func (r *fileRepository) List() ([]model.UploadedFile, error) {
	query := `SELECT id, filename, object_name, download_url, size_bytes, created_at FROM uploaded_files ORDER BY created_at DESC`
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var files []model.UploadedFile
	for rows.Next() {
		var f model.UploadedFile
		if err := rows.Scan(&f.ID, &f.Filename, &f.ObjectName, &f.DownloadURL, &f.SizeBytes, &f.CreatedAt); err != nil {
			return nil, err
		}
		files = append(files, f)
	}
	return files, nil
}

func (r *fileRepository) GetByID(id int64) (*model.UploadedFile, error) {
	query := `SELECT id, filename, object_name, download_url, size_bytes, created_at FROM uploaded_files WHERE id = $1`
	var f model.UploadedFile
	err := r.db.QueryRow(query, id).Scan(&f.ID, &f.Filename, &f.ObjectName, &f.DownloadURL, &f.SizeBytes, &f.CreatedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &f, nil
}

func (r *fileRepository) Delete(id int64) error {
	query := `DELETE FROM uploaded_files WHERE id = $1`
	_, err := r.db.Exec(query, id)
	return err
}
