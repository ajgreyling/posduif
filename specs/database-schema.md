# Database Schema Documentation

## Overview

The Posduif messaging application uses PostgreSQL with a schema-per-tenant architecture. Each tenant has its own schema containing all tables and data. This document describes the complete database schema for the messaging application.

## Schema Architecture

### Multi-Tenant Design

- **Database per tenant**: Each tenant has a dedicated PostgreSQL database
- **Schema isolation**: All tenant data is isolated in separate databases
- **Connection per tenant**: Each sync engine instance connects to one tenant database

### Example Tenant Setup

```sql
-- Create tenant database
CREATE DATABASE tenant_1;

-- Connect to tenant database
\c tenant_1

-- All tables are created in the public schema
-- Schema-per-tenant is achieved via database-per-tenant
```

## Tables

### users

Stores user information for both web and mobile users.

**Columns:**

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique user identifier |
| username | VARCHAR(255) | NOT NULL, UNIQUE | User's username |
| user_type | VARCHAR(50) | NOT NULL | Type of user: 'web' or 'mobile' |
| device_id | VARCHAR(255) | NULL | Device identifier for mobile users |
| online_status | BOOLEAN | DEFAULT false | Current online status |
| last_seen | TIMESTAMP | NULL | Last seen timestamp |
| enrolled_at | TIMESTAMP | NULL | Enrollment timestamp for mobile users |
| enrollment_token_id | UUID | NULL, REFERENCES enrollment_tokens(id) | Enrollment token used for enrollment |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation timestamp |
| updated_at | TIMESTAMP | DEFAULT NOW() | Record last update timestamp |

**Indexes:**
- Primary key on `id`
- Unique index on `username`
- Index on `user_type` for filtering
- Index on `device_id` for mobile user lookups

