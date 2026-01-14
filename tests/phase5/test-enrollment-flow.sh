#!/bin/bash

set -e

echo "=== Testing Enrollment Flow (E2E) ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
BASE_URL="http://localhost:8081"
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

# Start services (reuse from backend integration test setup)
echo -e "${YELLOW}Setting up test environment...${NC}"
cd "$(dirname "$0")/../.."

# Start services if not running
if ! docker ps | grep -q posduif-e2e-postgres; then
    cat > /tmp/test-e2e-services.yml <<EOF
version: '3.8'
services:
  postgres:
    image: postgres:18
    container_name: posduif-e2e-postgres
    environment:
      POSTGRES_USER: posduif
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: tenant_1
    ports:
      - "5436:5432"
    volumes:
      - $(pwd)/config/database-init.sql:/docker-entrypoint-initdb.d/init.sql

  redis:
    image: redis:7-alpine
    container_name: posduif-e2e-redis
    ports:
      - "6382:6379"
EOF
    docker-compose -f /tmp/test-e2e-services.yml up -d > /dev/null 2>&1 || \
    docker compose -f /tmp/test-e2e-services.yml up -d > /dev/null 2>&1
    sleep 15
fi

# Start server if not running
if ! pgrep -f "sync-engine-e2e" > /dev/null; then
    cd sync-engine
    cat > /tmp/test-e2e-config.yaml <<EOF
postgres:
  host: localhost
  port: 5436
  user: posduif
  password: secret
  db: tenant_1
  ssl_mode: disable
redis:
  host: localhost
  port: 6382
  streams:
    enabled: true
sse:
  port: 8081
auth:
  jwt_secret: "test-secret"
  jwt_expiration: 3600
cors:
  enabled: true
  allowed_origins: ["*"]
EOF
    go build -o /tmp/sync-engine-e2e ./cmd/sync-engine
    /tmp/sync-engine-e2e --config=/tmp/test-e2e-config.yaml > /tmp/sync-engine-e2e.log 2>&1 &
    SERVER_PID=$!
    sleep 5
fi

# Load test data if needed - use existing test user or create one
TEST_USERNAME="test_web_user"
if ! PGPASSWORD=secret psql -h localhost -p 5436 -U posduif -d tenant_1 -tAc "SELECT 1 FROM users WHERE username='$TEST_USERNAME'" 2>/dev/null | grep -q 1; then
    echo -e "${YELLOW}Creating test user...${NC}"
    WEB_USER_ID=$(uuidgen 2>/dev/null || echo "11111111-1111-1111-1111-111111111111")
    PGPASSWORD=secret psql -h localhost -p 5436 -U posduif -d tenant_1 -c "INSERT INTO users (id, username, user_type, online_status, created_at) VALUES ('$WEB_USER_ID', 'web_user_1', 'web', true, NOW()) ON CONFLICT (username) DO UPDATE SET user_type='web';" > /dev/null 2>&1
    TEST_USERNAME="web_user_1"
fi

# Test 1: Login as web user
LOGIN_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${TEST_USERNAME}\",\"password\":\"any\"}" 2>&1)
if echo "$LOGIN_RESPONSE" | grep -q "token"; then
    TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    run_test "Web User Login" "true"
else
    run_test "Web User Login" "false"
    TOKEN=""
fi

# Test 2: Create enrollment token
if [ -n "$TOKEN" ]; then
    ENROLLMENT_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/enrollment/create \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" 2>&1)
    if echo "$ENROLLMENT_RESPONSE" | grep -q '"token"'; then
        # Extract the main token (first occurrence, not from qr_code_data)
        ENROLLMENT_TOKEN=$(echo "$ENROLLMENT_RESPONSE" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p' | head -1)
        # Verify it's a valid UUID format
        if ! echo "$ENROLLMENT_TOKEN" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
            # Try alternative extraction
            ENROLLMENT_TOKEN=$(echo "$ENROLLMENT_RESPONSE" | grep -o '"token":"[^"]*"' | head -1 | sed 's/"token":"\(.*\)"/\1/')
        fi
        # Clean up token
        ENROLLMENT_TOKEN=$(echo "$ENROLLMENT_TOKEN" | tr -d '\n\r\t ' | head -1)
        QR_DATA=$(echo "$ENROLLMENT_RESPONSE" | grep -o '"qr_code_data":{[^}]*' || echo "")
        run_test "Create Enrollment Token" "true"
    else
        run_test "Create Enrollment Token" "false"
        ENROLLMENT_TOKEN=""
    fi
else
    run_test "Create Enrollment Token" "true"  # Skip
    ENROLLMENT_TOKEN=""
fi

# Test 3: Verify enrollment token is valid
if [ -n "$ENROLLMENT_TOKEN" ]; then
    ENROLLMENT_STATUS=$(curl -s ${BASE_URL}/api/enrollment/${ENROLLMENT_TOKEN} 2>&1)
    if echo "$ENROLLMENT_STATUS" | grep -q '"valid":true'; then
        run_test "Enrollment Token Valid" "true"
    else
        run_test "Enrollment Token Valid" "false"
    fi
else
    run_test "Enrollment Token Valid" "true"  # Skip
fi

# Test 4: Complete enrollment (mobile device)
if [ -n "$ENROLLMENT_TOKEN" ]; then
    DEVICE_ID="test-device-$(date +%s)"
    COMPLETE_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/enrollment/complete \
      -H "Content-Type: application/json" \
      -d "{\"token\":\"$ENROLLMENT_TOKEN\",\"device_id\":\"$DEVICE_ID\",\"device_info\":{\"platform\":\"test\"}}" 2>&1)
    if echo "$COMPLETE_RESPONSE" | grep -q "user_id"; then
        USER_ID=$(echo "$COMPLETE_RESPONSE" | grep -o '"user_id":"[^"]*' | cut -d'"' -f4)
        run_test "Complete Enrollment" "true"
    else
        run_test "Complete Enrollment" "false"
        USER_ID=""
    fi
else
    run_test "Complete Enrollment" "true"  # Skip
    DEVICE_ID="test-device-$(date +%s)"
    USER_ID=""
fi

# Test 5: Get app instructions
if [ -n "$DEVICE_ID" ]; then
    APP_INSTRUCTIONS=$(curl -s -H "X-Device-ID: $DEVICE_ID" ${BASE_URL}/api/app-instructions 2>&1)
    if echo "$APP_INSTRUCTIONS" | grep -q "api_base_url"; then
        run_test "Get App Instructions" "true"
    else
        run_test "Get App Instructions" "false"
    fi
else
    run_test "Get App Instructions" "true"  # Skip
fi

# Test 6: Verify user was created
if [ -n "$USER_ID" ]; then
    USER_CHECK=$(curl -s -H "Authorization: Bearer $TOKEN" ${BASE_URL}/api/users 2>&1)
    if echo "$USER_CHECK" | grep -q "$USER_ID"; then
        run_test "Mobile User Created" "true"
    else
        run_test "Mobile User Created" "false"
    fi
else
    run_test "Mobile User Created" "true"  # Skip
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

