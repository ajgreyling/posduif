# Posduif Sync Engine

The Go-based synchronization engine for Posduif, handling bidirectional sync between PostgreSQL and mobile SQLite databases.

## Structure

- `cmd/sync-engine/` - Application entry point
- `internal/` - Private application code (not importable)
- `config/` - Configuration files

## Development

```bash
# Install dependencies
go mod download

# Run the server
go run ./cmd/sync-engine/main.go --config=config/config.yaml

# Run tests
go test ./...

# Build
go build -o sync-engine ./cmd/sync-engine
```

## Dependencies

All dependencies are FOSS (Free and Open Source Software) with permissive licenses.

