# Data Flow Diagrams

This document contains mermaid diagrams illustrating the key data flows in the Posduif messaging application.

## Message Send Flow (Web → Mobile)

This diagram shows the complete flow when a web user sends a message to a mobile user.

```mermaid
sequenceDiagram
    participant WebUser as Web User
    participant WebApp as Flutter Web App
    participant API as Go Sync Engine
    participant DB as PostgreSQL
    participant Redis as Redis Streams
    participant MobileApp as Flutter Mobile App
    participant MobileDB as SQLite

    WebUser->>WebApp: Compose & Send Message
    WebApp->>API: POST /api/messages
    API->>DB: Insert message (status: pending_sync)
    DB-->>API: Message created
    API->>Redis: Publish message event
    API-->>WebApp: 201 Created (message)
    WebApp-->>WebUser: Confirmation displayed
    
    Note over MobileApp,MobileDB: Mobile device online
    MobileApp->>API: GET /api/sync/incoming
    API->>DB: Query pending messages
    DB-->>API: Messages returned
    API-->>MobileApp: Messages (compressed)
    MobileApp->>MobileDB: Save messages locally
    MobileApp->>API: Update sync status
    API->>DB: Update message status to 'synced'
    MobileApp->>MobileApp: Show notification
    MobileApp-->>WebUser: Message appears in inbox
```

## Message Reply Flow (Mobile → Web)

This diagram shows the flow when a mobile user replies to a message.

```mermaid
sequenceDiagram
    participant MobileUser as Mobile User
    participant MobileApp as Flutter Mobile App
    participant MobileDB as SQLite
    participant API as Go Sync Engine
    participant DB as PostgreSQL
    participant Redis as Redis Streams
    participant WebApp as Flutter Web App
    participant WebUser as Web User

    MobileUser->>MobileApp: Open message & compose reply
    MobileApp->>MobileDB: Save message (status: pending_sync)
    MobileDB-->>MobileApp: Message saved
    
    alt Mobile device online
        MobileApp->>API: POST /api/sync/outgoing
        API->>DB: Insert/update message (status: synced)
        DB-->>API: Message saved
        API->>Redis: Publish new message event
        API-->>MobileApp: Sync success
        MobileApp->>MobileDB: Update status to 'synced'
    else Mobile device offline
        Note over MobileApp: Message queued for sync
    end
    
    Redis->>WebApp: SSE event: new_message
    WebApp->>API: GET /api/messages
    API->>DB: Query messages
    DB-->>API: Messages returned
    API-->>WebApp: Messages
    WebApp->>WebApp: Update inbox badge
    WebApp-->>WebUser: Show notification & new message
```

## Sync Process Flow

This diagram shows the bidirectional synchronization process when a mobile device comes online.

```mermaid
sequenceDiagram
    participant MobileApp as Flutter Mobile App
    participant MobileDB as SQLite
    participant API as Go Sync Engine
    participant DB as PostgreSQL
    participant Redis as Redis Streams

    Note over MobileApp: Device comes online
    MobileApp->>MobileApp: Check connectivity
    MobileApp->>API: GET /api/sync/status
    API->>DB: Query sync metadata
    DB-->>API: Sync status
    API-->>MobileApp: Status response
    
    par Incoming Sync
        MobileApp->>API: GET /api/sync/incoming
        API->>DB: Query pending messages for device
        DB-->>API: Messages
        API-->>MobileApp: Messages (compressed)
        MobileApp->>MobileDB: Save messages
        MobileApp->>API: Update sync metadata
        API->>DB: Update message status to 'synced'
    and Outgoing Sync
        MobileApp->>MobileDB: Query pending outgoing messages
        MobileDB-->>MobileApp: Messages (status: pending_sync)
        MobileApp->>API: POST /api/sync/outgoing
        API->>DB: Insert/update messages
        DB-->>API: Success
        API-->>MobileApp: Sync result
        MobileApp->>MobileDB: Update status to 'synced'
    end
    
    API->>DB: Update sync_metadata
    MobileApp->>MobileApp: Trigger notifications for new messages
```

## Real-Time Notification Flow

This diagram shows how real-time notifications are delivered to web users via SSE.

