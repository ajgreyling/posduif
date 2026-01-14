# Web API Service

Separate Go API service for web users. Web users access the database directly through this API (no synchronization). This service is separate from the sync engine to keep concerns separated.

## Features

- **Username-Based Authentication**: No passwords, just username selection
- **Direct Database Access**: Web users query PostgreSQL directly
- **Message Management**: Send and receive messages
- **User Management**: List all users with `last_message_sent` field
- **Last Message Sent**: Updates sender's `last_message_sent` when message is created

## Architecture

This service is completely separate from the sync engine:
- **Different Port**: Runs on port 8081 (default) vs sync engine on 8080
- **Different Binary**: Separate Go module and binary
- **No Sync Logic**: Web users don't need sync functionality
- **Direct DB Access**: Queries PostgreSQL directly

## Endpoints

### Authentication
- `POST /api/auth/login` - Username-based login (no password)
  ```json
  {
    "username": "Bob the Web User"
  }
  ```

### Users
- `GET /api/users` - List all users with `last_message_sent` field
  - Requires `X-User-ID` header

### Messages
- `GET /api/messages` - Get messages for current user
  - Query params: `limit`, `offset`
  - Requires `X-User-ID` header
- `POST /api/messages` - Send message
  ```json
  {
    "recipient_id": "user-uuid",
    "content": "Hello!"
  }
  ```
  - Requires `X-User-ID` header
  - Automatically updates sender's `last_message_sent` field

## Structure

```
web-api/
├── cmd/web-api/
│   └── main.go              # Application entry point
├── internal/
│   ├── api/handlers/        # HTTP handlers
│   │   ├── auth.go          # Authentication
│   │   ├── messages.go      # Message endpoints
│   │   └── users.go         # User endpoints
│   ├── database/
│   │   └── queries.go       # Database queries
│   ├── models/
│   │   ├── user.go          # User model
│   │   └── message.go       # Message model
│   └── config/
│       └── config.go        # Configuration
├── go.mod
└── README.md
```

## Development

```bash
# Install dependencies
go mod download

# Run the server
go run ./cmd/web-api/main.go --config=../config/config.yaml

# Build
go build -o web-api ./cmd/web-api

# Run tests
go test ./...
```

## Configuration

Uses the same `config/config.yaml` as the sync engine:

```yaml
port: 8081  # Default port (different from sync engine)

postgres:
  host: localhost
  port: 5432
  user: posduif
  password: secret
  db: tenant_1
```

## Database

The service connects to the same PostgreSQL database as the sync engine and queries:
- `users` table (includes `last_message_sent` field)
- `messages` table

When a message is created, the service automatically updates the sender's `last_message_sent` field.

## Authentication

Currently uses `X-User-ID` header for authentication (simplified for demo). In production, would use JWT tokens.

## Dependencies

All dependencies are FOSS (Free and Open Source Software) with permissive licenses:
- `github.com/jackc/pgx/v5` - PostgreSQL driver
- `gopkg.in/yaml.v3` - YAML configuration
- `github.com/google/uuid` - UUID generation
