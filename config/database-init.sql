-- Posduif Database Initialization Script
-- This script creates the complete database schema for the messaging application

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Grant SUPERUSER and REPLICATION privileges to posduif user
-- SUPERUSER is required to create logical replication slots
-- REPLICATION is required to connect as a replication client
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'posduif') THEN
        ALTER USER posduif WITH SUPERUSER REPLICATION;
    END IF;
END
$$;

-- Create users table first (web users exist before enrollment)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(255) NOT NULL UNIQUE,
    user_type VARCHAR(50) NOT NULL,
    device_id VARCHAR(255),
    online_status BOOLEAN DEFAULT false,
    last_seen TIMESTAMP,
    enrolled_at TIMESTAMP,
    enrollment_token_id UUID,
    last_message_sent TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT chk_user_type CHECK (user_type IN ('web', 'mobile'))
);

-- Create enrollment_tokens table
CREATE TABLE IF NOT EXISTS enrollment_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    device_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Add foreign key constraint for users.enrollment_token_id (after enrollment_tokens exists)
ALTER TABLE users 
    ADD CONSTRAINT fk_users_enrollment_token 
    FOREIGN KEY (enrollment_token_id) REFERENCES enrollment_tokens(id);

-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending_sync',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    synced_at TIMESTAMP,
    read_at TIMESTAMP,
    CONSTRAINT chk_status CHECK (status IN ('pending_sync', 'synced', 'read'))
);

-- Create sync_metadata table
CREATE TABLE IF NOT EXISTS sync_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id VARCHAR(255) NOT NULL UNIQUE,
    last_sync_timestamp TIMESTAMP,
    pending_outgoing_count INTEGER DEFAULT 0,
    sync_status VARCHAR(50) DEFAULT 'idle',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT chk_sync_status CHECK (sync_status IN ('idle', 'syncing', 'error'))
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_enrollment_tokens_token ON enrollment_tokens(token);
CREATE INDEX IF NOT EXISTS idx_enrollment_tokens_created_by ON enrollment_tokens(created_by);
CREATE INDEX IF NOT EXISTS idx_enrollment_tokens_expires_at ON enrollment_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_enrollment_tokens_used_at ON enrollment_tokens(used_at) WHERE used_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_users_user_type ON users(user_type);
CREATE INDEX IF NOT EXISTS idx_users_device_id ON users(device_id) WHERE device_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_enrollment_token ON users(enrollment_token_id) WHERE enrollment_token_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient_status ON messages(recipient_id, status);
CREATE INDEX IF NOT EXISTS idx_messages_status ON messages(status);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sync_metadata_device ON sync_metadata(device_id);
CREATE INDEX IF NOT EXISTS idx_sync_metadata_status ON sync_metadata(sync_status);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_messages_updated_at BEFORE UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sync_metadata_updated_at BEFORE UPDATE ON sync_metadata
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_enrollment_tokens_updated_at BEFORE UPDATE ON enrollment_tokens
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to update synced_at
CREATE OR REPLACE FUNCTION update_synced_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'synced' AND (OLD.status IS NULL OR OLD.status != 'synced') THEN
        NEW.synced_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_messages_synced_at BEFORE UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION update_synced_at();

-- Create function to update read_at
CREATE OR REPLACE FUNCTION update_read_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'read' AND (OLD.status IS NULL OR OLD.status != 'read') THEN
        NEW.read_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_messages_read_at BEFORE UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION update_read_at();

-- Create function to update last_message_sent when user sends a message
CREATE OR REPLACE FUNCTION update_user_last_message_sent()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE users 
    SET last_message_sent = NEW.content, updated_at = NOW()
    WHERE id = NEW.sender_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_last_message_sent_trigger AFTER INSERT ON messages
    FOR EACH ROW EXECUTE FUNCTION update_user_last_message_sent();

-- Grant privileges (assuming posduif user exists)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO posduif;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO posduif;

