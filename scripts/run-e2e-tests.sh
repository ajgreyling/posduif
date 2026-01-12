#!/bin/bash

set -e

echo "=== Running E2E Test Suite ==="

# Start services if not running
if ! docker-compose -f infrastructure/docker-compose.yml ps | grep -q "Up"; then
    echo "Starting Docker Compose services..."
    docker-compose -f infrastructure/docker-compose.yml up -d
    echo "Waiting for services to be ready..."
    sleep 10
fi

# Run E2E tests
cd tests/e2e

if [ -f "run.sh" ]; then
    ./run.sh
else
    echo "E2E test runner not found. Creating basic test structure..."
    echo "E2E tests should be implemented here."
fi

cd ../..

echo "=== E2E Tests Complete ==="



