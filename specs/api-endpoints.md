# API Endpoint Documentation

The API Endpoints are written in Go

## Base URL

```
http://localhost:8080
```

## Authentication

Most endpoints require authentication via JWT token in the Authorization header:

```
Authorization: Bearer <token>
```

Mobile endpoints use device ID in the X-Device-ID header:

```
X-Device-ID: <device_id>
```

## Authentication Endpoints

### POST /api/auth/login

Authenticate a web user and receive a JWT token.

**Request:**

```http
POST /api/auth/login HTTP/1.1
Content-Type: application/json

{
  "username": "web_user_1",
  "password": "password123"
}
```

**Response (200 OK):**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiNTUwZTg0MDAtZTI5Yi00MWQ0LWE3MTYtNDQ2NjU1NDQwMDAwIiwiZXhwIjoxNzA1MzI0MDAwfQ.signature",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "web_user_1",
    "user_type": "web"
  },
  "expires_in": 3600
}
```

**Error Responses:**

- `400 Bad Request`: Invalid request format
- `401 Unauthorized`: Invalid credentials

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid username or password"
  }
}
```

## User Management Endpoints

### GET /api/users

List all mobile users with their online/offline status.

**Headers:**
```
Authorization: Bearer <token>
```

**Query Parameters:**
- `filter` (optional, string): Filter by username (partial match)
- `status` (optional, boolean): Filter by online_status (true/false)

**Request:**

```http
GET /api/users?status=true HTTP/1.1
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "users": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "username": "mobile_user_1",
      "user_type": "mobile",
      "device_id": "device_123",
      "online_status": true,
      "last_seen": "2024-01-15T10:30:00Z",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440002",
      "username": "mobile_user_2",
      "user_type": "mobile",
      "device_id": "device_456",
      "online_status": false,
      "last_seen": "2024-01-15T09:15:00Z",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T09:15:00Z"
    }
  ]
}
```

**Error Responses:**

- `401 Unauthorized`: Missing or invalid token

### GET /api/users/:id

Get specific user details by ID.

**Headers:**
```
Authorization: Bearer <token>
```

**Request:**

```http
GET /api/users/550e8400-e29b-41d4-a716-446655440001 HTTP/1.1
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "username": "mobile_user_1",
  "user_type": "mobile",
  "device_id": "device_123",
  "online_status": true,
  "last_seen": "2024-01-15T10:30:00Z",
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-15T10:30:00Z"
}
```

**Error Responses:**

- `404 Not Found`: User not found

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "User not found"
  }
}
```

## Message Endpoints

### POST /api/messages

Send a message from authenticated web user to a mobile user.

**Headers:**
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Request:**

```http
POST /api/messages HTTP/1.1
Authorization: Bearer <token>
Content-Type: application/json

{
  "recipient_id": "550e8400-e29b-41d4-a716-446655440001",
  "content": "Hello, this is a test message"
}
```

**Response (201 Created):**

```json
{
  "id": "660e8400-e29b-41d4-a716-446655440000",
  "sender_id": "550e8400-e29b-41d4-a716-446655440000",
  "recipient_id": "550e8400-e29b-41d4-a716-446655440001",
  "content": "Hello, this is a test message",
  "status": "pending_sync",
  "created_at": "2024-01-15T10:35:00Z",
  "updated_at": "2024-01-15T10:35:00Z",
  "synced_at": null,
  "read_at": null
}
```

**Error Responses:**

- `400 Bad Request`: Validation error

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Message content cannot be empty",
    "details": {
      "field": "content",
      "reason": "empty"
    }
  }
}
```

- `404 Not Found`: Recipient not found

```json
{
  "error": {
    "code": "INVALID_RECIPIENT",
    "message": "Recipient user not found"
  }
}
```

### GET /api/messages

Get messages for authenticated web user.

**Headers:**
```
Authorization: Bearer <token>
```

**Query Parameters:**
- `recipient_id` (optional, UUID): Filter by recipient
- `status` (optional, string): Filter by status (pending_sync, synced, read)
- `limit` (optional, integer): Limit results (default: 50, max: 100)
- `offset` (optional, integer): Pagination offset (default: 0)

**Request:**

