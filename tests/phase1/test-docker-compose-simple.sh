#!/bin/bash

set -e

echo "=== Testing Docker Compose Setup (PostgreSQL & Redis Only) ==="

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

# Create a simplified docker-compose for testing
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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U posduif"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: posduif-redis-test
    command: redis-server --appendonly yes
    ports:
      - "6380:6379"
    volumes:
      - redis_test_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_test_data:
  redis_test_data:
EOF

# Test 1: Validate Docker Compose file
run_test "Docker Compose File Valid" "docker-compose -f /tmp/test-docker-compose.yml config > /dev/null 2>&1 || docker compose -f /tmp/test-docker-compose.yml config > /dev/null 2>&1"

# Test 2: Start services
echo -e "${YELLOW}Starting Docker Compose services...${NC}"
if docker-compose -f /tmp/test-docker-compose.yml up -d > /dev/null 2>&1 || \
   docker compose -f /tmp/test-docker-compose.yml up -d > /dev/null 2>&1; then
    run_test "Docker Compose Services Started" "true"
    
    # Wait for services to be ready
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"
    sleep 15
    
    # Test 3: Check PostgreSQL container
    if docker ps | grep -q posduif-postgres-test; then
        run_test "PostgreSQL Container Running" "true"
        
        # Test 4: Check PostgreSQL health
        if docker exec posduif-postgres-test pg_isready -U posduif > /dev/null 2>&1; then
            run_test "PostgreSQL Health Check" "true"
        else
            run_test "PostgreSQL Health Check" "false"
        fi
    else
        run_test "PostgreSQL Container Running" "false"
    fi
    
    # Test 5: Check Redis container
    if docker ps | grep -q posduif-redis-test; then
        run_test "Redis Container Running" "true"
        
        # Test 6: Check Redis health
        if docker exec posduif-redis-test redis-cli ping > /dev/null 2>&1; then
            run_test "Redis Health Check" "true"
        else
            run_test "Redis Health Check" "false"
        fi
    else
        run_test "Redis Container Running" "false"
    fi
    
    # Test 7: Test database connection
    if docker exec posduif-postgres-test psql -U posduif -d tenant_1 -c "SELECT 1" > /dev/null 2>&1; then
        run_test "Database Connection" "true"
    else
        run_test "Database Connection" "false"
    fi
    
    # Test 8: Check if tables exist
    if docker exec posduif-postgres-test psql -U posduif -d tenant_1 -c "\dt" | grep -q "users"; then
        run_test "Database Tables Created" "true"
    else
        run_test "Database Tables Created" "false"
    fi
    
    # Test 9: Check Redis Streams support
    if docker exec posduif-redis-test redis-cli XADD test:stream "*" field value > /dev/null 2>&1; then
        run_test "Redis Streams Support" "true"
        # Cleanup test stream
        docker exec posduif-redis-test redis-cli DEL test:stream > /dev/null 2>&1
    else
        run_test "Redis Streams Support" "false"
    fi
    
    # Cleanup
    echo -e "${YELLOW}Stopping Docker Compose services...${NC}"
    docker-compose -f /tmp/test-docker-compose.yml down -v > /dev/null 2>&1 || \
    docker compose -f /tmp/test-docker-compose.yml down -v > /dev/null 2>&1
    rm -f /tmp/test-docker-compose.yml
    
else
    run_test "Docker Compose Services Started" "false"
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



