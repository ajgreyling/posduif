#!/bin/bash

set -e

echo "=== Initializing PostgreSQL Database ==="

# Set PostgreSQL password
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';" || true

# Create posduif user and database
sudo -u postgres psql <<EOF
-- Create user with REPLICATION privilege (required for logical replication slots)
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'posduif') THEN
        CREATE USER posduif WITH PASSWORD 'secret' REPLICATION;
    ELSE
        -- Grant REPLICATION privilege if user already exists
        ALTER USER posduif WITH REPLICATION;
    END IF;
END
\$\$;

-- Create database
SELECT 'CREATE DATABASE tenant_1'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'tenant_1')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE tenant_1 TO posduif;
EOF

# Connect to tenant_1 database and create schema using the init script
sudo -u postgres psql -d tenant_1 -f /vagrant/config/database-init.sql

# Grant privileges
sudo -u postgres psql -d tenant_1 <<EOF
-- Grant schema privileges
GRANT ALL ON SCHEMA public TO posduif;

-- Grant table privileges
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO posduif;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO posduif;

-- Insert sample data for testing
INSERT INTO users (username, user_type, online_status) VALUES
    ('web_user_1', 'web', true),
    ('mobile_user_1', 'mobile', false),
    ('mobile_user_2', 'mobile', true)
ON CONFLICT (username) DO NOTHING;
EOF

echo "Database initialized successfully!"
echo "Database: tenant_1"
echo "User: posduif"
echo "Password: secret"

