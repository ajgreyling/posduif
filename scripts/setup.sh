#!/bin/bash

set -e

echo "=== Posduif Development Environment Setup ==="

# Update system
echo "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install basic dependencies
echo "Installing basic dependencies..."
apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    sqlite3

# Install PostgreSQL 16
echo "Installing PostgreSQL 16..."
if ! command -v psql &> /dev/null; then
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    apt-get update
    apt-get install -y postgresql-16 postgresql-contrib-16
    systemctl enable postgresql
    systemctl start postgresql
fi

# Install Redis
echo "Installing Redis..."
if ! command -v redis-server &> /dev/null; then
    apt-get install -y redis-server
    systemctl enable redis-server
    systemctl start redis-server
fi

# Install Go 1.21+
echo "Installing Go..."
if ! command -v go &> /dev/null; then
    GO_VERSION="1.21.5"
    wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    rm go${GO_VERSION}.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/vagrant/.bashrc
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc
    export PATH=$PATH:/usr/local/go/bin
fi

# Install Docker
echo "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker vagrant
    systemctl enable docker
    systemctl start docker
    rm get-docker.sh
fi

# Install Docker Compose
echo "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_VERSION="2.23.0"
    curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# Install Flutter
echo "Installing Flutter..."
if ! command -v flutter &> /dev/null; then
    FLUTTER_VERSION="3.13.0"
    cd /opt
    git clone https://github.com/flutter/flutter.git -b stable
    cd flutter
    git checkout ${FLUTTER_VERSION}
    /opt/flutter/bin/flutter doctor
    echo 'export PATH=$PATH:/opt/flutter/bin' >> /home/vagrant/.bashrc
    echo 'export PATH=$PATH:/opt/flutter/bin' >> /root/.bashrc
    export PATH=$PATH:/opt/flutter/bin
fi

# Initialize database
echo "Initializing database..."
bash /vagrant/scripts/init-db.sh

# Configure Redis
echo "Configuring Redis..."
bash /vagrant/scripts/init-redis.sh

# Create workspace directory
mkdir -p /home/vagrant/posduif
chown -R vagrant:vagrant /home/vagrant/posduif

echo "=== Setup Complete ==="
echo "PostgreSQL: localhost:5432"
echo "Redis: localhost:6379"
echo "SSE Port: 8080"
echo "Web Port: 3000"
echo ""
echo "To use Go, run: export PATH=\$PATH:/usr/local/go/bin"
echo "To use Flutter, run: export PATH=\$PATH:/opt/flutter/bin"

