-- Test Fixtures for Posduif
-- This file contains test data for integration and E2E testing

-- Test Users
INSERT INTO users (id, username, user_type, online_status, created_at) VALUES
    ('00000000-0000-0000-0000-000000000001', 'test_web_user', 'web', true, NOW()),
    ('00000000-0000-0000-0000-000000000002', 'test_mobile_user_1', 'mobile', false, NOW()),
    ('00000000-0000-0000-0000-000000000003', 'test_mobile_user_2', 'mobile', true, NOW())
ON CONFLICT (username) DO UPDATE SET
    online_status = EXCLUDED.online_status;

-- Test Messages
INSERT INTO messages (id, sender_id, recipient_id, content, status, created_at) VALUES
    ('10000000-0000-0000-0000-000000000001', 
     '00000000-0000-0000-0000-000000000001', 
     '00000000-0000-0000-0000-000000000002',
     'Test message 1', 
     'pending_sync', 
     NOW()),
    ('10000000-0000-0000-0000-000000000002',
     '00000000-0000-0000-0000-000000000002',
     '00000000-0000-0000-0000-000000000001',
     'Test reply 1',
     'synced',
     NOW() - INTERVAL '1 hour')
ON CONFLICT (id) DO NOTHING;

-- Test Sync Metadata
INSERT INTO sync_metadata (device_id, last_sync_timestamp, sync_status) VALUES
    ('test_device_1', NOW() - INTERVAL '30 minutes', 'idle'),
    ('test_device_2', NOW() - INTERVAL '1 hour', 'idle')
ON CONFLICT (device_id) DO UPDATE SET
    last_sync_timestamp = EXCLUDED.last_sync_timestamp,
    sync_status = EXCLUDED.sync_status;

-- Test Enrollment Tokens (for testing enrollment flow)
INSERT INTO enrollment_tokens (id, token, created_by, tenant_id, expires_at) VALUES
    ('20000000-0000-0000-0000-000000000001',
     '20000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000001',
     'tenant_1',
     NOW() + INTERVAL '1 hour')
ON CONFLICT (token) DO NOTHING;



