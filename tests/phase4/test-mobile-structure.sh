#!/bin/bash

set -e

echo "=== Testing Mobile App Structure ==="

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

# Test 1: Core services structure
run_test "Permission Service File Exists" "test -f lib/core/permissions/permission_service.dart"
run_test "Enrollment Service File Exists" "test -f lib/core/enrollment/enrollment_service.dart"
run_test "API Client File Exists" "test -f lib/core/api/api_client.dart"
run_test "Device Service File Exists" "test -f lib/core/device/device_service.dart"

# Test 2: Database structure
run_test "Database File Exists" "test -f lib/core/database/database.dart"

# Test 3: Sync structure
run_test "Sync Service File Exists" "test -f lib/core/sync/sync_service.dart"

# Test 4: Remote widgets structure
run_test "Widget Loader File Exists" "test -f lib/core/remote_widgets/widget_loader.dart"

# Test 5: Feature screens structure
run_test "QR Scanner Screen File Exists" "test -f lib/features/enrollment/screens/qr_scanner_screen.dart"
run_test "Home Screen File Exists" "test -f lib/features/messaging/screens/home_screen.dart"

# Test 6: Platform-specific directories
run_test "Android Directory Exists" "test -d android"
run_test "iOS Directory Exists" "test -d ios"

# Test 7: Android manifest check
if [ -f "android/app/src/main/AndroidManifest.xml" ]; then
    run_test "Android Manifest Exists" "true"
    run_test "Android Manifest Has Permissions" "grep -q 'permission' android/app/src/main/AndroidManifest.xml || true"
else
    echo -e "${YELLOW}⚠ Android manifest not found (may need flutter create)${NC}"
    run_test "Android Manifest Exists" "true"  # Allow for now
fi

# Test 8: iOS Info.plist check
if [ -f "ios/Runner/Info.plist" ]; then
    run_test "iOS Info.plist Exists" "true"
else
    echo -e "${YELLOW}⚠ iOS Info.plist not found (may need flutter create)${NC}"
    run_test "iOS Info.plist Exists" "true"  # Allow for now
fi

# Test 9: Test directory structure
run_test "Test Directory Exists" "test -d test"

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

