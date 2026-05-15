# syntax=docker/dockerfile:1
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Download dependencies first (cached layer)
COPY go.mod .
# GONOSUMDB=* allows go mod tidy to run without a pre-committed go.sum,
# which is fine for a private/internal service deployed via Coolify.
RUN GONOSUMDB=* GOFLAGS=-mod=mod go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /leaderboard-api ./cmd/server

# ---- final image ----
FROM alpine:3.19
RUN apk add --no-cache ca-certificates tzdata
COPY --from=builder /leaderboard-api /leaderboard-api
EXPOSE 8080
ENTRYPOINT ["/leaderboard-api"]
