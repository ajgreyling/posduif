# Posduif – Offline-First Multi-Tenant Mobile & Web Sync Engine

Posduif is a self-hosted, open-source sync engine designed for offline-first mobile applications and web users. It enables seamless real-time synchronization between Flutter mobile clients (using SQLite) and a PostgreSQL backend, with per-tenant schemas. Mobile clients use a hardcoded Flutter messenger application with WhatsApp-style interfaces, while web users connect directly to PostgreSQL through a separate API service.

Posduif is built for FOSS environments, scalable deployments, and intermittent connectivity, providing developers with a single place to define tenant-specific data models and sync rules.

## Features

### Offline-First Mobile Sync

- Mobile apps use SQLite (Drift) as the primary offline database
- **Hardcoded Messenger App**: WhatsApp-style chat interface with conversation list and chat screens
- **QR Code Enrollment**: Mobile users enroll by scanning QR codes and select a username (Joe or Sally)
- **Username-Based Authentication**: No passwords - users select from predefined usernames
- Messages sync bidirectionally between mobile SQLite and PostgreSQL backend
- Online operations possible when connectivity is available

### Multi-Tenant Backend

- Single PostgreSQL database per tenant, with a schema per tenant
- Each tenant has a dedicated Go sync engine instance to ensure tenant isolation
- **WAL-Based Change Detection**: Uses PostgreSQL 18+ logical replication for efficient, real-time change detection
- Web users connect directly to PostgreSQL with live database access (no synchronization)
- Schema changes propagate to both SQLite on device and PostgreSQL backend
- **Tenant Enrollment**: QR code-based enrollment links mobile devices to specific tenants

### Real-Time Updates

- Mobile clients receive sync updates via Server-Sent Events (SSE) (Chosen over WebSockets or API polling as it is more power efficient as a single long-lived HTTP connection over bi-directional keep-alives)
- Web clients receive real-time notifications via SSE (notifications only, not data synchronization)

### Efficient Change Detection

- **WAL-Based Sync** (PostgreSQL 18+): Uses logical replication to detect changes in real-time
  - Reads changes directly from Write-Ahead Log (WAL)
  - Tracks changes per device using Log Sequence Numbers (LSN)
  - Only syncs changes since device's last sync position
  - No polling overhead - changes detected immediately
- **Polling Fallback**: Falls back to status-based polling if WAL is disabled

### Scalable, Self-Hosted Infrastructure

- Uses Redis Streams (disk-backed) for fan-out and event distribution (Closest to a Kafka type setup without actually implementing Kafka which is not the best fit here)
- Full self-hosted stack – no third-party SaaS dependencies
- Designed for horizontal scaling via multiple sync engine instances

### Compression & Connectivity

- All mobile sync data is compressed in both directions (PostgreSQL ↔ SQLite)
- Built to handle intermittent or poor network connectivity gracefully for mobile devices

### Messenger Application

- **Mobile App**: Hardcoded Flutter messenger with WhatsApp-style UI
  - Username selection: "Joe the Mobile User" or "Sally the Mobile User"
  - Conversation list showing all users with last message preview
  - Chat screen with message bubbles
  - Offline message composition
  - Real-time sync with backend
  
- **Web App**: Hardcoded Flutter web messenger
  - Username selection: "Bob the Web User" or "Jane the Web User"
  - Conversation list showing all users with last message preview
  - Chat screen with message bubbles
  - Direct database access via separate API service
  - Real-time updates via polling/SSE

- **Last Message Sent**: Each user has a `last_message_sent` field that syncs with last-write-wins conflict resolution

## Architecture

### Architecture Overview

Posduif uses two distinct data access patterns:

- **Web Users**: Connect directly to PostgreSQL via a separate Go web API service (port 8081). No synchronization is required as web users always have a direct connection to the database through the web API service.
- **Mobile Users**: Use SQLite (Drift) as an offline-first local database that synchronizes bidirectionally with PostgreSQL via the sync engine (port 8080). Mobile devices sync data when online and work offline when connectivity is unavailable.

The sync engine handles synchronization between PostgreSQL and mobile SQLite databases only. Web users access data through the separate web API service.

### Application Architecture

