# BDD Scenario Mapping

This document maps each BDD scenario from `messenger-demo-app.md` to the implementation components, including API endpoints, database operations, UI components, and sync logic.

## Feature: Web User Sends Message to Mobile User

### Scenario: Web user successfully sends a message to a selected mobile user

**Given Steps:**
- **Web user authenticated**: `AuthService.login()` → `POST /api/auth/login`
- **Viewing user selection**: `UserSelectionScreen` → `GET /api/users`

**When Steps:**
- **Select mobile user**: `UserSelectionScreen` → User selection handler
- **Compose message**: `ComposeScreen` → Message input widget
- **Submit message**: `ComposeScreen` → `POST /api/messages`

**Then Steps:**
- **Message written to database**: `MessageService.Create()` → `INSERT INTO messages`
- **Status set to pending_sync**: Database trigger sets default status
- **Confirmation displayed**: `ComposeScreen` shows success message

**Implementation Components:**
- **API Endpoint**: `POST /api/messages` (see `specs/api-endpoints.md`)
- **Database Operation**: `INSERT INTO messages (sender_id, recipient_id, content, status) VALUES (...)`
- **UI Component**: `ComposeScreen` (Flutter Web)
- **Service**: `MessageService` (Go sync engine)
- **Validation**: `MessageValidator.Validate()` checks content non-empty, recipient exists

### Scenario: Web user sends message with invalid recipient

**Given Steps:**
- **Web user authenticated**: `AuthService.login()` → `POST /api/auth/login`

**When Steps:**
- **Select non-existent user**: `UserSelectionScreen` → Validation fails

**Then Steps:**
- **Error message displayed**: `ComposeScreen` shows error
- **Message not saved**: Validation prevents API call

**Implementation Components:**
- **API Endpoint**: `POST /api/messages` returns `404 Not Found` if recipient invalid
- **Error Code**: `INVALID_RECIPIENT`
- **UI Component**: `ComposeScreen` error handling
- **Validation**: `MessageService.ValidateRecipient()` checks user exists

### Scenario: Web user sends empty message

**Given Steps:**
- **Web user authenticated**: `AuthService.login()`
- **Mobile user selected**: User selection complete

**When Steps:**
- **Attempt empty message**: `ComposeScreen` → Form validation

**Then Steps:**
- **Prevent submission**: Form validation blocks submit
- **Display validation error**: `ComposeScreen` shows field error

**Implementation Components:**
- **UI Component**: `ComposeScreen` form validation
- **Validation**: Client-side and server-side validation
- **Error Code**: `EMPTY_MESSAGE` or `VALIDATION_ERROR`

## Feature: Mobile User Receives Message

### Scenario: Mobile user receives message when online

**Given Steps:**
- **Device online**: `ConnectivityService.isOnline()` returns true
- **Message in backend**: `messages` table with status `pending_sync`

**When Steps:**
- **Sync process runs**: `SyncService.performSync()` → `GET /api/sync/incoming`

**Then Steps:**
- **Message synced to SQLite**: `AppDatabase.messagesDao.insertMessage()`
- **Status updated to synced**: `UPDATE messages SET status = 'synced'`
- **Notification received**: `NotificationService.showNotification()`
- **Message in inbox**: `InboxScreen` displays message

**Implementation Components:**
- **API Endpoint**: `GET /api/sync/incoming` (see `specs/api-endpoints.md`)
- **Database Operations**: 
  - Backend: `UPDATE messages SET status = 'synced', synced_at = NOW()`
  - Mobile: `INSERT INTO messages` (Drift)
- **UI Component**: `InboxScreen` (Flutter Mobile)
- **Service**: `SyncService.syncIncoming()` (Flutter Mobile)
- **Notification**: `NotificationService` (Flutter Mobile)

### Scenario: Mobile user receives message when offline

**Given Steps:**
- **Device offline**: `ConnectivityService.isOnline()` returns false
- **Message in backend**: `messages` table exists

**When Steps:**
- **Device comes online**: `ConnectivityService` detects connectivity
- **Sync process runs**: `SyncService.performSync()` triggered automatically

**Then Steps:**
- **Message synced to SQLite**: Same as online scenario
- **Notification received**: `NotificationService.showNotification()`
- **Message in inbox**: `InboxScreen` displays message