```http
GET /api/messages?recipient_id=550e8400-e29b-41d4-a716-446655440001&limit=20 HTTP/1.1
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "messages": [
    {
      "id": "660e8400-e29b-41d4-a716-446655440000",
      "sender_id": "550e8400-e29b-41d4-a716-446655440000",
      "recipient_id": "550e8400-e29b-41d4-a716-446655440001",
      "content": "Hello",
      "status": "synced",
      "created_at": "2024-01-15T10:35:00Z",
      "updated_at": "2024-01-15T10:35:05Z",
      "synced_at": "2024-01-15T10:35:05Z",
      "read_at": null
    },
    {
      "id": "770e8400-e29b-41d4-a716-446655440000",
      "sender_id": "550e8400-e29b-41d4-a716-446655440001",
      "recipient_id": "550e8400-e29b-41d4-a716-446655440000",
      "content": "Hi there!",
      "status": "read",
      "created_at": "2024-01-15T10:40:00Z",
      "updated_at": "2024-01-15T10:45:00Z",
      "synced_at": "2024-01-15T10:40:05Z",
      "read_at": "2024-01-15T10:45:00Z"
    }
  ],
  "total": 2,
  "limit": 20,
  "offset": 0
}
```

### GET /api/messages/unread-count

Get unread message count for authenticated web user.

**Headers:**
```
Authorization: Bearer <token>
```

**Request:**

```http
GET /api/messages/unread-count HTTP/1.1
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "unread_count": 5
}
```

### GET /api/messages/:id

Get specific message by ID.

**Headers:**
```
Authorization: Bearer <token>
```

**Request:**

```http
GET /api/messages/660e8400-e29b-41d4-a716-446655440000 HTTP/1.1
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "id": "660e8400-e29b-41d4-a716-446655440000",
  "sender_id": "550e8400-e29b-41d4-a716-446655440000",
  "recipient_id": "550e8400-e29b-41d4-a716-446655440001",
  "content": "Hello",
  "status": "read",
  "created_at": "2024-01-15T10:35:00Z",
  "updated_at": "2024-01-15T10:40:00Z",
  "synced_at": "2024-01-15T10:35:05Z",
  "read_at": "2024-01-15T10:40:00Z"
}
```

**Error Responses:**

- `404 Not Found`: Message not found or user doesn't have access

### PUT /api/messages/:id/read

Mark a message as read.

**Headers:**
```
Authorization: Bearer <token>
```

**Request:**

```http
PUT /api/messages/660e8400-e29b-41d4-a716-446655440000/read HTTP/1.1
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "id": "660e8400-e29b-41d4-a716-446655440000",
  "status": "read",
  "read_at": "2024-01-15T10:40:00Z"
}
```

## Enrollment Endpoints

### POST /api/enrollment/create

Create enrollment token for mobile user enrollment. Requires web user authentication.

**Headers:**
```
Authorization: Bearer <token>
```

**Request:**

```http
POST /api/enrollment/create HTTP/1.1
Authorization: Bearer <token>
```

**Response (201 Created):**

```json
{
  "token": "550e8400-e29b-41d4-a716-446655440000",
  "qr_code_data": {
    "enrollment_url": "https://backend.example.com/api/enrollment/550e8400-e29b-41d4-a716-446655440000",
    "token": "550e8400-e29b-41d4-a716-446655440000",
    "tenant_id": "tenant_1"
  },
  "expires_at": "2024-01-16T10:00:00Z"
}
```

**Error Responses:**

- `401 Unauthorized`: Missing or invalid token

### GET /api/enrollment/:token

Get enrollment details by token. Used by mobile app to validate token before enrollment.

**Request:**

```http
GET /api/enrollment/550e8400-e29b-41d4-a716-446655440000 HTTP/1.1
```

**Response (200 OK):**

```json
{
  "token": "550e8400-e29b-41d4-a716-446655440000",
  "tenant_id": "tenant_1",
  "created_by": "web_user_1",
  "expires_at": "2024-01-16T10:00:00Z",
  "used_at": null,
  "valid": true
}
```

**Error Responses:**

