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
	"leaderboard/internal/repository"
	"leaderboard/internal/service"
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
	if err := db.Seed(database); err != nil {
		log.Printf("[startup] db seed warning: %v", err)
	}

	// ── Repos & services ───────────────────────────────────────────────────
	runtimeRepo := repository.NewRuntimeRepository(database)
	accessRepo  := repository.NewAccessRepository(database)
	saveRepo    := repository.NewSaveRepository(database)
	fileRepo    := repository.NewFileRepository(database)
	resolver    := service.NewAccessResolver(runtimeRepo, accessRepo, cfg.DefaultAccessProfile)

	minioSvc, err := service.NewMinioService(cfg)
	if err != nil {
		log.Printf("[startup] minio service warning: %v", err)
	}

	// ── Handlers ───────────────────────────────────────────────────────────
	limiter    := ratelimit.New(60, time.Minute)
	lb         := handler.New(database, cfg).WithResolver(resolver)
	rtHandler  := handler.NewRuntimeHandler(runtimeRepo, resolver)
	saveH      := handler.NewSaveHandler(saveRepo)
	acHandler  := handler.NewAccessHandler(runtimeRepo, resolver)
	adm        := handler.NewAdminHandler(runtimeRepo, accessRepo, resolver)
	dash       := handler.NewDashboardHandler(database)
	install    := handler.NewInstallHandler(runtimeRepo, accessRepo, resolver)
	tokens     := handler.NewTokenHandler(database, runtimeRepo, accessRepo, resolver)
	auditH     := handler.NewAuditHandler(database)
	fileH      := handler.NewFileHandler(fileRepo, minioSvc)
	adminMW    := handler.AdminMiddleware(cfg.AdminToken)

	mux := http.NewServeMux()

	// ── Existing leaderboard endpoints (unchanged) ─────────────────────────
	mux.HandleFunc("GET /healthz", handler.Health)
	mux.HandleFunc("GET /health", handler.Health)
	mux.HandleFunc("POST /api/v1/leaderboard/submit", lb.Submit)
	mux.HandleFunc("GET /api/v1/leaderboard/top", lb.GetTop)
	mux.HandleFunc("OPTIONS /api/v1/leaderboard/submit", optionsOK)
	mux.HandleFunc("OPTIONS /api/v1/leaderboard/top", optionsOK)

	// ── Game client endpoints (public) ─────────────────────────────────────
	mux.HandleFunc("POST /api/v1/game/runtime/register",    rtHandler.Register)
	mux.HandleFunc("POST /api/v1/game/runtime/heartbeat",   rtHandler.Heartbeat)
	mux.HandleFunc("GET /api/v1/game/access",               acHandler.GetAccess)
	mux.HandleFunc("POST /api/v1/game/token/redeem",        tokens.RedeemToken)
	mux.HandleFunc("OPTIONS /api/v1/game/runtime/register", optionsOK)
	mux.HandleFunc("OPTIONS /api/v1/game/runtime/heartbeat",optionsOK)
	mux.HandleFunc("OPTIONS /api/v1/game/access",           optionsOK)
	mux.HandleFunc("OPTIONS /api/v1/game/token/redeem",     optionsOK)

	// ── Cloud Save endpoints (public, keyed by install_id) ─────────────────
	mux.HandleFunc("GET /api/v1/game/save",     saveH.GetSave)
	mux.HandleFunc("PUT /api/v1/game/save",     saveH.PutSave)
	mux.HandleFunc("OPTIONS /api/v1/game/save", optionsOK)

	// ── Admin REST API (token-protected, JSON only) ────────────────────────
	mux.Handle("GET /api/admin/dashboard/summary",                   adminMW(http.HandlerFunc(dash.Summary)))
	mux.Handle("GET /api/admin/runtimes",                            adminMW(http.HandlerFunc(adm.ListRuntimes)))
	mux.Handle("GET /api/admin/runtimes/{runtime_id}",               adminMW(http.HandlerFunc(adm.GetRuntime)))
	mux.Handle("PATCH /api/admin/runtimes/{runtime_id}/access",      adminMW(http.HandlerFunc(adm.SetRuntimeAccess)))
	mux.Handle("GET /api/admin/installs/{install_id}",               adminMW(http.HandlerFunc(install.GetInstall)))
	mux.Handle("PATCH /api/admin/installations/{install_id}/access", adminMW(http.HandlerFunc(adm.SetInstallAccess)))
	mux.Handle("POST /api/admin/tags",                               adminMW(http.HandlerFunc(adm.AddTag)))
	mux.Handle("DELETE /api/admin/tags",                             adminMW(http.HandlerFunc(adm.RemoveTag)))
	mux.Handle("GET /api/admin/access-profiles",                     adminMW(http.HandlerFunc(adm.ListProfiles)))
	mux.Handle("POST /api/admin/access-profiles",                    adminMW(http.HandlerFunc(adm.CreateProfile)))
	mux.Handle("PATCH /api/admin/access-profiles/{profile_key}",     adminMW(http.HandlerFunc(adm.UpdateProfile)))
	mux.Handle("GET /api/admin/overrides",                           adminMW(http.HandlerFunc(adm.ListOverrides)))
	mux.Handle("PATCH /api/admin/overrides/{id}",                    adminMW(http.HandlerFunc(adm.UpdateOverride)))
	mux.Handle("DELETE /api/admin/overrides/{id}",                   adminMW(http.HandlerFunc(adm.DeleteOverride)))
	mux.Handle("GET /api/admin/tokens",                              adminMW(http.HandlerFunc(tokens.ListTokens)))
	mux.Handle("POST /api/admin/tokens/generate",                    adminMW(http.HandlerFunc(tokens.GenerateTokens)))
	mux.Handle("PATCH /api/admin/tokens/{token_code}",               adminMW(http.HandlerFunc(tokens.UpdateToken)))
	mux.Handle("DELETE /api/admin/tokens/{token_code}",              adminMW(http.HandlerFunc(tokens.DeleteToken)))
	mux.Handle("GET /api/admin/tokens/{token_code}/redemptions",     adminMW(http.HandlerFunc(tokens.GetTokenRedemptions)))
	mux.Handle("GET /api/admin/audit-logs",                          adminMW(http.HandlerFunc(auditH.ListAuditLogs)))
	mux.Handle("POST /api/admin/files/upload",                       adminMW(http.HandlerFunc(fileH.UploadFile)))
	mux.Handle("GET /api/admin/files",                               adminMW(http.HandlerFunc(fileH.ListFiles)))
	mux.Handle("DELETE /api/admin/files/{id}",                       adminMW(http.HandlerFunc(fileH.DeleteFile)))

	// ── Global middleware stack ────────────────────────────────────────────
	var h http.Handler = mux
	h = handler.CORSMiddleware(cfg.CORSOrigins)(h)
	h = handler.MaxBodyMiddleware(65536)(h)
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

func optionsOK(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) }