**Implementation Components:**
- **Connectivity Detection**: `ConnectivityService` (Flutter Mobile)
- **Auto-sync Trigger**: `SyncService` listens to connectivity changes
- **API Endpoint**: `GET /api/sync/incoming`
- **Database Operations**: Same as online scenario

### Scenario: Mobile user views incoming message

**Given Steps:**
- **Message received**: Message exists in local SQLite database
- **Message stored locally**: `AppDatabase.messagesDao` has message

**When Steps:**
- **Open messaging interface**: `InboxScreen` → `MessageDetailScreen`

**Then Steps:**
- **Display message**: `MessageDetailScreen` shows content
- **Show sender info**: Join with `users` table to get sender username
- **Show timestamp**: Display `created_at` formatted
- **Show status**: Display `status` indicator

**Implementation Components:**
- **UI Component**: `MessageDetailScreen` (Flutter Mobile)
- **Database Query**: `SELECT m.*, u.username FROM messages m JOIN users u ON m.sender_id = u.id WHERE m.id = ?`
- **Widget**: `MessageBubble` displays message content
- **Widget**: `MessageStatusIndicator` shows status

## Feature: Mobile User Replies to Message

### Scenario: Mobile user replies while online

**Given Steps:**
- **Message received**: Message in local database
- **Device online**: `ConnectivityService.isOnline()` returns true

**When Steps:**
- **Open message**: `MessageDetailScreen` → View message
- **Compose reply**: `ComposeScreen` → Enter reply text
- **Submit reply**: `ComposeScreen` → Save and sync

**Then Steps:**
- **Save to SQLite**: `AppDatabase.messagesDao.insertMessage()` with status `pending_sync`
- **Immediately sync**: `SyncService.syncOutgoing()` → `POST /api/sync/outgoing`
- **Status set to synced**: `UPDATE messages SET status = 'synced'` in local DB
- **Web user sees reply**: SSE event → `WebApp` updates

**Implementation Components:**
- **API Endpoint**: `POST /api/sync/outgoing` (see `specs/api-endpoints.md`)
- **Database Operations**:
  - Mobile: `INSERT INTO messages` then `UPDATE status = 'synced'`
  - Backend: `INSERT INTO messages` with status `synced`
- **UI Component**: `ComposeScreen` (Flutter Mobile)
- **Service**: `SyncService.syncOutgoing()` (Flutter Mobile)
- **Real-time Update**: SSE event `new_message` to web client

### Scenario: Mobile user replies while offline

**Given Steps:**
- **Message received**: Message in local database
- **Device offline**: `ConnectivityService.isOnline()` returns false

**When Steps:**
- **Open message**: `MessageDetailScreen`
- **Compose reply**: `ComposeScreen`
- **Submit reply**: `ComposeScreen` → Save only

**Then Steps:**
- **Save to SQLite**: `AppDatabase.messagesDao.insertMessage()` with status `pending_sync`
- **Status pending_sync**: Message queued for sync
- **Not synced immediately**: `SyncService` queues for later

**Implementation Components:**
- **Database Operation**: `INSERT INTO messages` with status `pending_sync`
- **UI Component**: `ComposeScreen` shows "Will send when online"
- **Service**: `SyncService` detects offline, queues message
- **Widget**: `OfflineIndicator` shows offline status

### Scenario: Mobile user's offline reply syncs when device comes online

**Given Steps:**
- **Reply sent offline**: Message in local DB with status `pending_sync`

**When Steps:**
- **Device comes online**: `ConnectivityService` detects connectivity
- **Sync process runs**: `SyncService.performSync()` → `POST /api/sync/outgoing`

**Then Steps:**
- **Reply synced to backend**: `INSERT INTO messages` in PostgreSQL
- **Status updated**: `UPDATE messages SET status = 'synced'` in local DB
- **Web user notified**: SSE event → `WebApp` receives notification

**Implementation Components:**
- **API Endpoint**: `POST /api/sync/outgoing`
- **Database Operations**:
  - Mobile: `UPDATE messages SET status = 'synced'`
  - Backend: `INSERT INTO messages`
- **Service**: `SyncService.syncOutgoing()` (Flutter Mobile)
- **Real-time Update**: SSE event to web client

## Feature: Web User Receives Notification

### Scenario: Web user receives inbox notification for new message

**Given Steps:**
- **Web user authenticated**: `AuthService.isAuthenticated()` returns true
- **Reply synced**: Message in backend with status `synced`

