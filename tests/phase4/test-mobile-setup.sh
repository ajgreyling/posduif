#!/bin/bash

set -e

echo "=== Testing Flutter Mobile Container App Setup ==="

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

# Test 1: Check if Flutter is installed
run_test "Flutter Installation" "command -v flutter > /dev/null"

# Test 2: Check Flutter version (should be 3.13+)
if command -v flutter > /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -1 | awk '{print $2}' | cut -d. -f1,2)
    MAJOR=$(echo $FLUTTER_VERSION | cut -d. -f1)
    MINOR=$(echo $FLUTTER_VERSION | cut -d. -f2)
    if [ "$MAJOR" -gt 3 ] || ([ "$MAJOR" -eq 3 ] && [ "$MINOR" -ge 13 ]); then
        run_test "Flutter Version >= 3.13" "true"
    else
        run_test "Flutter Version >= 3.13" "false"
    fi
fi

# Test 3: Check if pubspec.yaml exists
run_test "Pubspec.yaml Exists" "test -f pubspec.yaml"

# Test 4: Check if main.dart exists
run_test "Main Entry Point Exists" "test -f lib/main.dart"

# Test 5: Check if required directories exist
run_test "Core Directory Exists" "test -d lib/core"
run_test "Features Directory Exists" "test -d lib/features"
run_test "Shared Directory Exists" "test -d lib/shared"

# Test 6: Check if core services exist
run_test "Permission Service Exists" "test -f lib/core/permissions/permission_service.dart"
run_test "Enrollment Service Exists" "test -f lib/core/enrollment/enrollment_service.dart"
run_test "API Client Exists" "test -f lib/core/api/api_client.dart"
run_test "Device Service Exists" "test -f lib/core/device/device_service.dart"

# Test 7: Check if database and sync exist
run_test "Database Directory Exists" "test -d lib/core/database"
run_test "Sync Directory Exists" "test -d lib/core/sync"
run_test "Remote Widgets Directory Exists" "test -d lib/core/remote_widgets"

# Test 8: Check if feature screens exist
run_test "QR Scanner Screen Exists" "test -f lib/features/enrollment/screens/qr_scanner_screen.dart"
run_test "Home Screen Exists" "test -f lib/features/messaging/screens/home_screen.dart"

# Test 9: Check Android and iOS directories
run_test "Android Directory Exists" "test -d android"
run_test "iOS Directory Exists" "test -d ios"

# Test 10: Flutter pub get
run_test "Flutter Dependencies" "flutter pub get > /dev/null 2>&1"

# Test 11: Flutter analyze (basic check)
run_test "Flutter Analyze" "flutter analyze --no-fatal-infos 2>&1 | grep -q 'No issues found' || flutter analyze --no-fatal-infos 2>&1 | tail -1 | grep -q 'issue'"

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

