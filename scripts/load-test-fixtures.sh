#!/bin/bash

set -e

echo "=== Loading Test Fixtures ==="

# Check if database exists
if ! psql -h localhost -U posduif -d tenant_1 -c "SELECT 1" > /dev/null 2>&1; then
    echo "Error: Cannot connect to database. Make sure PostgreSQL is running and configured."
    exit 1
fi

# Load test fixtures
echo "Loading test data..."
psql -h localhost -U posduif -d tenant_1 -f tests/fixtures/test-data.sql

echo "Test fixtures loaded successfully!"