```mermaid
sequenceDiagram
    participant MobileApp as Flutter Mobile App
    participant API as Go Sync Engine
    participant DB as PostgreSQL
    participant Redis as Redis Streams
    participant SSEServer as SSE Server
    participant WebApp as Flutter Web App
    participant WebUser as Web User

    MobileApp->>API: POST /api/sync/outgoing (new message)
    API->>DB: Save message
    API->>Redis: Publish event to stream
    
    Redis->>SSEServer: New event available
    SSEServer->>SSEServer: Get web user ID from message
    SSEServer->>WebApp: SSE: event: new_message
    Note over WebApp: data: {"type": "new_message",<br/>"message_id": "...",<br/>"unread_count": 3}
    
    WebApp->>WebApp: Update inbox badge count
    WebApp->>WebApp: Show browser notification
    WebApp->>API: GET /api/messages (if conversation open)
    API->>DB: Query messages
    DB-->>API: Messages
    API-->>WebApp: Messages
    WebApp-->>WebUser: Display new message
```

## Offline Message Handling Flow

This diagram shows how messages are handled when the mobile device is offline.

```mermaid
sequenceDiagram
    participant MobileUser as Mobile User
    participant MobileApp as Flutter Mobile App
    participant MobileDB as SQLite
    participant API as Go Sync Engine
    participant DB as PostgreSQL

    Note over MobileApp: Device is offline
    MobileUser->>MobileApp: Compose message
    MobileApp->>MobileDB: Save message (status: pending_sync)
    MobileDB-->>MobileApp: Saved
    MobileApp-->>MobileUser: "Message will be sent when online"
    
    Note over MobileApp: User can continue using app offline
    MobileUser->>MobileApp: View messages
    MobileApp->>MobileDB: Query local messages
    MobileDB-->>MobileApp: Messages
    MobileApp-->>MobileUser: Display messages from local DB
    
    Note over MobileApp: Device comes online
    MobileApp->>MobileApp: Detect connectivity
    MobileApp->>API: POST /api/sync/outgoing
    API->>DB: Save messages
    DB-->>API: Success
    API-->>MobileApp: Sync success
    MobileApp->>MobileDB: Update status to 'synced'
    MobileApp-->>MobileUser: "Message sent"
```

## Message Status Lifecycle

This diagram shows how message status changes throughout its lifecycle.

```mermaid
stateDiagram-v2
    [*] --> pending_sync: Web user sends message
    
    pending_sync --> synced: Mobile device syncs
    synced --> read: Mobile user reads message
    
    pending_sync --> pending_sync: Mobile offline (queued)
    synced --> synced: Message delivered but not read
    
    read --> [*]: Lifecycle complete
    
    note right of pending_sync
        Message created in backend
        Waiting for mobile sync
    end note
    
    note right of synced
        Message synced to mobile
        Available in mobile inbox
    end note
    
    note right of read
        Mobile user has read
        Status updated in backend
    end note
```

## Bidirectional Sync Flow

This diagram shows the complete bidirectional sync process with conflict handling.

```mermaid
flowchart TD
    Start([Mobile Device Online]) --> CheckStatus{Check Sync Status}
    CheckStatus --> IncomingSync[Sync Incoming Messages]
    CheckStatus --> OutgoingSync[Sync Outgoing Messages]
    
    IncomingSync --> FetchIncoming[Fetch from Backend]
    FetchIncoming --> SaveIncoming[Save to Local DB]
    SaveIncoming --> UpdateIncomingStatus[Update Status: synced]
    
    OutgoingSync --> FetchOutgoing[Fetch from Local DB]
    FetchOutgoing --> UploadOutgoing[Upload to Backend]
    UploadOutgoing --> CheckConflict{Conflict?}
    
    CheckConflict -->|No| UpdateOutgoingStatus[Update Status: synced]
    CheckConflict -->|Yes| ResolveConflict[Apply Resolution Strategy]
    ResolveConflict --> UpdateOutgoingStatus
    
    UpdateIncomingStatus --> UpdateMetadata[Update Sync Metadata]
    UpdateOutgoingStatus --> UpdateMetadata
    UpdateMetadata --> TriggerNotifications[Trigger Notifications]
    TriggerNotifications --> End([Sync Complete])
    
    style Start fill:#e1f5ff
    style End fill:#d4edda
    style CheckConflict fill:#fff3cd
    style ResolveConflict fill:#f8d7da
```

## Web User Polling Fallback Flow

This diagram shows the polling fallback mechanism when SSE is unavailable.