```
┌─────────────────────────────────────────────────┐
│         Mobile App (Flutter)                    │
│  - Hardcoded messenger UI                       │
│  - QR code scanner                              │
│  - Username selection                           │
│  - Conversation list & chat screens             │
│  - Drift ORM (hardcoded schema)                │
│  - Sync service                                 │
└─────────────────────────────────────────────────┘
                    │
                    │ Sync (bidirectional)
                    ▼
┌─────────────────────────────────────────────────┐
│         Go Sync Engine (Backend)                │
│  - Enrollment service                           │
│  - Sync manager (mobile ↔ PostgreSQL)         │
│  - PostgreSQL                                   │
└─────────────────────────────────────────────────┘
                    ▲
                    │ Direct DB Access
                    │
┌─────────────────────────────────────────────────┐
│         Web API Service (Go)                    │
│  - Username-based auth                          │
│  - Message endpoints                            │
│  - User endpoints                               │
└─────────────────────────────────────────────────┘
                    ▲
                    │ API Calls
                    │
┌─────────────────────────────────────────────────┐
│         Web App (Flutter)                       │
│  - Hardcoded messenger UI                       │
│  - Username selection                           │
│  - Conversation list & chat screens             │
│  - Direct API access (no sync)                  │
└─────────────────────────────────────────────────┘
```

### QR Code Enrollment Flow

1. **Web User Initiates Enrollment**: Web user clicks "Enroll Mobile User" in the web interface
2. **Backend Creates Token**: Backend generates a unique enrollment token and QR code data
3. **QR Code Displayed**: Web interface displays QR code with enrollment URL
4. **Mobile Scans QR Code**: Mobile app scans QR code using camera permission
5. **Mobile Validates Token**: Mobile app calls backend to validate enrollment token
6. **Mobile Selects Username**: Mobile app shows username selection screen (Joe or Sally)
7. **Mobile Completes Enrollment**: Mobile app sends device information and selected username to complete enrollment
8. **Backend Creates User**: Backend creates mobile user account with selected username and links device to tenant
9. **App Ready**: Mobile app proceeds directly to conversation list

### Tech Stack

- **Mobile**: 
  - Flutter app with hardcoded messenger UI
  - Drift (SQLite) for offline-first data storage with hardcoded schema
  - Riverpod for state management
  - QR code scanner for enrollment
  - Username selection (Joe/Sally)
  - Bidirectional sync with PostgreSQL backend
- **Web**: Flutter web application
  - Hardcoded messenger UI
  - Username selection (Bob/Jane)
  - Direct PostgreSQL access via separate web API service
  - Live database queries (no synchronization)
- **Backend**: 
  - **Sync Engine** (Go): Handles mobile ↔ PostgreSQL synchronization
  - **Web API Service** (Go): Separate service for web users (port 8081)
- **Database**: PostgreSQL 18+ (database-per-tenant)
  - WAL-based change detection using logical replication
  - Real-time change tracking via replication slots
- **Messaging**: Redis Streams (disk-backed)
- **Realtime**: SSE (Server-Sent Events)

## Getting Started

### Prerequisites

- PostgreSQL ≥ 18 (required for WAL-based change detection)
- Redis (disk-backed, Streams enabled)
- Go ≥ 1.21
- Flutter ≥ 3.13
- Drift (Flutter SQLite ORM)

### 1. Clone the repository

```bash
git clone https://github.com/ajgreyling/posduif.git
cd posduif
```

### 2. Set up development environment

Use the provided Vagrant setup:

```bash
vagrant up
```

This will provision a complete development environment with:
- PostgreSQL 18+ (with logical replication enabled)
- Redis with Streams enabled
- Go 1.21+
- Flutter 3.13+

### 3. Configure the sync engine

Edit `config/config.yaml` per tenant:

```yaml
postgres:
  host: localhost
  port: 5432
  user: posduif
  password: secret
  db: tenant_1

redis:
  host: localhost
  port: 6379

sse:
  port: 8080
```

### 4. Initialize database

The database is automatically initialized by the Vagrant provisioning scripts. Manual initialization:

```bash
psql -U posduif -d tenant_1 -f config/database-init.sql
```

**Important**: Ensure PostgreSQL is configured with `wal_level = logical` in `postgresql.conf` for WAL-based change detection to work. The sync engine will automatically create logical replication slots on startup.

### 5. Run the sync engine

```bash
go run ./cmd/sync-engine/main.go --config=config/config.yaml
```

### 6. Run the web API service

```bash
cd web-api
go run ./cmd/web-api/main.go --config=../config/config.yaml
```

The web API service runs on port 8081 by default (different from sync engine on 8080).

### 7. Mobile setup

#### Mobile App

The mobile app is a hardcoded Flutter messenger application with:
- QR code scanner for enrollment
- Username selection screen (Joe the Mobile User, Sally the Mobile User)
- Conversation list screen showing all users with last message preview
- Chat screen with WhatsApp-style message bubbles
- Offline message composition
- Real-time sync with backend

#### Enrollment Process

