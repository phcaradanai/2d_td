package config

import (
	"os"
	"strconv"
)

type Config struct {
	Port                 string
	DatabaseURL          string
	CORSOrigins          string
	MaxLevel1Wave        int
	AdminToken           string
	DefaultAccessProfile string
	PublicBaseURL        string
}

func Load() Config {
	maxWave := 60
	if v := os.Getenv("MAX_LEVEL1_WAVE"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			maxWave = n
		}
	}
	return Config{
		Port:                 getenv("PORT", "8080"),
		DatabaseURL:          os.Getenv("DATABASE_URL"),
		CORSOrigins:          getenv("CORS_ALLOWED_ORIGINS", "*"),
		MaxLevel1Wave:        maxWave,
		AdminToken:           getenv("ADMIN_TOKEN", "change-me-now"),
		DefaultAccessProfile: getenv("DEFAULT_ACCESS_PROFILE", "demo"),
		PublicBaseURL:        os.Getenv("PUBLIC_BASE_URL"),
	}
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
