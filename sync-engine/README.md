# Posduif Sync Engine

The Go-based synchronization engine for Posduif, handling bidirectional sync between PostgreSQL and mobile SQLite databases.

## Features

- **WAL-Based Change Detection**: Uses PostgreSQL 18+ logical replication for real-time change detection
- **Efficient Sync**: Tracks changes using Log Sequence Numbers (LSN) for incremental synchronization
- **Backward Compatible**: Falls back to polling-based sync if WAL is disabled
- **Multi-Tenant**: Database-per-tenant architecture with automatic replication slot management
- **User Sync**: Syncs users table including `last_message_sent` field with last-write-wins conflict resolution

## Structure

- `cmd/sync-engine/` - Application entry point
- `internal/` - Private application code (not importable)
  - `sync/` - Sync logic including WAL reader, change tracker, and sync manager
  - `database/` - PostgreSQL connection, queries, migrations, and replication slot management
  - `api/` - HTTP handlers, middleware, SSE
  - `models/` - Data models (User, Message, SyncMetadata, etc.)
  - `enrollment/` - Enrollment service (QR code-based)
  - `redis/` - Redis client for event distribution
  - `compression/` - Compression utilities
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

## Endpoints

### Enrollment (Public)
- `GET /api/enrollment/:token` - Get enrollment token details
- `POST /api/enrollment/complete` - Complete enrollment with username
  ```json
  {
    "token": "enrollment-token",
    "device_id": "device-id",
    "username": "Joe the Mobile User",
    "device_info": {}
  }
  ```

### Enrollment (Protected)
- `POST /api/enrollment/create` - Create enrollment token (requires auth)

### Sync (Device-Authenticated)
- `GET /api/sync/incoming` - Get incoming messages and users (requires X-Device-ID header)
  - Returns messages and users with `last_message_sent` field
- `POST /api/sync/outgoing` - Upload outgoing messages (requires X-Device-ID header)
- `GET /api/sync/status` - Get sync status (requires X-Device-ID header)

### Messages (Protected)
- `GET /api/messages` - List messages (requires auth)
- `POST /api/messages` - Create message (requires auth)
  - Automatically updates sender's `last_message_sent` field

### Users (Protected)
- `GET /api/users` - List users (requires auth)

## WAL-Based Change Detection

The sync engine uses PostgreSQL 18+ logical replication for efficient change detection:

1. **Replication Slot**: Automatically creates a logical replication slot per tenant on startup
2. **WAL Reading**: Reads changes from Write-Ahead Log using pgoutput plugin
3. **Change Tracking**: Tracks changes per device using Log Sequence Numbers (LSN)
4. **Incremental Sync**: Only syncs changes since device's last synced LSN

### Configuration

Enable WAL-based sync in `config/config.yaml`:

```yaml
sync:
  wal:
    enabled: true  # Enable WAL-based change detection
    slot_name: ""  # Auto-generated from tenant DB name if empty
    batch_size: 100
    read_interval: "1s"
```

### PostgreSQL Requirements

- PostgreSQL 18+ required
- `wal_level = logical` in `postgresql.conf`
- Replication user with `REPLICATION` privilege
- Logical replication slot created automatically on startup

## Last Message Sent Sync

The sync engine handles syncing the `last_message_sent` field on the users table:

- **On Message Create**: Updates sender's `last_message_sent` field
- **On Sync**: Includes users in sync response with `last_message_sent` field
- **Conflict Resolution**: Uses last-write-wins (compares `updated_at` timestamps)
- **Mobile Sync**: Mobile app receives users with `last_message_sent` and updates local database

## Dependencies

All dependencies are FOSS (Free and Open Source Software) with permissive licenses:
- `github.com/jackc/pgx/v5` - PostgreSQL driver
- `github.com/redis/go-redis/v9` - Redis client
- `gopkg.in/yaml.v3` - YAML configuration
