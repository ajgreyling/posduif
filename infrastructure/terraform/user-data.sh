#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create app directory
mkdir -p /opt/posduif
cd /opt/posduif

# Create docker-compose.yml (will be deployed via Ansible)
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  sync-engine:
    image: posduif/sync-engine:latest
    container_name: posduif-sync-engine
    restart: unless-stopped
    environment:
      POSTGRES_HOST: ${db_endpoint}
      POSTGRES_PORT: 5432
      POSTGRES_USER: ${db_username}
      POSTGRES_PASSWORD: ${db_password}
      POSTGRES_DB: ${db_name}
      REDIS_HOST: ${redis_endpoint}
      REDIS_PORT: 6379
      SSE_PORT: 8080
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF

# Start sync engine (will be managed by systemd or docker-compose)
# docker-compose up -d

