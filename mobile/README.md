# Posduif Mobile App

Hardcoded Flutter messenger application with offline-first architecture using Drift ORM. Features a WhatsApp-style chat interface with real-time synchronization.

## Features

- **WhatsApp-Style UI**: Conversation list and chat screens with message bubbles
- **Username Selection**: Choose between "Joe the Mobile User" or "Sally the Mobile User" (no password)
- **QR Code Enrollment**: Scan QR code to enroll device and select username
- **Offline-First**: Messages stored locally in SQLite, sync when online
- **Real-Time Sync**: Bidirectional sync with PostgreSQL backend
- **Last Message Sent**: Shows last message sent by each user in conversation list (syncs with last-write-wins)

## Structure

- `lib/core/` - Core functionality (API, database, sync, enrollment)
  - `database/` - Drift database with hardcoded schema (Messages, Users tables)
  - `sync/` - Sync service for bidirectional synchronization
  - `api/` - API client for sync engine communication
  - `enrollment/` - Enrollment service for QR code scanning
- `lib/features/` - Feature modules
  - `auth/` - Username selection screen
  - `enrollment/` - QR scanner screen
  - `messaging/` - Conversation list, chat screen, and widgets
- `lib/shared/` - Shared utilities and widgets

## Database Schema

The app uses a hardcoded Drift schema:

- **Messages**: id, senderId, recipientId, content, status, timestamps
- **Users**: id, username, userType, deviceId, onlineStatus, lastSeen, **lastMessageSent**, timestamps

The `lastMessageSent` field syncs with the backend using last-write-wins conflict resolution.

## Development

```bash
# Install dependencies
flutter pub get

# Generate Drift code
flutter pub run build_runner build

# Run on device/emulator
flutter run

# Run tests
flutter test
```

## Enrollment Flow

1. Launch app → Shows QR scanner if not enrolled
2. Scan enrollment QR code from web interface
3. Select username (Joe or Sally)
4. Enrollment completes → Navigate to conversation list
5. Start messaging!

## Sync Flow

- **Outgoing**: Messages saved locally with `pending_sync` status → Synced to backend when online
- **Incoming**: Backend messages synced to local database → Users table synced with `last_message_sent` field
- **Conflict Resolution**: `last_message_sent` uses last-write-wins (compares `updated_at` timestamps)

## Dependencies

All dependencies are FOSS (Free and Open Source Software) with permissive licenses:
- `drift` - SQLite ORM
- `flutter_riverpod` - State management
- `go_router` - Navigation
- `mobile_scanner` - QR code scanning
- `connectivity_plus` - Network connectivity
- `dio` - HTTP client
