#!/bin/bash

set -e

echo "=== Configuring Redis ==="

# Backup original config
if [ ! -f /etc/redis/redis.conf.backup ]; then
    cp /etc/redis/redis.conf /etc/redis/redis.conf.backup
fi

# Configure Redis for persistence and streams
cat >> /etc/redis/redis.conf <<EOF

# Posduif Configuration
# Enable persistence (disk-backed)
save 900 1
save 300 10
save 60 10000

# Enable AOF (Append Only File) for better durability
appendonly yes
appendfsync everysec

# Memory settings
maxmemory 256mb
maxmemory-policy allkeys-lru

# Streams are enabled by default in Redis 5.0+
EOF

# Restart Redis to apply changes
systemctl restart redis-server

# Verify Redis is running
if systemctl is-active --quiet redis-server; then
    echo "Redis is running and configured"
    redis-cli ping
else
    echo "Error: Redis failed to start"
    exit 1
fi

echo "Redis configured successfully!"
echo "Redis Streams: Enabled"
echo "Persistence: Enabled (RDB + AOF)"

