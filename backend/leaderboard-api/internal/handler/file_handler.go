package handler

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"leaderboard/internal/model"
	"leaderboard/internal/repository"
	"leaderboard/internal/service"
)

type FileHandler struct {
	fileRepo repository.FileRepository
	minioSvc service.MinioService
}

func NewFileHandler(fileRepo repository.FileRepository, minioSvc service.MinioService) *FileHandler {
	return &FileHandler{
		fileRepo: fileRepo,
		minioSvc: minioSvc,
	}
}

func (h *FileHandler) UploadFile(w http.ResponseWriter, r *http.Request) {
	// Parse multipart form, 50 MB max memory (adjust as needed)
	if err := r.ParseMultipartForm(50 << 20); err != nil {
		http.Error(w, "Failed to parse form", http.StatusBadRequest)
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "File is required", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Generate a unique object name to prevent collisions
	timestamp := time.Now().UnixNano()
	objectName := fmt.Sprintf("%d-%s", timestamp, header.Filename)

	// Upload to Minio
	url, err := h.minioSvc.UploadFile(r.Context(), objectName, file, header.Size, header.Header.Get("Content-Type"))
	if err != nil {
		log.Printf("[file_handler] minio upload error: %v", err)
		http.Error(w, "Failed to upload file", http.StatusInternalServerError)
		return
	}

	// Save to Database
	f := &model.UploadedFile{
		Filename:    header.Filename,
		ObjectName:  objectName,
		DownloadURL: url,
		SizeBytes:   header.Size,
	}
	if err := h.fileRepo.Save(f); err != nil {
		log.Printf("[file_handler] db save error: %v", err)
		http.Error(w, "Failed to save file metadata", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(f)
}

func (h *FileHandler) ListFiles(w http.ResponseWriter, r *http.Request) {
	files, err := h.fileRepo.List()
	if err != nil {
		log.Printf("[file_handler] db list error: %v", err)
		http.Error(w, "Failed to fetch files", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(files)
}

func (h *FileHandler) DeleteFile(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, "Invalid ID", http.StatusBadRequest)
		return
	}

	f, err := h.fileRepo.GetByID(id)
	if err != nil {
		log.Printf("[file_handler] db get error: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
	if f == nil {
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}

	// Delete from Minio
	if err := h.minioSvc.DeleteFile(r.Context(), f.ObjectName); err != nil {
		log.Printf("[file_handler] minio delete error: %v", err)
		// We can still proceed to delete from DB if minio delete fails (e.g. file already gone)
		// But usually it's better to log it.
	}

	// Delete from Database
	if err := h.fileRepo.Delete(id); err != nil {
		log.Printf("[file_handler] db delete error: %v", err)
		http.Error(w, "Failed to delete file from database", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
