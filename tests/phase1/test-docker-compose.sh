#!/bin/bash

set -e

echo "=== Testing Docker Compose Setup ==="

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

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Test 1: Validate Docker Compose file
run_test "Docker Compose File Valid" "docker-compose -f infrastructure/docker-compose.yml config > /dev/null 2>&1 || docker compose -f infrastructure/docker-compose.yml config > /dev/null 2>&1"

# Test 2: Start services
echo -e "${YELLOW}Starting Docker Compose services...${NC}"
if docker-compose -f infrastructure/docker-compose.yml up -d > /dev/null 2>&1 || \
   docker compose -f infrastructure/docker-compose.yml up -d > /dev/null 2>&1; then
    run_test "Docker Compose Services Started" "true"
    
    # Wait for services to be ready
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"
    sleep 10
    
    # Test 3: Check PostgreSQL container
    if docker ps | grep -q posduif-postgres; then
        run_test "PostgreSQL Container Running" "true"
        
        # Test 4: Check PostgreSQL health
        sleep 5
        if docker exec posduif-postgres pg_isready -U posduif > /dev/null 2>&1; then
            run_test "PostgreSQL Health Check" "true"
        else
            run_test "PostgreSQL Health Check" "false"
        fi
    else
        run_test "PostgreSQL Container Running" "false"
    fi
    
    # Test 5: Check Redis container
    if docker ps | grep -q posduif-redis; then
        run_test "Redis Container Running" "true"
        
        # Test 6: Check Redis health
        sleep 5
        if docker exec posduif-redis redis-cli ping > /dev/null 2>&1; then
            run_test "Redis Health Check" "true"
        else
            run_test "Redis Health Check" "false"
        fi
    else
        run_test "Redis Container Running" "false"
    fi
    
    # Test 7: Test database connection
    if docker exec posduif-postgres psql -U posduif -d tenant_1 -c "SELECT 1" > /dev/null 2>&1; then
        run_test "Database Connection" "true"
    else
        run_test "Database Connection" "false"
    fi
    
    # Test 8: Check if tables exist
    if docker exec posduif-postgres psql -U posduif -d tenant_1 -c "\dt" | grep -q "users"; then
        run_test "Database Tables Created" "true"
    else
        run_test "Database Tables Created" "false"
    fi
    
    # Cleanup
    echo -e "${YELLOW}Stopping Docker Compose services...${NC}"
    docker-compose -f infrastructure/docker-compose.yml down > /dev/null 2>&1 || \
    docker compose -f infrastructure/docker-compose.yml down > /dev/null 2>&1
    
else
    run_test "Docker Compose Services Started" "false"
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