**SQL Definition:**

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(255) NOT NULL UNIQUE,
    user_type VARCHAR(50) NOT NULL,
    device_id VARCHAR(255),
    online_status BOOLEAN DEFAULT false,
    last_seen TIMESTAMP,
    enrolled_at TIMESTAMP,
    enrollment_token_id UUID REFERENCES enrollment_tokens(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_user_type ON users(user_type);
CREATE INDEX idx_users_device_id ON users(device_id) WHERE device_id IS NOT NULL;
CREATE INDEX idx_users_enrollment_token ON users(enrollment_token_id) WHERE enrollment_token_id IS NOT NULL;
```

**Triggers:**

```sql
-- Update updated_at timestamp on row update
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### messages

Stores all messages sent between users. This table is mobile-synced, meaning it synchronizes with mobile SQLite databases.

**Columns:**

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique message identifier |
| sender_id | UUID | NOT NULL, REFERENCES users(id) | ID of the message sender |
| recipient_id | UUID | NOT NULL, REFERENCES users(id) | ID of the message recipient |
| content | TEXT | NOT NULL | Message content |
| status | VARCHAR(50) | NOT NULL, DEFAULT 'pending_sync' | Message status: 'pending_sync', 'synced', 'read' |
| created_at | TIMESTAMP | DEFAULT NOW() | Message creation timestamp |
| updated_at | TIMESTAMP | DEFAULT NOW() | Message last update timestamp |
| synced_at | TIMESTAMP | NULL | Timestamp when message was synced to mobile |
| read_at | TIMESTAMP | NULL | Timestamp when message was read |

**Status Values:**
- `pending_sync`: Message created but not yet synced to mobile device
- `synced`: Message has been synced to mobile device
- `read`: Message has been read by recipient

**Indexes:**
- Primary key on `id`
- Foreign key indexes on `sender_id` and `recipient_id`
- Composite index on `(recipient_id, status)` for efficient inbox queries
- Index on `status` for status-based filtering
- Index on `created_at` for chronological sorting

**SQL Definition:**

```sql
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id),
    recipient_id UUID NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending_sync',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    synced_at TIMESTAMP,
    read_at TIMESTAMP,
    CONSTRAINT chk_status CHECK (status IN ('pending_sync', 'synced', 'read'))
);

CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_recipient ON messages(recipient_id);
CREATE INDEX idx_messages_recipient_status ON messages(recipient_id, status);
CREATE INDEX idx_messages_status ON messages(status);
CREATE INDEX idx_messages_created_at ON messages(created_at DESC);
```

**Triggers:**

```sql
-- Update updated_at timestamp
CREATE TRIGGER update_messages_updated_at BEFORE UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Update synced_at when status changes to 'synced'
CREATE OR REPLACE FUNCTION update_synced_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'synced' AND OLD.status != 'synced' THEN
        NEW.synced_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_messages_synced_at BEFORE UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION update_synced_at();

-- Update read_at when status changes to 'read'
CREATE OR REPLACE FUNCTION update_read_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'read' AND OLD.status != 'read' THEN
        NEW.read_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_messages_read_at BEFORE UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION update_read_at();
```

### sync_metadata

Tracks synchronization metadata for each mobile device.

**Columns:**

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique metadata record identifier |
| device_id | VARCHAR(255) | NOT NULL, UNIQUE | Mobile device identifier |
| last_sync_timestamp | TIMESTAMP | NULL | Last successful sync timestamp |
| pending_outgoing_count | INTEGER | DEFAULT 0 | Count of pending outgoing messages |
| sync_status | VARCHAR(50) | DEFAULT 'idle' | Current sync status: 'idle', 'syncing', 'error' |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation timestamp |
| updated_at | TIMESTAMP | DEFAULT NOW() | Record last update timestamp |

**Status Values:**
- `idle`: No sync in progress
- `syncing`: Sync operation in progress
- `error`: Last sync encountered an error

**Indexes:**
- Primary key on `id`
- Unique index on `device_id` for fast device lookups
- Index on `sync_status` for monitoring

**SQL Definition:**

```sql
CREATE TABLE sync_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id VARCHAR(255) NOT NULL UNIQUE,
    last_sync_timestamp TIMESTAMP,
    pending_outgoing_count INTEGER DEFAULT 0,
    sync_status VARCHAR(50) DEFAULT 'idle',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT chk_sync_status CHECK (sync_status IN ('idle', 'syncing', 'error'))
);

CREATE INDEX idx_sync_metadata_device ON sync_metadata(device_id);
CREATE INDEX idx_sync_metadata_status ON sync_metadata(sync_status);
```

**Triggers:**

```sql
-- Update updated_at timestamp
CREATE TRIGGER update_sync_metadata_updated_at BEFORE UPDATE ON sync_metadata
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### enrollment_tokens

Stores enrollment tokens for mobile user enrollment via QR code.

**Columns:**

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique enrollment token identifier |
| token | UUID | NOT NULL, UNIQUE | Enrollment token (same as id for simplicity) |
| created_by | UUID | NOT NULL, REFERENCES users(id) | Web user who created the enrollment |
| tenant_id | VARCHAR(255) | NOT NULL | Tenant identifier |
| expires_at | TIMESTAMP | NOT NULL | Token expiration timestamp |
| used_at | TIMESTAMP | NULL | Timestamp when token was used (enrollment completed) |
| device_id | VARCHAR(255) | NULL | Device ID set when enrollment is completed |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation timestamp |
| updated_at | TIMESTAMP | DEFAULT NOW() | Record last update timestamp |

**Indexes:**
- Primary key on `id`
- Unique index on `token`
- Index on `created_by` for querying enrollments by web user
- Index on `expires_at` for cleanup of expired tokens
- Index on `used_at` for querying unused tokens

**SQL Definition:**

```sql
CREATE TABLE enrollment_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    created_by UUID NOT NULL REFERENCES users(id),
    tenant_id VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    device_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_enrollment_tokens_token ON enrollment_tokens(token);
CREATE INDEX idx_enrollment_tokens_created_by ON enrollment_tokens(created_by);
CREATE INDEX idx_enrollment_tokens_expires_at ON enrollment_tokens(expires_at);
CREATE INDEX idx_enrollment_tokens_used_at ON enrollment_tokens(used_at) WHERE used_at IS NULL;
```

**Triggers:**

```sql
-- Update updated_at timestamp
CREATE TRIGGER update_enrollment_tokens_updated_at BEFORE UPDATE ON enrollment_tokens
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

**Token Expiration:**
- Tokens expire after 1 hour (configurable)
- Expired tokens cannot be used for enrollment
- Used tokens cannot be reused

## Relationships

### Entity Relationship Diagram

```
users (1) ----< (many) messages (many) >---- (1) users
  |                                              |
  |                                              |
  | (sender_id)                            (recipient_id)
  |                                              |
  |                                              |
  | (created_by)                                 |
  |                                              |
enrollment_tokens (many) ----< (1) users         |
  |                                              |
  | (enrollment_token_id)                        |
  |                                              |
  |                                              |
sync_metadata (1) ----< (1) users
  |
  | (device_id references users.device_id)
```

**Relationship Details:**

1. **users → messages (sender)**: One-to-many
   - A user can send many messages
   - Each message has one sender

2. **users → messages (recipient)**: One-to-many
   - A user can receive many messages
   - Each message has one recipient

3. **users → sync_metadata**: One-to-one (for mobile users)
   - Each mobile user (with device_id) has one sync_metadata record
   - Relationship is implicit via device_id

4. **users → enrollment_tokens (created_by)**: One-to-many
   - A web user can create many enrollment tokens
   - Each enrollment token has one creator

5. **enrollment_tokens → users (enrollment_token_id)**: One-to-one (for mobile users)
   - Each mobile user can be enrolled via one enrollment token
   - Token is marked as used when enrollment completes

## Constraints

### Check Constraints

```sql
-- Ensure user_type is valid
ALTER TABLE users ADD CONSTRAINT chk_user_type 
    CHECK (user_type IN ('web', 'mobile'));

-- Ensure message status is valid
ALTER TABLE messages ADD CONSTRAINT chk_status 
    CHECK (status IN ('pending_sync', 'synced', 'read'));

-- Ensure sync_status is valid
ALTER TABLE sync_metadata ADD CONSTRAINT chk_sync_status 
    CHECK (sync_status IN ('idle', 'syncing', 'error'));
```

### Foreign Key Constraints

```sql
-- Messages must reference valid users
ALTER TABLE messages ADD CONSTRAINT fk_messages_sender 
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE messages ADD CONSTRAINT fk_messages_recipient 
    FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE;
```

## Common Queries

### Get Messages for User (Inbox)

```sql
SELECT m.*, u.username as sender_username
FROM messages m
JOIN users u ON m.sender_id = u.id
WHERE m.recipient_id = $1
ORDER BY m.created_at DESC
LIMIT $2 OFFSET $3;
```

### Get Unread Message Count

```sql
SELECT COUNT(*) as unread_count
FROM messages
WHERE recipient_id = $1
  AND status != 'read';
```

### Get Pending Messages for Mobile Device

```sql
SELECT m.*
FROM messages m
JOIN users u ON m.recipient_id = u.id
WHERE u.device_id = $1
  AND m.status = 'pending_sync'
ORDER BY m.created_at ASC
LIMIT $2;
```

### Get Mobile Users with Online Status

```sql
SELECT *
FROM users
WHERE user_type = 'mobile'
ORDER BY online_status DESC, username ASC;
```

### Update Message Status

```sql
UPDATE messages
SET status = $2,
    updated_at = NOW(),
    synced_at = CASE WHEN $2 = 'synced' THEN NOW() ELSE synced_at END,
    read_at = CASE WHEN $2 = 'read' THEN NOW() ELSE read_at END
WHERE id = $1
RETURNING *;
```

### Get Sync Status for Device

```sql
SELECT *
FROM sync_metadata
WHERE device_id = $1;
```

### Create Enrollment Token

```sql
INSERT INTO enrollment_tokens (created_by, tenant_id, expires_at)
VALUES ($1, $2, NOW() + INTERVAL '1 hour')
RETURNING *;
```

### Get Enrollment Token Details

```sql
SELECT et.*, u.username as created_by_username
FROM enrollment_tokens et
JOIN users u ON et.created_by = u.id
WHERE et.token = $1
  AND et.expires_at > NOW()
  AND et.used_at IS NULL;
```

### Complete Enrollment

```sql
-- Update enrollment token
UPDATE enrollment_tokens
SET used_at = NOW(),
    device_id = $2,
    updated_at = NOW()
WHERE token = $1
  AND used_at IS NULL
  AND expires_at > NOW()
RETURNING *;

-- Create mobile user
INSERT INTO users (username, user_type, device_id, enrolled_at, enrollment_token_id)
VALUES ($3, 'mobile', $2, NOW(), (SELECT id FROM enrollment_tokens WHERE token = $1))
RETURNING *;
```

### Get Expired Enrollment Tokens

```sql
SELECT *
FROM enrollment_tokens
WHERE expires_at < NOW()
  AND used_at IS NULL;
```

### Get Enrollment Tokens by Creator

```sql
SELECT et.*
FROM enrollment_tokens et
WHERE et.created_by = $1
ORDER BY et.created_at DESC;
```

## Migration Strategy

### Initial Migration

```sql
-- Migration 001: Initial schema
-- Create users table
CREATE TABLE users (...);

-- Create messages table
CREATE TABLE messages (...);

-- Create sync_metadata table
CREATE TABLE sync_metadata (...);

-- Create indexes
CREATE INDEX ...;

-- Create triggers
CREATE TRIGGER ...;
```

### Future Migrations

- Add new columns with `ALTER TABLE ADD COLUMN`
- Create migration versioning table
- Track applied migrations
- Support rollback if needed

## Performance Considerations

### Indexing Strategy

1. **Primary Keys**: All tables use UUID primary keys with automatic indexes
2. **Foreign Keys**: Indexed automatically by PostgreSQL
3. **Composite Indexes**: Used for common query patterns (recipient_id + status)
4. **Partial Indexes**: Consider for filtered queries (e.g., unread messages only)

### Query Optimization

- Use prepared statements for repeated queries
- Batch operations for sync
- Limit result sets with pagination
- Use EXPLAIN ANALYZE to optimize slow queries

### Partitioning (Future)

For high-volume scenarios, consider partitioning the `messages` table by:
- Date range (monthly partitions)
- Tenant (if multi-tenant in same database)

## Backup and Recovery

### Backup Strategy

- Regular PostgreSQL dumps (pg_dump)
- Point-in-time recovery (PITR) with WAL archiving
- Backup retention policy

### Recovery Procedures

- Restore from backup
- Replay WAL logs
- Verify data integrity

## Security

### Row-Level Security (Future)

Consider implementing RLS policies for multi-tenant scenarios:

```sql
-- Enable RLS
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see messages they sent or received
CREATE POLICY messages_user_policy ON messages
    FOR ALL
    USING (sender_id = current_user_id() OR recipient_id = current_user_id());
```

### Data Encryption

- Encrypt sensitive data at rest (database encryption)
- Use SSL/TLS for connections
- Encrypt backups

## Monitoring

### Key Metrics

- Table sizes
- Index usage
- Query performance
- Connection pool usage
- Replication lag (if applicable)

### Health Checks

```sql
-- Check database health
SELECT 
    (SELECT COUNT(*) FROM users) as user_count,
    (SELECT COUNT(*) FROM messages) as message_count,
    (SELECT COUNT(*) FROM messages WHERE status = 'pending_sync') as pending_sync_count,
    (SELECT COUNT(*) FROM sync_metadata WHERE sync_status = 'error') as sync_errors;
```

