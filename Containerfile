# ==========================================
# Stage 1: Build Stage
# ==========================================
FROM golang:1-alpine AS builder

# Install CA certificates in the builder stage so we can copy them into scratch
RUN apk --no-cache add ca-certificates

# Create a non-root user in the builder stage
RUN adduser -D -u 1000 appuser

WORKDIR /app

# Cache Go modules
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build fully static binary (CGO_ENABLED=0)
ARG VERSION=dev
ARG COMMIT=unknown
ARG BUILD_DATE=unknown

RUN CGO_ENABLED=0 GOOS=linux go build \
    -buildvcs=false \
    -ldflags="-w -s -X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" \
    -o /app/cliproxyapi ./cmd/server

# ==========================================
# Stage 2: Minimal Scratch Runtime Stage
# ==========================================
FROM scratch

# Copy TLS root certificates for outgoing HTTPS requests
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy user database from builder to run as non-root
COPY --from=builder /etc/passwd /etc/passwd

# Copy the static binary
COPY --from=builder /app/cliproxyapi /cliproxyapi

# Switch to the non-root user created in builder (UID 10001)
USER 1000:1000

EXPOSE 8317

ENTRYPOINT ["/cliproxyapi"]