#!/bin/bash

set -e

echo "=== Phase 1: Infrastructure & Database Testing ==="

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

# Test 1: Check if Vagrant is installed
run_test "Vagrant Installation" "command -v vagrant > /dev/null"

# Test 2: Check if VirtualBox is installed (if using VirtualBox provider)
if command -v VBoxManage > /dev/null; then
    run_test "VirtualBox Installation" "VBoxManage --version > /dev/null"
fi

# Test 3: Check if Docker is installed
run_test "Docker Installation" "command -v docker > /dev/null"

# Test 4: Check if Docker Compose is installed
run_test "Docker Compose Installation" "command -v docker-compose > /dev/null || docker compose version > /dev/null"

# Test 5: Check if PostgreSQL is accessible (if running locally)
if command -v psql > /dev/null; then
    run_test "PostgreSQL Client Available" "psql --version > /dev/null"
    
    # Try to connect to PostgreSQL
    if PGPASSWORD=secret psql -h localhost -U posduif -d tenant_1 -c "SELECT 1" > /dev/null 2>&1; then
        run_test "PostgreSQL Connection" "true"
    else
        echo -e "${YELLOW}⚠ PostgreSQL not running locally (this is OK if using Docker)${NC}"
    fi
fi

# Test 6: Check if Redis is accessible (if running locally)
if command -v redis-cli > /dev/null; then
    run_test "Redis Client Available" "redis-cli --version > /dev/null"
    
    # Try to connect to Redis
    if redis-cli -h localhost ping > /dev/null 2>&1; then
        run_test "Redis Connection" "true"
    else
        echo -e "${YELLOW}⚠ Redis not running locally (this is OK if using Docker)${NC}"
    fi
fi

# Test 7: Check if setup scripts exist and are executable
run_test "Setup Script Exists" "test -f scripts/setup.sh && test -x scripts/setup.sh"
run_test "Init DB Script Exists" "test -f scripts/init-db.sh && test -x scripts/init-db.sh"
run_test "Init Redis Script Exists" "test -f scripts/init-redis.sh && test -x scripts/init-redis.sh"

# Test 8: Check if database init SQL exists
run_test "Database Init SQL Exists" "test -f config/database-init.sql"

# Test 9: Check if Docker Compose file exists
run_test "Docker Compose File Exists" "test -f infrastructure/docker-compose.yml"

# Test 10: Validate database-init.sql syntax (basic check)
run_test "Database Init SQL Syntax" "grep -q 'CREATE TABLE' config/database-init.sql"

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



