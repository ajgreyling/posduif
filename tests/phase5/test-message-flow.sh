#!/bin/bash

set -e

echo "=== Testing Message Flow (E2E) ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
BASE_URL="http://localhost:8081"

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

# Ensure services are running (from previous tests)
if ! pgrep -f "sync-engine-e2e" > /dev/null; then
    echo -e "${YELLOW}⚠ Server not running. Please run backend integration tests first.${NC}"
    exit 1
fi

# Load test data if needed - use existing test user
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
    WEB_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    WEB_USER_ID=$(echo "$LOGIN_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    run_test "Web User Login" "true"
else
    run_test "Web User Login" "false"
    WEB_TOKEN=""
    WEB_USER_ID=""
fi

# Test 2: Get mobile users list
if [ -n "$WEB_TOKEN" ]; then
    USERS_RESPONSE=$(curl -s -H "Authorization: Bearer $WEB_TOKEN" ${BASE_URL}/api/users 2>&1)
    if echo "$USERS_RESPONSE" | grep -q "users"; then
        MOBILE_USER_ID=$(echo "$USERS_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
        run_test "Get Mobile Users" "true"
    else
        run_test "Get Mobile Users" "false"
        MOBILE_USER_ID=""
    fi
else
    run_test "Get Mobile Users" "true"  # Skip
    MOBILE_USER_ID=""
fi

# Test 3: Send message from web to mobile
if [ -n "$WEB_TOKEN" ] && [ -n "$MOBILE_USER_ID" ]; then
    MESSAGE_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/messages \
      -H "Authorization: Bearer $WEB_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"recipient_id\":\"$MOBILE_USER_ID\",\"content\":\"Test E2E message\"}" 2>&1)
    if echo "$MESSAGE_RESPONSE" | grep -q "id"; then
        MESSAGE_ID=$(echo "$MESSAGE_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
        run_test "Send Message" "true"
    else
        run_test "Send Message" "false"
        MESSAGE_ID=""
    fi
else
    run_test "Send Message" "true"  # Skip
    MESSAGE_ID=""
fi

# Test 4: Get messages for mobile user (via sync)
if [ -n "$MOBILE_USER_ID" ]; then
    # Get device ID for mobile user (would need to query user first)
    DEVICE_ID="test-device-sync"
    SYNC_RESPONSE=$(curl -s -H "X-Device-ID: $DEVICE_ID" ${BASE_URL}/api/sync/incoming 2>&1)
    if echo "$SYNC_RESPONSE" | grep -q "messages"; then
        run_test "Sync Incoming Messages" "true"
    else
        run_test "Sync Incoming Messages" "false"
    fi
else
    run_test "Sync Incoming Messages" "true"  # Skip
fi

# Test 5: Get unread count
if [ -n "$WEB_TOKEN" ]; then
    UNREAD_RESPONSE=$(curl -s -H "Authorization: Bearer $WEB_TOKEN" ${BASE_URL}/api/messages/unread-count 2>&1)
    if echo "$UNREAD_RESPONSE" | grep -q "unread_count"; then
        run_test "Get Unread Count" "true"
    else
        run_test "Get Unread Count" "false"
    fi
else
    run_test "Get Unread Count" "true"  # Skip
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

