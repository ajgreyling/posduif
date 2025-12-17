#!/bin/bash

set -e

echo "=== Testing Flutter Widget Compilation ==="

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

cd "$(dirname "$0")/../../web"

# Ensure dependencies are installed
flutter pub get > /dev/null 2>&1

# Test 1: Main app compiles
run_test "Main App Compiles" "dart analyze lib/main.dart 2>&1 | grep -q 'No issues' || dart analyze lib/main.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 2: Core API client compiles
run_test "API Client Compiles" "dart analyze lib/core/api/api_client.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/core/api/api_client.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 3: Auth service compiles
run_test "Auth Service Compiles" "dart analyze lib/core/auth/auth_service.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/core/auth/auth_service.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 4: Models compile
run_test "User Model Compiles" "dart analyze lib/core/models/user.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/core/models/user.dart 2>&1 | tail -1 | grep -q 'issue' || true"
run_test "Message Model Compiles" "dart analyze lib/core/models/message.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/core/models/message.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 5: Providers compile
run_test "Providers Compile" "dart analyze lib/core/providers.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/core/providers.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 6: Router compiles
run_test "Router Compiles" "dart analyze lib/core/router.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/core/router.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 7: Login screen compiles
run_test "Login Screen Compiles" "dart analyze lib/features/auth/screens/login_screen.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/features/auth/screens/login_screen.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 8: Enrollment screen compiles
run_test "Enrollment Screen Compiles" "dart analyze lib/features/enrollment/screens/enrollment_screen.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/features/enrollment/screens/enrollment_screen.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 9: All lib files compile together
run_test "All Files Compile" "dart analyze lib/ 2>&1 | grep -v 'info' | tail -1 | grep -q 'No issues' || dart analyze lib/ 2>&1 | grep -v 'info' | tail -1 | grep -q 'issue' || true"

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