**When Steps:**
- **Interface polls**: `SSEService` or `PollingService` detects update

**Then Steps:**
- **Inbox icon appears**: `InboxIcon` widget shows badge
- **Unread count displayed**: Badge shows count from `GET /api/messages/unread-count`

**Implementation Components:**
- **API Endpoint**: `GET /api/messages/unread-count` (see `specs/api-endpoints.md`)
- **SSE Event**: `event: new_message` with `unread_count`
- **UI Component**: `InboxIcon` widget (Flutter Web)
- **Service**: `SSEService` or `PollingService` (Flutter Web)

### Scenario: Web user views new message after notification

**Given Steps:**
- **Inbox icon visible**: `InboxIcon` shows notification

**When Steps:**
- **Click inbox icon**: `InboxIcon` → Navigate to `InboxScreen`

**Then Steps:**
- **Messaging interface opens**: `InboxScreen` displays
- **New message displayed**: `InboxScreen` shows message list
- **Inbox icon updates**: Badge count decreases

**Implementation Components:**
- **UI Component**: `InboxScreen` (Flutter Web)
- **Navigation**: `GoRouter` navigates to `/inbox`
- **API Endpoint**: `GET /api/messages` to fetch messages
- **State Update**: `unreadCountProvider` updates

### Scenario: Web user receives multiple notifications

**Given Steps:**
- **Web user authenticated**: `AuthService.isAuthenticated()`
- **Multiple replies synced**: Multiple messages in backend

**When Steps:**
- **Interface polls**: `SSEService` or `PollingService` detects updates

**Then Steps:**
- **Total unread count**: Badge shows sum of all unread messages
- **All unread messages**: `InboxScreen` shows all unread messages

**Implementation Components:**
- **API Endpoint**: `GET /api/messages/unread-count`
- **UI Component**: `InboxScreen` with message list
- **Query**: `SELECT COUNT(*) FROM messages WHERE recipient_id = ? AND status != 'read'`

## Feature: Synchronization Process

### Scenario: Successful bidirectional sync when mobile comes online

**Given Steps:**
- **Device offline**: `ConnectivityService.isOnline()` returns false
- **Pending outgoing**: Messages in local DB with status `pending_sync`
- **New incoming**: Messages in backend with status `pending_sync`

**When Steps:**
- **Device comes online**: `ConnectivityService` detects connectivity
- **Sync triggered**: `SyncService.performSync()` called

**Then Steps:**
- **Outgoing synced**: `POST /api/sync/outgoing` → Messages uploaded
- **Incoming synced**: `GET /api/sync/incoming` → Messages downloaded
- **Status updated**: All messages updated to `synced`
- **Sync completes**: `SyncService` reports success

**Implementation Components:**
- **API Endpoints**: 
  - `GET /api/sync/incoming`
  - `POST /api/sync/outgoing`
- **Service**: `SyncService.performSync()` (Flutter Mobile)
- **Database Operations**: Multiple `UPDATE` statements
- **Sync Metadata**: `UPDATE sync_metadata SET last_sync_timestamp = NOW()`

### Scenario: Sync handles network interruption

**Given Steps:**
- **Sync in progress**: `SyncService.performSync()` running

**When Steps:**
- **Network lost**: `ConnectivityService` detects disconnection

**Then Steps:**
- **Handle interruption**: `SyncService` catches error
- **Mark partial sync**: Messages partially synced remain in `pending_sync`
- **Resume on reconnect**: `SyncService` retries from last successful point

**Implementation Components:**
- **Error Handling**: `SyncService` error handling logic
- **Retry Logic**: Exponential backoff retry mechanism
- **State Management**: Track last successful sync point
- **Database**: Messages remain in `pending_sync` until fully synced

### Scenario: Sync conflict resolution

**Given Steps:**
- **Message modified on both sides**: Same message ID, different content/timestamps

**When Steps:**
- **Sync process runs**: `SyncService.performSync()`

**Then Steps:**
- **Detect conflict**: `ConflictResolver.DetectConflict()`
- **Apply resolution**: `ConflictResolver.Resolve()` uses strategy (last-write-wins)
- **Preserve versions**: Both versions logged if needed

**Implementation Components:**
- **Service**: `ConflictResolver` (Go sync engine)
- **Strategy**: Configurable in `config.yaml` (`conflict_resolution`)
- **Database**: Conflict log table (optional)
- **Logic**: Compare timestamps, apply resolution

