# Posduif – Offline-First Multi-Tenant Mobile & Web Sync Engine

Posduif is a self-hosted, open-source sync engine designed for offline-first mobile applications and web users. It enables seamless real-time synchronization between Flutter mobile clients (using SQLite) and a PostgreSQL backend, with per-tenant schemas and full control over which tables are synced. Web users connect directly to PostgreSQL with live database access and do not participate in synchronization. The schema is defined once on the backend and fetched at runtime by mobile clients during enrollment, configuring the Drift ORM database dynamically.

Posduif is built for FOSS environments, scalable deployments, and intermittent connectivity, providing developers with a single place to define tenant-specific data models and sync rules.

## Features

### Offline-First Mobile Sync

- Mobile apps use SQLite (Drift) as the primary offline database
- **Runtime Schema Configuration**: Schema is defined once on the backend and fetched during QR code enrollment, configuring Drift ORM tables dynamically at runtime
- **QR Code Enrollment**: Mobile users enroll by scanning QR codes displayed in the web interface
- Tables can be marked as:
  - `mobile-synced` → automatically synchronized
  - `mobile-only` → local to device
  - `web-only` → backend only
- Supports partial sync based on developer-defined rules
- Online operations possible when connectivity is available

### Multi-Tenant Backend

- Single PostgreSQL database per tenant, with a schema per tenant
- Each tenant has a dedicated Go sync engine instance to ensure tennant isolation.
- Web users connect directly to PostgreSQL with live database access (no synchronization)
- Schema changes propagate to both SQLite on device and PostgreSQL backend
- **Tenant Enrollment**: QR code-based enrollment links mobile devices to specific tenants

### Real-Time Updates

- Mobile clients receive sync updates via Server-Sent Events (SSE) (Chosen over WebSocktets or API polling as it is more power efficient as as single long-lived HTTP connection over bi-directional keep-alives)
- Web clients receive real-time notifications via SSE (notifications only, not data synchronization)

### Scalable, Self-Hosted Infrastructure

- Uses Redis Streams (disk-backed) for fan-out and event distribution (Closest to a Kafka type setup without actually implementing Kafka which is not the best fit here)
- Full self-hosted stack – no third-party SaaS dependencies
- Designed for horizontal scaling via multiple sync engine instances

### Compression & Connectivity

- All mobile sync data is compressed in both directions (PostgreSQL ↔ SQLite)
- Built to handle intermittent or poor network connectivity gracefully for mobile devices

### Unified Data Modeling

- Developers define data models / ERDs in code once
- Changes propagate automatically:
  - Mobile device SQLite
  - PostgreSQL backend
- Simplifies schema evolution per tenant

## Architecture

### Architecture Overview

Posduif uses two distinct data access patterns:

- **Web Users**: Connect directly to PostgreSQL with live database access via the Go sync engine API. No synchronization is required as web users always have a direct connection to the database.
- **Mobile Users**: Use SQLite (Drift) as an offline-first local database that synchronizes bidirectionally with PostgreSQL via the sync engine. Mobile devices sync data when online and work offline when connectivity is unavailable.

The sync engine handles synchronization between PostgreSQL and mobile SQLite databases only. Web users access data directly through the API layer.

### Mobile Application Architecture

The mobile application uses a **schema-driven architecture** where the database schema is fetched from the backend during enrollment:

```
┌─────────────────────────────────────────────────┐
│         Mobile App (Flutter)                     │
│  - QR code scanner                              │
│  - Enrollment service                           │
│  - Schema fetcher                               │
│  - Drift ORM (runtime configured)              │
│  - Sync service                                 │
│  - Shared services (database, API)            │
└─────────────────────────────────────────────────┘
                    │
                    │ Fetches Schema
                    ▼
┌─────────────────────────────────────────────────┐
│         Go Sync Engine (Backend)                │
│  - API endpoints                                │
│  - Enrollment service                           │
│  - Schema endpoint                              │
│  - Sync manager (mobile ↔ PostgreSQL)         │
│  - PostgreSQL (schema definition)               │
└─────────────────────────────────────────────────┘
                    ▲
                    │ Direct DB Access
                    │
┌─────────────────────────────────────────────────┐
│         Web App (Flutter)                       │
│  - API client                                   │
│  - Live PostgreSQL queries                      │
│  - SSE notifications                            │
└─────────────────────────────────────────────────┘
```

### QR Code Enrollment Flow

