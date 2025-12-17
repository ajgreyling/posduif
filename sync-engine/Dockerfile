FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o sync-engine ./cmd/sync-engine

FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /app/sync-engine .

# Copy config directory
COPY --from=builder /app/config ./config

EXPOSE 8080

CMD ["./sync-engine", "--config=config/config.yaml"]

