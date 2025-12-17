#!/bin/bash

set -e

echo "=== Testing Flutter Web App Structure ==="

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

# Test 1: Core API structure
run_test "API Client File Exists" "test -f lib/core/api/api_client.dart"
run_test "Auth Service File Exists" "test -f lib/core/auth/auth_service.dart"

# Test 2: Models structure
run_test "User Model File Exists" "test -f lib/core/models/user.dart"
run_test "Message Model File Exists" "test -f lib/core/models/message.dart"
run_test "Enrollment Model File Exists" "test -f lib/core/models/enrollment.dart"

# Test 3: Providers structure
run_test "Providers File Exists" "test -f lib/core/providers.dart"
run_test "Router File Exists" "test -f lib/core/router.dart"

# Test 4: Feature screens structure
run_test "Auth Feature Directory Exists" "test -d lib/features/auth"
run_test "Enrollment Feature Directory Exists" "test -d lib/features/enrollment"
run_test "Messaging Feature Directory Exists" "test -d lib/features/messaging"

# Test 5: Screen files exist
run_test "Login Screen File Exists" "test -f lib/features/auth/screens/login_screen.dart"
run_test "Enrollment Screen File Exists" "test -f lib/features/enrollment/screens/enrollment_screen.dart"
run_test "User Selection Screen File Exists" "test -f lib/features/messaging/screens/user_selection_screen.dart"
run_test "Conversation Screen File Exists" "test -f lib/features/messaging/screens/conversation_screen.dart"
run_test "Inbox Screen File Exists" "test -f lib/features/messaging/screens/inbox_screen.dart"

# Test 6: Shared utilities structure
run_test "Shared Directory Exists" "test -d lib/shared"
run_test "Shared Widgets Directory Exists" "test -d lib/shared/widgets"
run_test "Shared Utils Directory Exists" "test -d lib/shared/utils"

# Test 7: Test directory structure
run_test "Test Directory Exists" "test -d test"

# Test 8: Web assets structure
run_test "Web Directory Exists" "test -d web"

# Test 9: Check pubspec.yaml has required dependencies
run_test "Pubspec Has Riverpod" "grep -q 'flutter_riverpod' pubspec.yaml"
run_test "Pubspec Has GoRouter" "grep -q 'go_router' pubspec.yaml"
run_test "Pubspec Has Dio" "grep -q 'dio' pubspec.yaml"
run_test "Pubspec Has QR Flutter" "grep -q 'qr_flutter' pubspec.yaml"

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

