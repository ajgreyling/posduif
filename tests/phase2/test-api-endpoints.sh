#!/bin/bash

set -e

echo "=== Testing API Endpoints ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
BASE_URL="http://localhost:8080"
SERVER_PID=""

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

# Start test database and Redis
echo -e "${YELLOW}Starting test services...${NC}"
cd "$(dirname "$0")/../.."

cat > /tmp/test-services.yml <<EOF
version: '3.8'
services:
  postgres:
    image: postgres:18
    container_name: posduif-test-postgres
    environment:
      POSTGRES_USER: posduif
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: tenant_1
    ports:
      - "5434:5432"
    volumes:
      - $(pwd)/config/database-init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U posduif"]
      interval: 5s
      timeout: 3s
      retries: 10

  redis:
    image: redis:7-alpine
    container_name: posduif-test-redis
    ports:
      - "6381:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10
EOF

docker-compose -f /tmp/test-services.yml up -d > /dev/null 2>&1 || \
docker compose -f /tmp/test-services.yml up -d > /dev/null 2>&1

# Wait for services
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 15

# Start sync engine server
echo -e "${YELLOW}Starting sync engine server...${NC}"
cd sync-engine

# Update config for test
cat > /tmp/test-config.yaml <<EOF
postgres:
  host: localhost
  port: 5434
  user: posduif
  password: secret
  db: tenant_1
  max_connections: 10
  ssl_mode: disable

redis:
  host: localhost
  port: 6381
  password: ""
  db: 0
  streams:
    enabled: true
    max_length: 1000

sse:
  port: 8080
  read_timeout: 30s
  write_timeout: 10s
  ping_interval: 15s

sync:
  batch_size: 100
  compression: false
  compression_threshold: 1024
  conflict_resolution: "last_write_wins"
  retry_attempts: 3
  retry_backoff: 2s

auth:
  jwt_secret: "test-secret-key-for-testing-only"
  jwt_expiration: 3600
  password_min_length: 8
  bcrypt_cost: 10

logging:
  level: "info"
  format: "text"
  output: "stdout"

cors:
  enabled: true
  allowed_origins:
    - "*"
  allowed_methods:
    - "GET"
    - "POST"
    - "PUT"
    - "DELETE"
    - "OPTIONS"
  allowed_headers:
    - "Content-Type"
    - "Authorization"
    - "X-Device-ID"
EOF

# Build and start server in background
go build -o /tmp/sync-engine-test ./cmd/sync-engine
/tmp/sync-engine-test --config=/tmp/test-config.yaml > /tmp/sync-engine.log 2>&1 &
SERVER_PID=$!

# Wait for server to start
sleep 5

# Test 1: Health check endpoint
run_test "Health Check Endpoint" "curl -s -f ${BASE_URL}/health | grep -q 'OK'"

# Test 2: CORS headers
run_test "CORS Headers" "curl -s -H 'Origin: http://localhost:3000' -H 'Access-Control-Request-Method: GET' -X OPTIONS ${BASE_URL}/health -I | grep -q 'Access-Control-Allow-Origin'"

# Test 3: Login endpoint (should fail without credentials)
run_test "Login Endpoint Exists" "curl -s -X POST ${BASE_URL}/api/auth/login -H 'Content-Type: application/json' -d '{}' | grep -q 'Invalid\|credentials\|body'"

# Test 4: Protected endpoint requires auth
run_test "Protected Endpoint Requires Auth" "curl -s -f ${BASE_URL}/api/users 2>&1 | grep -q 'Unauthorized\|401' || [ \$? -eq 22 ]"

# Test 5: Enrollment endpoint structure
run_test "Enrollment Endpoint Accessible" "curl -s -X GET ${BASE_URL}/api/enrollment/test-token 2>&1 | grep -q 'not found\|404\|token' || [ \$? -eq 22 ]"

# Test 6: Sync endpoints exist
run_test "Sync Incoming Endpoint" "curl -s -X GET ${BASE_URL}/api/sync/incoming -H 'X-Device-ID: test-device' 2>&1 | grep -q 'messages\|device\|json' || [ \$? -eq 22 ]"

# Test 7: SSE endpoint structure
run_test "SSE Endpoint Structure" "curl -s -N ${BASE_URL}/sse/mobile/test-device -H 'X-Device-ID: test-device' 2>&1 | head -1 | grep -q 'connected\|event\|data' || [ \$? -eq 22 ]"

# Cleanup
echo -e "${YELLOW}Stopping server...${NC}"
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true
rm -f /tmp/sync-engine-test /tmp/test-config.yaml

echo -e "${YELLOW}Stopping test services...${NC}"
docker-compose -f /tmp/test-services.yml down -v > /dev/null 2>&1 || \
docker compose -f /tmp/test-services.yml down -v > /dev/null 2>&1
rm -f /tmp/test-services.yml

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



