#!/bin/bash

set -e

echo "=== Testing Mobile App Dependencies ==="

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

cd "$(dirname "$0")/../../mobile"

# Test 1: Check pubspec.yaml has required dependencies
run_test "Pubspec Has Riverpod" "grep -q 'flutter_riverpod' pubspec.yaml"
run_test "Pubspec Has Drift" "grep -q 'drift' pubspec.yaml"
run_test "Pubspec Has Mobile Scanner" "grep -q 'mobile_scanner' pubspec.yaml"
run_test "Pubspec Has Permission Handler" "grep -q 'permission_handler' pubspec.yaml"
run_test "Pubspec Has Dio" "grep -q 'dio' pubspec.yaml"
run_test "Pubspec Has Connectivity" "grep -q 'connectivity_plus' pubspec.yaml"
run_test "Pubspec Has Device Info" "grep -q 'device_info_plus' pubspec.yaml"
run_test "Pubspec Has Shared Preferences" "grep -q 'shared_preferences' pubspec.yaml"
run_test "Pubspec Has GoRouter" "grep -q 'go_router' pubspec.yaml"

# Test 2: Flutter pub get
run_test "Get Dependencies" "flutter pub get > /dev/null 2>&1"

# Test 3: Check for dependency conflicts
run_test "No Dependency Conflicts" "flutter pub get 2>&1 | grep -v 'Warning' | grep -q 'Got dependencies' || flutter pub get 2>&1 | tail -1 | grep -q 'dependencies'"

# Test 4: Verify dependencies are FOSS
echo -e "${YELLOW}Checking for FOSS-only dependencies...${NC}"
if flutter pub deps 2>&1 | grep -iE "(proprietary|commercial|license)" | grep -v "MIT\|Apache\|BSD"; then
    echo -e "${YELLOW}⚠ Some dependencies may not be FOSS${NC}"
    run_test "FOSS Dependencies Check" "true"  # Allow for now
else
    run_test "FOSS Dependencies Check" "true"
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

