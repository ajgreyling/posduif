#!/bin/bash

# Script to fix PostgreSQL replication permissions for posduif user
# This grants SUPERUSER and REPLICATION privileges needed to create replication slots
# SUPERUSER is required to create logical replication slots
# REPLICATION is required to connect as a replication client

set -e

echo "=== Fixing PostgreSQL Replication Permissions ==="
echo ""

# Check if running in Docker or locally
if [ -f /.dockerenv ] || docker ps | grep -q posduif-postgres; then
    echo "Detected Docker environment"
    
    # Try connecting as postgres user first, fallback to posduif (which may be the superuser)
    if docker exec -i posduif-postgres psql -U postgres -c "SELECT 1" > /dev/null 2>&1; then
        # Connect via Docker as postgres user
        docker exec -i posduif-postgres psql -U postgres <<EOF
-- Grant SUPERUSER and REPLICATION privileges to posduif user
ALTER USER posduif WITH SUPERUSER REPLICATION;

-- Verify the privileges were granted
SELECT rolname, rolsuper, rolreplication FROM pg_roles WHERE rolname = 'posduif';
EOF
    else
        # Connect as posduif user (which is the superuser when POSTGRES_USER=posduif)
        docker exec -i posduif-postgres psql -U posduif <<EOF
-- Grant SUPERUSER and REPLICATION privileges to posduif user
ALTER USER posduif WITH SUPERUSER REPLICATION;

-- Verify the privileges were granted
SELECT rolname, rolsuper, rolreplication FROM pg_roles WHERE rolname = 'posduif';
EOF
    fi
    
    echo ""
    echo "✓ SUPERUSER and REPLICATION privileges granted to posduif user"
    echo ""
    echo "Note: PostgreSQL must have wal_level=logical configured."
    echo "For Docker, this is typically set via POSTGRES_INITDB_ARGS or command line."
    
else
    echo "Detected local PostgreSQL installation"
    
    # Connect locally (requires sudo access)
    sudo -u postgres psql <<EOF
-- Grant SUPERUSER and REPLICATION privileges to posduif user
ALTER USER posduif WITH SUPERUSER REPLICATION;

-- Verify the privileges were granted
SELECT rolname, rolsuper, rolreplication FROM pg_roles WHERE rolname = 'posduif';
EOF
    
    echo ""
    echo "✓ SUPERUSER and REPLICATION privileges granted to posduif user"
    echo ""
    echo "Note: Ensure PostgreSQL has wal_level=logical in postgresql.conf"
    echo "You may need to restart PostgreSQL for wal_level changes to take effect."
fi

echo ""
echo "=== Next Steps ==="
echo "1. Ensure PostgreSQL has wal_level=logical configured"
echo "2. Restart PostgreSQL if wal_level was changed"
echo "3. Restart the sync engine"
echo ""
echo "Note: SUPERUSER privilege is required to create logical replication slots."
echo "For production environments, consider using function-level permissions instead."
echo ""
