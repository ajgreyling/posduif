# Posduif – Offline-First Multi-Tenant Mobile & Web Sync Engine

Posduif is a self-hosted, open-source sync engine designed for offline-first mobile applications and web users. It enables seamless real-time synchronization between Flutter mobile clients (using Flutter Remote Widgets with a container app), web users, and a PostgreSQL backend, with per-tenant schemas and full control over which tables are synced.

Posduif is built for FOSS environments, scalable deployments, and intermittent connectivity, providing developers with a single place to define tenant-specific data models and sync rules.

## Features

### Offline-First Mobile Sync

- Mobile apps use SQLite (Drift) as the primary offline database
- **Flutter Remote Widgets**: Mobile app uses a container app architecture with remote widgets fetched from the backend
- **QR Code Enrollment**: Mobile users enroll by scanning QR codes displayed in the web interface
- Tables can be marked as:
  - `mobile-synced` → automatically synchronized
  - `mobile-only` → local to device
  - `web-only` → backend only
- Supports partial sync based on developer-defined rules
- Online operations possible when connectivity is available

### Multi-Tenant Backend

- Single PostgreSQL database per tenant, with a schema per tenant
- Each tenant has a dedicated Go sync engine instance
- Schema changes propagate to both SQLite on device and PostgreSQL backend
- **Tenant Enrollment**: QR code-based enrollment links mobile devices to specific tenants

### Real-Time Updates

- Mobile clients receive updates via Server-Sent Events (SSE)
- Low power consumption for mobile devices
- Web clients receive real-time notifications via SSE

### Scalable, Self-Hosted Infrastructure

- Uses Redis Streams (disk-backed) for fan-out and event distribution
- Full self-hosted stack – no third-party SaaS dependencies
- Designed for horizontal scaling via multiple sync engine instances

### Compression & Connectivity

- All synced data is compressed in both directions
- Built to handle intermittent or poor network connectivity gracefully

### Unified Data Modeling

- Developers define data models / ERDs in code once
- Changes propagate automatically:
  - Mobile device SQLite
  - PostgreSQL backend
- Simplifies schema evolution per tenant

## Architecture

### Mobile Application Architecture

The mobile application uses a **container app** architecture with **Flutter Remote Widgets**:

```
┌─────────────────────────────────────────────────┐
│         Container App (Flutter)                 │
│  - All permissions (camera, storage, etc.)      │
│  - QR code scanner                              │
│  - Remote widget loader                         │
│  - Enrollment service                           │
│  - Shared services (sync, database, API)       │
└─────────────────────────────────────────────────┘
                    │
                    │ Fetches & Renders
                    ▼
┌─────────────────────────────────────────────────┐
│      Remote Widgets (Tenant-Specific UI)        │
│  - Inbox screen                                 │
│  - Message detail screen                        │
│  - Compose screen                               │
│  - Widgets (message list, bubbles, etc.)        │
└─────────────────────────────────────────────────┘
                    │
                    │ Syncs Data
                    ▼
┌─────────────────────────────────────────────────┐
│         Go Sync Engine (Backend)                │
│  - API endpoints                                │
│  - Enrollment service                           │
│  - App instructions endpoint                    │
│  - Sync manager                                 │
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
8. **Mobile Fetches Instructions**: Mobile app fetches app instructions (remote widget URLs, config)
9. **Mobile Loads Remote Widgets**: Container app loads and renders tenant-specific remote widgets
10. **App Ready**: Mobile app is configured and ready for use

### Tech Stack

- **Mobile**: 
  - Flutter container app with all permissions
  - Flutter Remote Widgets for tenant-specific UI
  - Drift (SQLite) for offline-first data storage
  - Riverpod for state management
  - QR code scanner for enrollment
- **Web**: Flutter web application
- **Backend**: Go sync engine
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
- Flutter Remote Widgets package

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

#### Container App

The mobile container app should:
- Request all necessary permissions (camera, storage, network, etc.)
- Implement QR code scanner for enrollment
- Load remote widgets based on app instructions from backend
- Provide shared services (sync, database, API client)

#### Enrollment Process

1. Launch container app (shows QR scanner if not enrolled)
2. Web user generates enrollment QR code
3. Mobile user scans QR code
4. App automatically enrolls and fetches remote widgets
5. App displays tenant-specific messaging interface

### 7. Web setup

The Flutter web application provides:
- User authentication
- Mobile user enrollment (QR code generation)
- User selection and messaging interface
- Real-time updates via SSE

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
  "widgets": {
    "inbox": {
      "type": "remote_widget",
      "url": "https://cdn.example.com/widgets/inbox.json"
    },
    "compose": {
      "type": "remote_widget",
      "url": "https://cdn.example.com/widgets/compose.json"
    }
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
4. Mobile clients enroll via QR code
5. Mobile clients automatically receive remote widget updates
6. Mobile clients automatically sync data via SSE
7. Use offline SQLite for most operations; fall back to online API calls as needed

## Container App Permissions

The container app requests all necessary permissions:

- **Camera**: For QR code scanning during enrollment
- **Internet**: For API communication and remote widget fetching
- **Network State**: For connectivity monitoring
- **Storage**: For SQLite database
- **Notifications**: For push notifications
- **Background Sync**: For background synchronization
- **Location**: If needed for location-based features
- **Contacts**: If needed for contact integration

## Remote Widgets

Remote widgets are tenant-specific UI components fetched from the backend:

- **Dynamic UI**: Each tenant can have custom UI without app updates
- **Version Control**: Widget versions tracked and updated automatically
- **CDN Support**: Widgets can be served from CDN for performance
- **Offline Fallback**: Cached widgets work offline

## Roadmap

- [ ] Multi-schema sharding support
- [ ] Conflict resolution strategies
- [ ] GUI for defining schema and sync rules
- [ ] Flutter Remote Widgets integration examples
- [ ] Full support for intermittent connectivity edge cases
- [ ] Widget versioning and rollback
- [ ] Widget caching strategies

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

