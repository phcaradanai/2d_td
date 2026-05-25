package service

import (
	"context"
	"fmt"
	"io"
	"log"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"leaderboard/internal/config"
)

type MinioService interface {
	UploadFile(ctx context.Context, objectName string, reader io.Reader, objectSize int64, contentType string) (string, error)
	DeleteFile(ctx context.Context, objectName string) error
}

type minioService struct {
	client *minio.Client
	bucket string
	publicBaseURL string
}

func NewMinioService(cfg config.Config) (MinioService, error) {
	if cfg.MinioEndpoint == "" {
		return nil, fmt.Errorf("MINIO_ENDPOINT is not configured")
	}

	client, err := minio.New(cfg.MinioEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.MinioAccessKey, cfg.MinioSecretKey, ""),
		Secure: cfg.MinioUseSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to init minio client: %w", err)
	}

	// Ensure bucket exists
	ctx := context.Background()
	exists, err := client.BucketExists(ctx, cfg.MinioBucket)
	if err != nil {
		log.Printf("[minio] warning: could not check if bucket %s exists: %v", cfg.MinioBucket, err)
	} else if !exists {
		err = client.MakeBucket(ctx, cfg.MinioBucket, minio.MakeBucketOptions{})
		if err != nil {
			log.Printf("[minio] warning: could not create bucket %s: %v", cfg.MinioBucket, err)
		} else {
			// Make bucket public for download
			policy := fmt.Sprintf(`{
				"Version": "2012-10-17",
				"Statement": [
					{
						"Effect": "Allow",
						"Principal": {
							"AWS": ["*"]
						},
						"Action": ["s3:GetObject"],
						"Resource": ["arn:aws:s3:::%s/*"]
					}
				]
			}`, cfg.MinioBucket)
			if err := client.SetBucketPolicy(ctx, cfg.MinioBucket, policy); err != nil {
				log.Printf("[minio] warning: could not set bucket policy: %v", err)
			}
		}
	}

	return &minioService{
		client:        client,
		bucket:        cfg.MinioBucket,
		publicBaseURL: cfg.PublicBaseURL, // We could use this to format URLs if minio is behind a proxy
	}, nil
}

func (s *minioService) UploadFile(ctx context.Context, objectName string, reader io.Reader, objectSize int64, contentType string) (string, error) {
	_, err := s.client.PutObject(ctx, s.bucket, objectName, reader, objectSize, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", err
	}

	// Construct public download URL
	// If Minio UseSSL is true, scheme is https, else http
	scheme := "http"
	if s.client.EndpointURL().Scheme == "https" || s.client.EndpointURL().Port() == "443" {
		scheme = "https"
	}
	// For simple minio setup, the url is scheme://endpoint/bucket/objectName
	// Note: You can override this if minio is behind a proxy like publicBaseURL
	url := fmt.Sprintf("%s://%s/%s/%s", scheme, s.client.EndpointURL().Host, s.bucket, objectName)
	return url, nil
}

func (s *minioService) DeleteFile(ctx context.Context, objectName string) error {
	return s.client.RemoveObject(ctx, s.bucket, objectName, minio.RemoveObjectOptions{})
}