```mermaid
sequenceDiagram
    participant WebApp as Flutter Web App
    participant SSEService as SSE Service
    participant PollingService as Polling Service
    participant API as Go Sync Engine
    participant DB as PostgreSQL

    WebApp->>SSEService: Attempt SSE connection
    SSEService->>SSEService: Connection failed
    
    WebApp->>PollingService: Enable polling fallback
    loop Every 5 seconds
        PollingService->>API: GET /api/messages/unread-count
        API->>DB: Query unread count
        DB-->>API: Count
        API-->>PollingService: Unread count
        
        alt Count changed
            PollingService->>WebApp: Update badge
            PollingService->>API: GET /api/messages
            API->>DB: Query new messages
            DB-->>API: Messages
            API-->>PollingService: Messages
            PollingService->>WebApp: Update message list
        end
    end
    
    Note over SSEService: SSE reconnection attempt
    SSEService->>SSEService: Retry connection
    alt SSE reconnected
        SSEService->>PollingService: Disable polling
        PollingService->>PollingService: Stop polling
    end
```

## QR Code Enrollment Flow

This diagram shows the complete enrollment flow from web user generating QR code to mobile app being ready for use.

```mermaid
sequenceDiagram
    participant WebUser as Web User
    participant WebApp as Flutter Web App
    participant API as Go Sync Engine
    participant DB as PostgreSQL
    participant MobileApp as Container App
    participant MobileDB as SQLite
    participant WidgetCDN as Widget CDN

    WebUser->>WebApp: Click "Enroll Mobile User"
    WebApp->>API: POST /api/enrollment/create
    API->>DB: Create enrollment token
    DB-->>API: Token created
    API->>API: Generate QR code data
    API-->>WebApp: Enrollment response (token + QR data)
    WebApp->>WebApp: Generate QR code image
    WebApp-->>WebUser: Display QR code
    
    Note over MobileApp: User opens container app
    MobileApp->>MobileApp: Check if enrolled
    MobileApp->>MobileApp: Show QR scanner (not enrolled)
    MobileUser->>MobileApp: Scan QR code
    MobileApp->>MobileApp: Parse QR code data
    MobileApp->>API: GET /api/enrollment/:token
    API->>DB: Validate token
    DB-->>API: Token valid
    API-->>MobileApp: Enrollment details
    
    MobileApp->>MobileApp: Get device ID
    MobileApp->>API: POST /api/enrollment/complete
    API->>DB: Create mobile user
    API->>DB: Mark token as used
    DB-->>API: User created
    API-->>MobileApp: Enrollment result + app instructions URL
    
    MobileApp->>API: GET /api/app-instructions
    API->>DB: Get tenant config
    DB-->>API: Config
    API-->>MobileApp: App instructions (widget URLs)
    
    MobileApp->>MobileDB: Store tenant ID & config
    MobileApp->>WidgetCDN: Fetch remote widgets
    WidgetCDN-->>MobileApp: Widget definitions
    MobileApp->>MobileApp: Cache widgets
    MobileApp->>MobileApp: Render remote widgets
    MobileApp-->>MobileUser: App ready (messaging UI)
    
    Note over WebApp: Poll for enrollment status
    WebApp->>API: Check enrollment status
    API->>DB: Query token usage
    DB-->>API: Token used
    API-->>WebApp: Enrollment completed
    WebApp-->>WebUser: Show success message
```

## Error Handling and Retry Flow

This diagram shows how errors are handled and retried during sync operations.

```mermaid
flowchart TD
    Start([Sync Operation]) --> Attempt[Attempt Sync]
    Attempt --> Success{Success?}
    
    Success -->|Yes| Complete([Sync Complete])
    Success -->|No| CheckError{Error Type}
    
    CheckError -->|Network Error| Wait[Wait with Backoff]
    CheckError -->|Validation Error| LogError[Log Error]
    CheckError -->|Server Error| Wait
    CheckError -->|Fatal Error| Abort([Abort Sync])
    
    Wait --> IncrementAttempt[Increment Attempt]
    IncrementAttempt --> CheckMaxAttempts{Max Attempts?}
    
    CheckMaxAttempts -->|No| Attempt
    CheckMaxAttempts -->|Yes| MarkFailed[Mark as Failed]
    
    LogError --> UpdateStatus[Update Status: error]
    MarkFailed --> UpdateStatus
    UpdateStatus --> NotifyUser[Notify User]
    NotifyUser --> End([End])
    
    style Start fill:#e1f5ff
    style Complete fill:#d4edda
    style Abort fill:#f8d7da
    style MarkFailed fill:#f8d7da
```

