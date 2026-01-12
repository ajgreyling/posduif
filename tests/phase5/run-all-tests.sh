#!/bin/bash

set -e

echo "=== Phase 5: Integration & E2E Testing ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Function to run a test suite
run_test_suite() {
    local test_name=$1
    local test_script=$2
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Running: ${test_name}${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if bash "$test_script" 2>&1; then
        echo -e "${GREEN}✓ ${test_name} completed${NC}"
        ((TOTAL_PASSED++))
        return 0
    else
        echo -e "${RED}✗ ${test_name} failed${NC}"
        ((TOTAL_FAILED++))
        return 1
    fi
    ((TOTAL_TESTS++))
}

cd "$SCRIPT_DIR/../.."

# Run test suites
run_test_suite "Backend API Integration Tests" "$SCRIPT_DIR/test-backend-integration.sh"
echo ""

run_test_suite "Enrollment Flow Tests" "$SCRIPT_DIR/test-enrollment-flow.sh"
echo ""

run_test_suite "Message Flow Tests" "$SCRIPT_DIR/test-message-flow.sh"
echo ""

run_test_suite "Sync Flow Tests" "$SCRIPT_DIR/test-sync-flow.sh"
echo ""

# Final summary
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Phase 5 Test Summary${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Total Test Suites Passed: ${TOTAL_PASSED}${NC}"
if [ $TOTAL_FAILED -gt 0 ]; then
    echo -e "${RED}Total Test Suites Failed: ${TOTAL_FAILED}${NC}"
    exit 1
else
    echo -e "${GREEN}Total Test Suites Failed: ${TOTAL_FAILED}${NC}"
    exit 0
fi



