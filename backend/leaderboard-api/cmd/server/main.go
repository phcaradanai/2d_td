package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"leaderboard/internal/config"
	"leaderboard/internal/db"
	"leaderboard/internal/handler"
	"leaderboard/internal/ratelimit"
)

func main() {
	cfg := config.Load()

	database, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("[startup] db connect: %v", err)
	}
	defer database.Close()

	if err := db.Migrate(database); err != nil {
		log.Fatalf("[startup] db migrate: %v", err)
	}

	limiter := ratelimit.New(30, time.Minute) // 30 req/min per IP

	lb := handler.New(database, cfg)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", handler.Health)
	mux.HandleFunc("POST /api/v1/leaderboard/submit", lb.Submit)
	mux.HandleFunc("GET /api/v1/leaderboard/top", lb.GetTop)
	// Pre-flight OPTIONS handled by CORS middleware
	mux.HandleFunc("OPTIONS /api/v1/leaderboard/submit", func(w http.ResponseWriter, r *http.Request) {})
	mux.HandleFunc("OPTIONS /api/v1/leaderboard/top", func(w http.ResponseWriter, r *http.Request) {})

	var h http.Handler = mux
	h = handler.CORSMiddleware(cfg.CORSOrigins)(h)
	h = handler.MaxBodyMiddleware(65536)(h) // 64 KB max body
	h = limiter.Middleware(h)
	h = handler.RecoverMiddleware(h)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      h,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("[leaderboard-api] listening on :%s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[leaderboard-api] listen: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("[leaderboard-api] shutting down gracefully...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("[leaderboard-api] shutdown error: %v", err)
	}
}
