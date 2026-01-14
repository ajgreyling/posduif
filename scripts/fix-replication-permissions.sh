#!/bin/bash

# Script to fix PostgreSQL replication permissions for posduif user
# This grants the REPLICATION privilege needed to create replication slots

set -e

echo "=== Fixing PostgreSQL Replication Permissions ==="
echo ""

# Check if running in Docker or locally
if [ -f /.dockerenv ] || docker ps | grep -q posduif-postgres; then
    echo "Detected Docker environment"
    
    # Connect via Docker
    docker exec -i posduif-postgres psql -U postgres <<EOF
-- Grant REPLICATION privilege to posduif user
ALTER USER posduif WITH REPLICATION;

-- Verify the privilege was granted
SELECT rolname, rolreplication FROM pg_roles WHERE rolname = 'posduif';
EOF
    
    echo ""
    echo "✓ Replication privilege granted to posduif user"
    echo ""
    echo "Note: PostgreSQL must have wal_level=logical configured."
    echo "For Docker, this is typically set via POSTGRES_INITDB_ARGS or command line."
    
else
    echo "Detected local PostgreSQL installation"
    
    # Connect locally (requires sudo access)
    sudo -u postgres psql <<EOF
-- Grant REPLICATION privilege to posduif user
ALTER USER posduif WITH REPLICATION;

-- Verify the privilege was granted
SELECT rolname, rolreplication FROM pg_roles WHERE rolname = 'posduif';
EOF
    
    echo ""
    echo "✓ Replication privilege granted to posduif user"
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
