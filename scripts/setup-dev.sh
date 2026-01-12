#!/bin/bash

set -e

echo "=== Setting up Posduif Development Environment ==="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Start Docker Compose services
echo "Starting Docker Compose services..."
cd infrastructure
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 5

# Check service health
echo "Checking service health..."
docker-compose ps

echo ""
echo "=== Development Environment Ready ==="
echo "PostgreSQL: localhost:5432"
echo "Redis: localhost:6379"
echo "Sync Engine: localhost:8080"
echo ""
echo "To stop services: docker-compose -f infrastructure/docker-compose.yml down"
echo "To view logs: docker-compose -f infrastructure/docker-compose.yml logs -f"



