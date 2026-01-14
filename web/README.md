# Posduif Web Application

Hardcoded Flutter web messenger application with WhatsApp-style interface. Connects directly to PostgreSQL via separate web API service (no synchronization).

## Features

- **WhatsApp-Style UI**: Conversation list and chat screens with message bubbles
- **Username Selection**: Choose between "Bob the Web User" or "Jane the Web User" (no password)
- **Direct Database Access**: Connects to PostgreSQL via separate web API service
- **Real-Time Updates**: Polls for new messages and updates
- **Last Message Sent**: Shows last message sent by each user in conversation list

## Structure

- `lib/core/` - Core functionality
  - `api/` - API client for web API service (port 8081)
  - `auth/` - Authentication service (username-only)
  - `models/` - Data models (User, Message)
  - `providers/` - Riverpod state management
  - `router/` - Navigation routing
- `lib/features/` - Feature modules
  - `auth/` - Username selection/login screen
  - `messaging/` - Conversation list, chat screen
  - `enrollment/` - Mobile user enrollment (QR code generation)
- `lib/shared/` - Shared utilities and widgets

## Architecture

The web app connects to a **separate Go API service** (web-api) running on port 8081:

- **No Synchronization**: Web users access database directly via API
- **Username-Based Auth**: No passwords, just username selection
- **Real-Time**: Polls API for updates or uses SSE notifications

## Development

```bash
# Install dependencies
flutter pub get

# Run in Chrome
flutter run -d chrome

# Build for production
flutter build web

# Run tests
flutter test
```

## API Service

The web app requires the web API service to be running:

```bash
cd ../web-api
go run ./cmd/web-api/main.go --config=../config/config.yaml
```

The web API service runs on port 8081 by default.

## User Flow

1. Open web app → Shows username selection screen
2. Select username (Bob or Jane)
3. View conversation list with all users
4. Click user to start conversation
5. Send/receive messages in real-time

## Dependencies

All dependencies are FOSS (Free and Open Source Software) with permissive licenses:
- `flutter_riverpod` - State management
- `go_router` - Navigation
- `dio` - HTTP client
- `intl` - Date/time formatting
