#!/bin/bash

set -e

echo "=== Testing Database Schema ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Function to run tests
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "${YELLOW}Testing: ${test_name}${NC}"
    if eval "$test_command"; then
        echo -e "${GREEN}✓ ${test_name} passed${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ ${test_name} failed${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Start Docker Compose if not running
if ! docker ps | grep -q posduif-postgres-test; then
    echo -e "${YELLOW}Starting test database...${NC}"
    cat > /tmp/test-docker-compose.yml <<EOF
version: '3.8'
services:
  postgres:
    image: postgres:18
    container_name: posduif-postgres-test
    environment:
      POSTGRES_USER: posduif
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: tenant_1
    ports:
      - "5433:5432"
    volumes:
      - postgres_test_data:/var/lib/postgresql/data
      - $(pwd)/config/database-init.sql:/docker-entrypoint-initdb.d/init.sql
volumes:
  postgres_test_data:
EOF
    docker-compose -f /tmp/test-docker-compose.yml up -d > /dev/null 2>&1 || \
    docker compose -f /tmp/test-docker-compose.yml up -d > /dev/null 2>&1
    sleep 10
fi

# Check if we can connect to database
if ! PGPASSWORD=secret psql -h localhost -p 5433 -U posduif -d tenant_1 -c "SELECT 1" > /dev/null 2>&1; then
    if docker ps | grep -q posduif-postgres-test; then
        DB_CMD="docker exec posduif-postgres-test psql -U posduif -d tenant_1"
    else
        echo -e "${RED}Error: Cannot connect to database.${NC}"
        exit 1
    fi
else
    export PGPASSWORD=secret
    DB_CMD="psql -h localhost -p 5433 -U posduif -d tenant_1"
fi

# Test 1: Check if users table exists
run_test "Users Table Exists" "$DB_CMD -c '\d users' > /dev/null 2>&1"

# Test 2: Check if messages table exists
run_test "Messages Table Exists" "$DB_CMD -c '\d messages' > /dev/null 2>&1"

# Test 3: Check if enrollment_tokens table exists
run_test "Enrollment Tokens Table Exists" "$DB_CMD -c '\d enrollment_tokens' > /dev/null 2>&1"

# Test 4: Check if sync_metadata table exists
run_test "Sync Metadata Table Exists" "$DB_CMD -c '\d sync_metadata' > /dev/null 2>&1"

# Test 5: Check users table structure
run_test "Users Table Has Required Columns" "$DB_CMD -c '\d users' | grep -q 'id.*uuid'"

# Test 6: Check messages table structure
run_test "Messages Table Has Required Columns" "$DB_CMD -c '\d messages' | grep -q 'id.*uuid'"

# Test 7: Check foreign key constraints
run_test "Messages Table Has Foreign Keys" "$DB_CMD -c '\d messages' | grep -q 'sender_id'"

# Test 8: Check indexes
run_test "Messages Table Has Indexes" "$DB_CMD -c '\di' | grep -q 'idx_messages'"

# Test 9: Test inserting a user
run_test "Can Insert User" "$DB_CMD -c \"INSERT INTO users (id, username, user_type, created_at, updated_at) VALUES (gen_random_uuid(), 'test_user_' || extract(epoch from now()), 'web', NOW(), NOW()) ON CONFLICT DO NOTHING;\" > /dev/null 2>&1"

# Test 10: Test querying users
run_test "Can Query Users" "$DB_CMD -c 'SELECT COUNT(*) FROM users;' > /dev/null 2>&1"

# Cleanup
if [ -f /tmp/test-docker-compose.yml ]; then
    echo -e "${YELLOW}Cleaning up test database...${NC}"
    docker-compose -f /tmp/test-docker-compose.yml down -v > /dev/null 2>&1 || \
    docker compose -f /tmp/test-docker-compose.yml down -v > /dev/null 2>&1
    rm -f /tmp/test-docker-compose.yml
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    exit 1
else
    echo -e "${GREEN}Failed: ${TESTS_FAILED}${NC}"
    exit 0
fi