### Scenario: Sync with no pending changes

**Given Steps:**
- **Device online**: `ConnectivityService.isOnline()` returns true
- **No pending outgoing**: All messages in local DB have status `synced`
- **No new incoming**: All messages in backend already synced

**When Steps:**
- **Sync process runs**: `SyncService.performSync()`

**Then Steps:**
- **Complete immediately**: No operations needed
- **No database operations**: Skip sync
- **Status unchanged**: `sync_metadata` remains `idle`

**Implementation Components:**
- **Service**: `SyncService.performSync()` early return
- **API Endpoint**: `GET /api/sync/status` returns no pending messages
- **Optimization**: Skip sync if no changes detected

## Feature: Offline-First Mobile Experience

### Scenario: Mobile user can view messages while offline

**Given Steps:**
- **Device offline**: `ConnectivityService.isOnline()` returns false
- **Messages in local DB**: `AppDatabase.messagesDao` has messages

**When Steps:**
- **Open messaging interface**: `InboxScreen` loads

**Then Steps:**
- **Display local messages**: Query local SQLite database
- **Show offline status**: `OfflineIndicator` widget displays
- **Allow read/compose**: UI remains functional

**Implementation Components:**
- **UI Component**: `InboxScreen` (Flutter Mobile)
- **Database Query**: `SELECT * FROM messages ORDER BY created_at DESC`
- **Widget**: `OfflineIndicator` shows offline status
- **Service**: All operations use local database

### Scenario: Mobile user can compose messages while offline

**Given Steps:**
- **Device offline**: `ConnectivityService.isOnline()` returns false

**When Steps:**
- **Compose message**: `ComposeScreen` → Enter message
- **Submit message**: `ComposeScreen` → Save

**Then Steps:**
- **Save to SQLite**: `AppDatabase.messagesDao.insertMessage()`
- **Mark pending_sync**: Status set to `pending_sync`
- **Show confirmation**: "Message will be sent when online"

**Implementation Components:**
- **UI Component**: `ComposeScreen` (Flutter Mobile)
- **Database Operation**: `INSERT INTO messages` with status `pending_sync`
- **Widget**: Status message shows pending state
- **Service**: `MessageService` works offline

### Scenario: Mobile app initializes with local data

**Given Steps:**
- **App launched**: `main.dart` → App initialization
- **Data in local DB**: `AppDatabase` has existing messages

**When Steps:**
- **App initializes**: `AppDatabase` opens connection

**Then Steps:**
- **Load from local DB**: `InboxScreen` queries local database immediately
- **UI displays without network**: No network wait
- **Background sync**: `SyncService` attempts sync if network available

**Implementation Components:**
- **Database**: `AppDatabase` initialization (Drift)
- **UI Component**: `InboxScreen` loads from local DB
- **Service**: `SyncService` runs in background
- **Architecture**: Offline-first design

## Feature: User Selection and Management

### Scenario: Web user selects mobile user from list

**Given Steps:**
- **Web user authenticated**: `AuthService.isAuthenticated()`
- **Multiple mobile users**: `users` table has mobile users

**When Steps:**
- **View user selection**: `UserSelectionScreen` loads

**Then Steps:**
- **List displayed**: `GET /api/users?user_type=mobile`
- **Show online/offline status**: `UserStatusIndicator` widget
- **Allow selection**: User can tap to select

**Implementation Components:**
- **API Endpoint**: `GET /api/users` (see `specs/api-endpoints.md`)
- **UI Component**: `UserSelectionScreen` (Flutter Web)
- **Widget**: `UserListItem` displays user info
- **Widget**: `UserStatusIndicator` shows online/offline

### Scenario: Web user filters mobile users

**Given Steps:**
- **Viewing user selection**: `UserSelectionScreen` open
- **Many mobile users**: Large user list

**When Steps:**
- **Apply filter**: Search input or filter dropdown

**Then Steps:**
- **List filtered**: Client-side or server-side filtering
- **Only matching users**: Filtered results displayed

**Implementation Components:**
- **UI Component**: `UserSelectionScreen` with search/filter
- **API Endpoint**: `GET /api/users?filter=search_term`
- **State Management**: Filter state in `UserController`

## Feature: Message Status Tracking

### Scenario: Message status updates through lifecycle

**Given Steps:**
- **Web user sends message**: Message created

