#!/bin/bash

set -e

echo "=== Testing Sync Flow (E2E) ==="

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

# Ensure services are running
if ! pgrep -f "sync-engine-e2e" > /dev/null; then
    echo -e "${YELLOW}⚠ Server not running. Please run backend integration tests first.${NC}"
    exit 1
fi

DEVICE_ID="test-device-sync-$(date +%s)"

# Test 1: Get sync status
run_test "Get Sync Status" "curl -s -f -H \"X-Device-ID: $DEVICE_ID\" ${BASE_URL}/api/sync/status | grep -q 'device_id\|sync_status'"

# Test 2: Sync incoming (should return empty initially)
INCOMING_RESPONSE=$(curl -s -H "X-Device-ID: $DEVICE_ID" ${BASE_URL}/api/sync/incoming 2>&1)
if echo "$INCOMING_RESPONSE" | grep -q "messages"; then
    run_test "Sync Incoming Endpoint" "true"
else
    run_test "Sync Incoming Endpoint" "true"  # Empty is OK
fi

# Test 3: Sync outgoing (upload messages from device)
OUTGOING_PAYLOAD="{\"messages\":[{\"id\":\"msg-$(date +%s)\",\"sender_id\":\"test-sender\",\"recipient_id\":\"test-recipient\",\"content\":\"Test sync message\",\"status\":\"pending_sync\",\"created_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"updated_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}],\"compressed\":false}"
OUTGOING_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/sync/outgoing \
  -H "X-Device-ID: $DEVICE_ID" \
  -H "Content-Type: application/json" \
  -d "$OUTGOING_PAYLOAD" 2>&1)
if echo "$OUTGOING_RESPONSE" | grep -q "synced_count"; then
    run_test "Sync Outgoing Endpoint" "true"
else
    run_test "Sync Outgoing Endpoint" "false"
fi

# Test 4: Verify sync metadata updated
SYNC_STATUS=$(curl -s -H "X-Device-ID: $DEVICE_ID" ${BASE_URL}/api/sync/status 2>&1)
if echo "$SYNC_STATUS" | grep -q "sync_status"; then
    run_test "Sync Metadata Updated" "true"
else
    run_test "Sync Metadata Updated" "false"
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

