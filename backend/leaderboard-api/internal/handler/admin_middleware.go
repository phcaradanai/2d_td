package handler

import (
	"encoding/json"
	"net/http"
	"strings"
)

// AdminMiddleware guards admin endpoints with a Bearer token.
// Token is compared against cfg.AdminToken loaded from env ADMIN_TOKEN.
func AdminMiddleware(token string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			auth := r.Header.Get("Authorization")
			parts := strings.SplitN(auth, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || parts[1] != token {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusUnauthorized)
				json.NewEncoder(w).Encode(map[string]any{
					"ok":    false,
					"error": map[string]string{"code": "unauthorized", "message": "Invalid or missing admin token"},
				})
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