- `404 Not Found`: Token not found

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Enrollment token not found"
  }
}
```

- `400 Bad Request`: Token expired or already used

```json
{
  "error": {
    "code": "INVALID_TOKEN",
    "message": "Enrollment token has expired or has already been used"
  }
}
```

### POST /api/enrollment/complete

Complete enrollment process. Mobile app sends device information to complete enrollment.

**Request:**

```http
POST /api/enrollment/complete HTTP/1.1
Content-Type: application/json

{
  "token": "550e8400-e29b-41d4-a716-446655440000",
  "device_id": "device_123",
  "device_info": {
    "platform": "android",
    "version": "13",
    "model": "Pixel 7",
    "app_version": "1.0.0"
  }
}
```

**Response (200 OK):**

```json
{
  "user_id": "660e8400-e29b-41d4-a716-446655440001",
  "device_id": "device_123",
  "tenant_id": "tenant_1",
  "app_instructions_url": "https://backend.example.com/api/app-instructions"
}
```

**Error Responses:**

- `400 Bad Request`: Invalid token or device ID

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid enrollment token or device ID"
  }
}
```

- `404 Not Found`: Token not found or expired

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Enrollment token not found or expired"
  }
}
```

### GET /api/app-instructions

Get app instructions (database schema configuration) for enrolled device.

**Headers:**
```
X-Device-ID: <device_id>
```

**Request:**

```http
GET /api/app-instructions HTTP/1.1
X-Device-ID: device_123
```

**Response (200 OK):**

```json
{
  "version": "1.0.0",
  "tenant_id": "tenant_1",
  "api_base_url": "https://backend.example.com",
  "schema": {
    "tables": [
      {
        "name": "messages",
        "columns": [
          {"name": "id", "type": "text", "primary_key": true, "nullable": false},
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
    "compression": true,
    "sync_interval_seconds": 300
  }
}
```

**Error Responses:**

- `401 Unauthorized`: Invalid or missing device ID

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or missing device ID"
  }
}
```

- `404 Not Found`: Device not enrolled

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Device not enrolled"
  }
}
```

## Sync Endpoints

### GET /api/sync/incoming

Get pending incoming messages for mobile device.

**Headers:**
```
X-Device-ID: <device_id>
```

**Query Parameters:**
- `since` (optional, ISO 8601 timestamp): Get messages since timestamp
- `limit` (optional, integer): Batch size (default: 100, max: 500)

**Request:**

```http
GET /api/sync/incoming?since=2024-01-15T10:00:00Z&limit=100 HTTP/1.1
X-Device-ID: device_123
```

**Response (200 OK):**

```json
{
  "messages": [
    {
      "id": "660e8400-e29b-41d4-a716-446655440000",
      "sender_id": "550e8400-e29b-41d4-a716-446655440000",
      "recipient_id": "550e8400-e29b-41d4-a716-446655440001",
      "content": "Hello",
      "status": "pending_sync",
      "created_at": "2024-01-15T10:35:00Z",
      "updated_at": "2024-01-15T10:35:00Z"
    }
  ],
  "compressed": false,
  "sync_timestamp": "2024-01-15T10:45:00Z"
}
```

**Compressed Response (if compression enabled):**

```http
HTTP/1.1 200 OK
Content-Type: application/json
Content-Encoding: gzip

<compressed binary data>
```

**Error Responses:**

- `400 Bad Request`: Invalid device ID or parameters

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid device ID"
  }
}
```

### POST /api/sync/outgoing

Upload pending outgoing messages from mobile device.

**Headers:**
```
X-Device-ID: <device_id>
Content-Type: application/json
Content-Encoding: gzip (optional, if compressed)
```

**Request:**

```http
POST /api/sync/outgoing HTTP/1.1
X-Device-ID: device_123
Content-Type: application/json

{
  "messages": [
    {
      "id": "770e8400-e29b-41d4-a716-446655440000",
      "sender_id": "550e8400-e29b-41d4-a716-446655440001",
      "recipient_id": "550e8400-e29b-41d4-a716-446655440000",
      "content": "Reply message",
      "status": "pending_sync",
      "created_at": "2024-01-15T10:50:00Z",
      "updated_at": "2024-01-15T10:50:00Z"
    }
  ],
  "compressed": false
}
```

**Response (200 OK):**

```json
{
  "synced_count": 1,
  "failed_count": 0,
  "failed_messages": [],
  "sync_timestamp": "2024-01-15T10:51:00Z"
}
```

**Partial Success Response:**

```json
{
  "synced_count": 2,
  "failed_count": 1,
  "failed_messages": [
    {
      "message_id": "880e8400-e29b-41d4-a716-446655440000",
      "error": "Invalid recipient"
    }
  ],
  "sync_timestamp": "2024-01-15T10:51:00Z"
}
```

**Error Responses:**

- `400 Bad Request`: Invalid message data

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Message content cannot be empty",
    "details": {
      "message_id": "770e8400-e29b-41d4-a716-446655440000"
    }
  }
}
```

### GET /api/sync/status

Get sync status for mobile device.

**Headers:**
```
X-Device-ID: <device_id>
```

**Request:**

```http
GET /api/sync/status HTTP/1.1
X-Device-ID: device_123
```

**Response (200 OK):**

```json
{
  "device_id": "device_123",
  "last_sync_timestamp": "2024-01-15T10:45:00Z",
  "pending_outgoing_count": 0,
  "sync_status": "idle"
}
```

## Server-Sent Events (SSE) Endpoints

### GET /sse/mobile/:device_id

SSE stream for mobile device notifications.

**Headers:**
```
X-Device-ID: <device_id> (must match :device_id in URL)
```

**Request:**

```http
GET /sse/mobile/device_123 HTTP/1.1
X-Device-ID: device_123
```

**Response (200 OK):**

```
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive

event: message
data: {"type": "new_message", "message_id": "660e8400-e29b-41d4-a716-446655440000"}

event: sync_required
data: {"type": "sync_required", "pending_count": 5}

: ping
```

**Event Types:**
- `message`: New message available
- `sync_required`: Sync operation recommended
- `ping`: Keep-alive ping

**Error Responses:**

- `400 Bad Request`: Device ID mismatch

### GET /sse/web/:user_id

SSE stream for web user notifications.

**Headers:**
```
Authorization: Bearer <token>
```

**Request:**

```http
GET /sse/web/550e8400-e29b-41d4-a716-446655440000 HTTP/1.1
Authorization: Bearer <token>
```

**Response (200 OK):**

```
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive

event: new_message
data: {"type": "new_message", "message_id": "770e8400-e29b-41d4-a716-446655440000", "unread_count": 3}

event: message_read
data: {"type": "message_read", "message_id": "660e8400-e29b-41d4-a716-446655440000"}

: ping
```

**Event Types:**
- `new_message`: New message received
- `message_read`: Message was read by recipient
- `ping`: Keep-alive ping

**Error Responses:**

- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: User ID mismatch

## Error Response Format

All error responses follow this format:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {}
  }
}
```

## Common Error Codes

- `UNAUTHORIZED`: Authentication required or invalid token
- `FORBIDDEN`: Insufficient permissions
- `NOT_FOUND`: Resource not found
- `VALIDATION_ERROR`: Request validation failed
- `INVALID_RECIPIENT`: Recipient user does not exist
- `EMPTY_MESSAGE`: Message content is empty
- `SYNC_ERROR`: Sync operation failed
- `DATABASE_ERROR`: Database operation failed
- `REDIS_ERROR`: Redis operation failed
- `INTERNAL_ERROR`: Internal server error

## Rate Limiting

API endpoints are rate-limited to prevent abuse:
- Default: 60 requests per minute per IP/user
- Burst: 10 requests
- Rate limit headers included in responses:
  - `X-RateLimit-Limit`: Request limit
  - `X-RateLimit-Remaining`: Remaining requests
  - `X-RateLimit-Reset`: Reset timestamp

## Pagination

List endpoints support pagination via `limit` and `offset` query parameters:
- Default limit: 50
- Maximum limit: 100
- Response includes `total`, `limit`, and `offset` fields

## Compression

Large payloads (>1KB) are automatically compressed with gzip:
- Request: Include `Content-Encoding: gzip` header
- Response: Check `Content-Encoding: gzip` header
- Compression threshold configurable in sync engine config

