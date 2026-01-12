# Posduif Project Structure

This document outlines the folder structure for the Posduif project.

## Root Structure

```
posduif/
├── .cursorrules              # Root Cursor rules (FOSS-only enforcement)
├── .gitignore               # Git ignore patterns
├── README.md                # Main project documentation
├── PROJECT_STRUCTURE.md     # This file
├── Vagrantfile              # Development environment setup
│
├── config/                  # Shared configuration files
│   ├── config.yaml          # Sync engine configuration
│   └── database-init.sql    # Database initialization script
│
├── scripts/                  # Setup and initialization scripts
│   ├── setup.sh
│   ├── init-db.sh
│   └── init-redis.sh
│
├── specs/                   # Project specifications
│   ├── api-endpoints.md
│   ├── bdd-mapping.md
│   ├── data-flow-diagrams.md
│   ├── database-schema.md
│   ├── flutter-mobile.md
│   ├── flutter-web.md
│   └── go-sync-engine.md
│
├── sync-engine/             # Go sync engine backend
│   ├── .cursorrules         # Go-specific Cursor rules
│   ├── go.mod               # Go module definition
│   ├── README.md            # Sync engine documentation
│   ├── cmd/
│   │   └── sync-engine/
│   │       └── main.go      # Application entry point
│   ├── internal/            # Private application code
│   │   ├── api/
│   │   │   ├── handlers/    # HTTP handlers
│   │   │   ├── middleware/  # HTTP middleware
│   │   │   └── sse/         # Server-Sent Events handlers
│   │   ├── database/        # PostgreSQL connection and queries
│   │   ├── models/          # Data models
│   │   ├── enrollment/      # Enrollment service
│   │   ├── sync/            # Sync logic
│   │   ├── message/         # Message service
│   │   ├── redis/           # Redis client
│   │   └── compression/     # Compression utilities
│   └── config/              # Configuration files
│
├── mobile/                  # Flutter mobile container app
│   ├── .cursorrules         # Flutter mobile-specific Cursor rules
│   ├── pubspec.yaml         # Flutter dependencies
│   ├── README.md            # Mobile app documentation
│   ├── lib/
│   │   ├── main.dart        # Application entry point
│   │   ├── core/            # Core functionality
│   │   │   ├── api/         # API client
│   │   │   ├── database/   # Drift database setup
│   │   │   ├── sync/       # Sync service
│   │   │   └── enrollment/ # Enrollment service
│   │   ├── features/        # Feature modules
│   │   │   ├── auth/       # Authentication
│   │   │   ├── enrollment/ # QR code enrollment
│   │   │   └── messaging/  # Messaging UI
│   │   └── shared/          # Shared utilities
│   │       ├── widgets/    # Reusable widgets
│   │       └── utils/      # Utility functions
│   ├── test/               # Tests
│   ├── android/            # Android-specific code
│   ├── ios/                # iOS-specific code
│   └── web/                # Web-specific code (if needed)
│
└── web/                    # Flutter web application
    ├── .cursorrules         # Flutter web-specific Cursor rules
    ├── pubspec.yaml         # Flutter dependencies
    ├── README.md            # Web app documentation
    ├── lib/
    │   ├── main.dart        # Application entry point
    │   ├── core/            # Core functionality
    │   │   ├── api/         # API client
    │   │   └── auth/        # Authentication service
    │   ├── features/        # Feature modules
    │   │   ├── auth/       # Authentication UI
    │   │   ├── enrollment/ # Mobile user enrollment
    │   │   └── messaging/  # Messaging UI
    │   └── shared/          # Shared utilities
    │       ├── widgets/    # Reusable widgets
    │       └── utils/      # Utility functions
    ├── test/               # Tests
    └── web/                # Web-specific assets and config
```

## Cursor Rules

Each major folder has a `.cursorrules` file that enforces:

1. **FOSS-only libraries**: Only open-source libraries with permissive licenses
2. **Language-specific best practices**: Go, Flutter, and Dart conventions
3. **Project-specific guidelines**: Architecture patterns and coding standards

### Root `.cursorrules`
- General project principles
- FOSS-only enforcement
- Technology stack overview

### `sync-engine/.cursorrules`
- Go 1.21+ conventions
- Allowed FOSS Go libraries
- Project structure guidelines
- Database and API design patterns

### `mobile/.cursorrules`
- Flutter 3.13+ conventions
- Allowed FOSS Flutter packages
- Offline-first architecture
- Container app patterns

### `web/.cursorrules`
- Flutter Web conventions
- Allowed FOSS Flutter packages
- Real-time updates (SSE)
- Web-specific optimizations

## Dependencies

All dependencies must be:
- **FOSS (Free and Open Source Software)**
- **Permissive licenses** (MIT, Apache 2.0, BSD)
- **No proprietary or commercial dependencies**
- **No third-party SaaS dependencies**

## Development Workflow

1. **Sync Engine**: `cd sync-engine && go run ./cmd/sync-engine/main.go`
2. **Mobile App**: `cd mobile && flutter run`
3. **Web App**: `cd web && flutter run -d chrome`

## Notes

- All empty directories contain `.gitkeep` files to ensure they're tracked by git
- Configuration files with secrets should be in `.gitignore`
- Each component has its own README with specific setup instructions