1. **Web User Initiates Enrollment**: Web user clicks "Enroll Mobile User" in the web interface
2. **Backend Creates Token**: Backend generates a unique enrollment token and QR code data
3. **QR Code Displayed**: Web interface displays QR code with enrollment URL
4. **Mobile Scans QR Code**: Container app scans QR code using camera permission
5. **Mobile Validates Token**: Mobile app calls backend to validate enrollment token
6. **Mobile Completes Enrollment**: Mobile app sends device information to complete enrollment
7. **Backend Creates User**: Backend creates mobile user account and links device to tenant
8. **Mobile Fetches Schema**: Mobile app fetches database schema configuration from backend
9. **Mobile Configures Database**: Drift ORM configures database tables dynamically using fetched schema
10. **App Ready**: Mobile app is configured and ready for use

### Tech Stack

- **Mobile**: 
  - Flutter app with all necessary permissions
  - Runtime schema configuration with Drift ORM
  - Drift (SQLite) for offline-first data storage
  - Riverpod for state management
  - QR code scanner for enrollment
  - Bidirectional sync with PostgreSQL backend
- **Web**: Flutter web application
  - Direct PostgreSQL access via Go sync engine API
  - Live database queries (no synchronization)
  - SSE for real-time notifications
- **Backend**: Go sync engine
  - Handles mobile ↔ PostgreSQL synchronization
  - Provides API for web users to access PostgreSQL
- **Database**: PostgreSQL (schema-per-tenant)
- **Messaging**: Redis Streams (disk-backed)
- **Realtime**: SSE (Server-Sent Events)

## Getting Started

### Prerequisites

- PostgreSQL ≥ 16
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
- PostgreSQL 16
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

### 5. Run the sync engine

```bash
go run ./cmd/sync-engine/main.go --config=config/config.yaml
```

### 6. Mobile setup

#### Mobile App

The mobile app should:
- Request all necessary permissions (camera, storage, network, etc.)
- Implement QR code scanner for enrollment
- Fetch database schema from backend during enrollment
- Configure Drift ORM tables dynamically using fetched schema
- Provide shared services (sync, database, API client)

#### Enrollment Process

1. Launch mobile app (shows QR scanner if not enrolled)
2. Web user generates enrollment QR code
3. Mobile user scans QR code
4. App automatically enrolls and fetches database schema
5. App configures database and displays messaging interface

### 7. Web setup

The Flutter web application provides:
- User authentication
- Direct PostgreSQL database access via API (live queries, no synchronization)
- Mobile user enrollment (QR code generation)
- User selection and messaging interface
- Real-time notifications via SSE (notifications only, not data synchronization)

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
  "tenant_id": "tenant_1",
  "app_instructions_url": "https://backend.example.com/api/app-instructions"
}
```

### Get App Instructions (Mobile)

```http
GET /api/app-instructions
X-Device-ID: device_123

Response:
{
  "version": "1.0.0",
  "tenant_id": "tenant_1",
  "api_base_url": "https://backend.example.com",
  "schema": {
    "tables": [
      {
        "name": "messages",
        "columns": [
          {"name": "id", "type": "text", "primary_key": true},
          {"name": "sender_id", "type": "text", "nullable": false},
          {"name": "recipient_id", "type": "text", "nullable": false},
          {"name": "content", "type": "text", "nullable": false},
          {"name": "status", "type": "text", "nullable": false},
          {"name": "created_at", "type": "datetime", "nullable": false},
          {"name": "updated_at", "type": "datetime", "nullable": false},
          {"name": "synced_at", "type": "datetime", "nullable": true},
          {"name": "read_at", "type": "datetime", "nullable": true}
        ],
        "indexes": []
      }
    ]
  },
  "sync_config": {
    "batch_size": 100,
    "compression": true
  }
}
```

## Developer Workflow

1. Define schema in code (one source of truth per tenant)
2. Specify table sync rules:
   - Mobile-synced
   - Mobile-only
   - Web-only
   - Partial sync filters
3. Deploy tenant-specific sync engine
4. Web users connect directly to PostgreSQL via API (live database access)
5. Mobile clients enroll via QR code
6. Mobile clients fetch schema and configure database at runtime
7. Mobile clients automatically sync data with PostgreSQL via SSE
8. Mobile devices use offline SQLite for most operations; sync when online

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

## Runtime Schema Configuration

The database schema is defined once on the backend and fetched during enrollment:

- **Single Source of Truth**: Schema defined in PostgreSQL backend
- **Runtime Configuration**: Drift ORM configures tables dynamically using fetched schema
- **Tenant-Specific**: Each tenant can have different schema definitions
- **Version Control**: Schema versions tracked and updated automatically

## Roadmap

- [ ] Multi-schema sharding support
- [ ] Conflict resolution strategies
- [ ] GUI for defining schema and sync rules
- [ ] Schema versioning and migration support
- [ ] Full support for intermittent connectivity edge cases
- [ ] Dynamic table creation and updates
- [ ] Schema validation and error handling

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