**When/Then Steps:**
- **Message created**: Status = `pending_sync` (default)
- **Synced to mobile**: Status = `synced` (trigger updates)
- **Mobile user reads**: Status = `read` (mobile updates, synced back)

**Implementation Components:**
- **Database Triggers**: Auto-update `synced_at` and `read_at`
- **Status Updates**: `UPDATE messages SET status = ?`
- **UI Components**: `MessageStatusIndicator` shows status
- **Sync Logic**: Status synced bidirectionally

### Scenario: Reply status tracking

**Given Steps:**
- **Mobile user sends reply**: Reply created locally

**When/Then Steps:**
- **Saved locally offline**: Status = `pending_sync`
- **Synced to backend**: Status = `synced`
- **Web user views**: Status = `read` (optional tracking)

**Implementation Components:**
- **Database Operations**: Status updates in both databases
- **Sync Logic**: Status synchronization
- **UI Components**: Status indicators in both apps

## Feature: Error Handling

### Scenario: Database write failure on web

**Given Steps:**
- **Web user sends message**: `ComposeScreen` → Submit

**When Steps:**
- **Database write fails**: PostgreSQL error

**Then Steps:**
- **Error message displayed**: `ComposeScreen` shows error
- **Message not saved**: Transaction rolled back
- **Retry available**: User can retry send

**Implementation Components:**
- **Error Handling**: `MessageService.Create()` error handling
- **UI Component**: `ComposeScreen` error display
- **Retry Logic**: User can resubmit
- **Error Code**: `DATABASE_ERROR`

### Scenario: Sync failure on mobile

**Given Steps:**
- **Device comes online**: Connectivity restored
- **Pending messages**: Messages with status `pending_sync`

**When Steps:**
- **Sync fails**: Backend error or network error

**Then Steps:**
- **Messages remain pending_sync**: Status unchanged
- **Auto retry**: `SyncService` retries with backoff
- **Notify if persistent**: User notified after max retries

**Implementation Components:**
- **Error Handling**: `SyncService` error handling
- **Retry Logic**: Exponential backoff retry
- **UI Component**: `SyncStatusIndicator` shows error
- **Notification**: User notification after persistent failure

### Scenario: Local database corruption on mobile

**Given Steps:**
- **Corrupted SQLite**: Database file corrupted

**When Steps:**
- **App reads messages**: `AppDatabase` query fails

**Then Steps:**
- **Detect corruption**: Database error caught
- **Recover or reinitialize**: Attempt recovery or recreate DB
- **Trigger full sync**: Sync all data from backend when possible

**Implementation Components:**
- **Error Detection**: `AppDatabase` error handling
- **Recovery Logic**: Database recovery or reinitialization
- **Sync Logic**: Full sync from backend
- **UI Component**: Error message to user

## Feature: Real-time Updates (Web)

### Scenario: Web user sees live message updates

**Given Steps:**
- **Active session**: Web user logged in
- **Interface connected**: `SSEService` connected

**When Steps:**
- **Mobile user sends reply**: Reply synced to backend

**Then Steps:**
- **Interface updates automatically**: SSE event received
- **Inbox icon appears**: Badge updates
- **Message visible**: Conversation updates

**Implementation Components:**
- **SSE Endpoint**: `GET /sse/web/:user_id`
- **SSE Service**: `SSEService` (Flutter Web)
- **UI Update**: `MessageController` updates state
- **Real-time**: No page refresh needed

### Scenario: Web user interface reflects message status changes

**Given Steps:**
- **Message sent**: Message in backend
- **Status changes**: Status updated in backend

**When Steps:**
- **Interface polls**: `SSEService` or `PollingService` checks updates

**Then Steps:**
- **Status updated in UI**: `MessageStatusIndicator` updates
- **Current status shown**: Status reflects backend state

**Implementation Components:**
- **Polling**: `PollingService` polls `GET /api/messages`
- **SSE**: SSE events for status changes
- **UI Component**: `MessageStatusIndicator` widget
- **State Management**: Message state updates

## Feature: Notification Management

### Scenario: Mobile user receives push notification for new message

**Given Steps:**
- **Device online**: `ConnectivityService.isOnline()` returns true
- **New message synced**: Message in local database

**When Steps:**
- **Message received**: `SyncService` saves message