1. Launch mobile app (shows QR scanner if not enrolled)
2. Web user generates enrollment QR code
3. Mobile user scans QR code
4. Mobile user selects username (Joe or Sally)
5. App completes enrollment and proceeds to conversation list

### 7. Web setup

#### Web API Service

Start the separate web API service:

```bash
cd web-api
go run ./cmd/web-api/main.go --config=../config/config.yaml
```

The web API service runs on port 8081 (default) and provides:
- Username-based authentication (no password)
- Direct PostgreSQL database access
- Message and user endpoints

#### Web App

The Flutter web application provides:
- Username selection (Bob the Web User, Jane the Web User)
- Direct database access via web API service (no synchronization)
- Conversation list showing all users with last message preview
- Chat screen with WhatsApp-style message bubbles
- Real-time updates via polling

## Enrollment API

### Create Enrollment Token (Web)

```http
POST /api/enrollment/create
Authorization: Bearer <web_user_token>

Response:
{
  "token": "550e8400-e29b-41d4-a716-446655440000",
  "qr_code_data": {
    "enrollment_url": "https://backend.example.com/api/enrollment/550e8400...",
    "token": "550e8400-e29b-41d4-a716-446655440000",
    "tenant_id": "tenant_1"
  },
  "expires_at": "2024-01-16T10:00:00Z"
}
```

### Get Enrollment Details (Mobile)

```http
GET /api/enrollment/:token

Response:
{
  "token": "550e8400-e29b-41d4-a716-446655440000",
  "tenant_id": "tenant_1",
  "created_by": "web_user_1",
  "expires_at": "2024-01-16T10:00:00Z",
  "valid": true
}
```

### Complete Enrollment (Mobile)

```http
POST /api/enrollment/complete
Content-Type: application/json

{
  "token": "550e8400-e29b-41d4-a716-446655440000",
  "device_id": "device_123",
  "username": "Joe the Mobile User",
  "device_info": {
    "platform": "android",
    "version": "13",
    "model": "Pixel 7"
  }
}

Response:
{
  "user_id": "660e8400-e29b-41d4-a716-446655440001",
  "device_id": "device_123",
  "tenant_id": "tenant_1"
}
```

## Developer Workflow

1. Define database schema in PostgreSQL (one source of truth per tenant)
2. Deploy tenant-specific sync engine
3. Deploy web API service (separate binary)
4. Web users select username and connect via web API service
5. Mobile clients enroll via QR code and select username
6. Mobile clients automatically sync data with PostgreSQL
7. Mobile devices use offline SQLite for most operations; sync when online
8. All users can message each other; messages sync with last-write-wins for `last_message_sent` field

## Mobile App Permissions

The mobile app requests all necessary permissions:

- **Camera**: For QR code scanning during enrollment
- **Internet**: For API communication and schema fetching
- **Network State**: For connectivity monitoring
- **Storage**: For SQLite database
- **Notifications**: For push notifications
- **Background Sync**: For background synchronization
- **Location**: If needed for location-based features
- **Contacts**: If needed for contact integration

## Database Schema

The mobile app uses a hardcoded Drift schema with the following tables:

- **Messages**: Stores all messages with sender_id, recipient_id, content, status, timestamps
- **Users**: Stores user information including `last_message_sent` field that syncs with last-write-wins

The `last_message_sent` field on the users table:
- Gets updated when a user sends a message
- Syncs between mobile and backend with last-write-wins conflict resolution (compares `updated_at` timestamps)
- Displays in the conversation list to show the last message sent by each user

## Roadmap

- [ ] Multi-schema sharding support
- [ ] Conflict resolution strategies
- [ ] GUI for defining schema and sync rules
- [ ] Schema versioning and migration support
- [ ] Full support for intermittent connectivity edge cases
- [ ] Dynamic table creation and updates
- [ ] Schema validation and error handling

## Predefined Users

For the demo application, the following users are available:

- **Web Users**: "Bob the Web User", "Jane the Web User"
- **Mobile Users**: "Joe the Mobile User", "Sally the Mobile User"

Users select their username at login/enrollment (no password required).

## Documentation

- [Go Sync Engine Specification](specs/go-sync-engine.md)
- [Flutter Mobile App Specification](specs/flutter-mobile.md)
- [Flutter Web App Specification](specs/flutter-web.md)
- [Database Schema Documentation](specs/database-schema.md)
- [API Endpoint Documentation](specs/api-endpoints.md)
- [Data Flow Diagrams](specs/data-flow-diagrams.md)
- [BDD Scenario Mapping](specs/bdd-mapping.md)

## License

[Specify your license here]



