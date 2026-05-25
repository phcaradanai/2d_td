package model

import "time"

type UploadedFile struct {
	ID          int64     `json:"id"`
	Filename    string    `json:"filename"`
	ObjectName  string    `json:"object_name"`
	DownloadURL string    `json:"download_url"`
	SizeBytes   int64     `json:"size_bytes"`
	CreatedAt   time.Time `json:"created_at"`
}