**Then Steps:**
- **Push notification triggered**: `NotificationService.showNotification()`
- **Sender and preview displayed**: Notification shows sender and content preview
- **Tapping opens message**: Notification tap opens `MessageDetailScreen`

**Implementation Components:**
- **Service**: `NotificationService` (Flutter Mobile)
- **Platform**: `flutter_local_notifications` package
- **Navigation**: Deep link to message on tap
- **Content**: Notification payload with sender and preview

### Scenario: Mobile user dismisses notification

**Given Steps:**
- **Notification received**: Notification displayed

**When Steps:**
- **User dismisses**: User swipes or dismisses notification

**Then Steps:**
- **Notification removed**: Notification cleared
- **Message accessible**: Message still in app
- **Unread indicator remains**: Badge shows until read

**Implementation Components:**
- **Service**: `NotificationService` handles dismissal
- **UI Component**: Unread badge in `InboxScreen`
- **State**: Message remains unread until opened

## Feature: Mobile User Enrollment

### Scenario: Web user enrolls mobile user via QR code

**Given Steps:**
- **Web user authenticated**: `AuthService.isAuthenticated()` returns true
- **Web user viewing user selection**: `UserSelectionScreen` open

**When Steps:**
- **Click "Enroll Mobile User"**: Button in `UserSelectionScreen`
- **Navigate to enrollment screen**: `EnrollmentScreen` opens
- **Create enrollment**: `EnrollmentService.createEnrollment()` called

**Then Steps:**
- **Enrollment token created**: `POST /api/enrollment/create` → Token in database
- **QR code generated**: QR code data created with enrollment URL
- **QR code displayed**: `QRCodeWidget` shows QR code
- **Enrollment status tracked**: `EnrollmentStatusWidget` shows pending status

**Implementation Components:**
- **API Endpoint**: `POST /api/enrollment/create` (see `specs/api-endpoints.md`)
- **Database Operation**: `INSERT INTO enrollment_tokens`
- **UI Component**: `EnrollmentScreen` (Flutter Web)
- **Service**: `EnrollmentService` (Flutter Web)
- **Widget**: `QRCodeWidget` displays QR code

### Scenario: Mobile user scans QR code and enrolls

**Given Steps:**
- **Container app launched**: App checks enrollment status
- **App not enrolled**: `EnrollmentService.isEnrolled()` returns false
- **QR code displayed**: Web interface shows enrollment QR code

**When Steps:**
- **Open container app**: App shows QR scanner screen
- **Scan QR code**: `QRScannerWidget` scans code
- **Parse QR data**: Extract token from QR code
- **Validate token**: `GET /api/enrollment/:token`
- **Complete enrollment**: `POST /api/enrollment/complete`

**Then Steps:**
- **Token validated**: Backend confirms token is valid
- **Mobile user created**: `INSERT INTO users` with user_type='mobile'
- **Device linked**: Device ID linked to user
- **App instructions fetched**: `GET /api/app-instructions`
- **Remote widgets loaded**: Widgets fetched from CDN
- **App ready**: Messaging interface displayed

**Implementation Components:**
- **API Endpoints**: 
  - `GET /api/enrollment/:token`
  - `POST /api/enrollment/complete`
  - `GET /api/app-instructions`
- **Database Operations**:
  - `UPDATE enrollment_tokens SET used_at = NOW()`
  - `INSERT INTO users` (mobile user)
- **UI Component**: `EnrollmentScreen` (Flutter Mobile Container App)
- **Service**: `EnrollmentService` (Flutter Mobile)
- **Service**: `RemoteWidgetLoader` loads widgets

### Scenario: Mobile app fetches app instructions after enrollment

**Given Steps:**
- **Enrollment completed**: Mobile user created and device linked
- **App instructions URL received**: From enrollment completion response

**When Steps:**
- **Fetch app instructions**: `GET /api/app-instructions` with device ID

**Then Steps:**
- **App instructions returned**: JSON with widget URLs and config
- **Tenant ID stored**: Stored in local app config
- **API base URL stored**: Stored for API client
- **Widget URLs available**: Ready for remote widget loading

**Implementation Components:**
- **API Endpoint**: `GET /api/app-instructions` (see `specs/api-endpoints.md`)
- **Database Operation**: Query user and tenant config
- **Service**: `AppInstructionsService` (Flutter Mobile)
- **Storage**: App config stored in local database
- **Service**: `APIClient` configured with tenant-specific base URL

