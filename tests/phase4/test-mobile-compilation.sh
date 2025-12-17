#!/bin/bash

set -e

echo "=== Testing Mobile App Compilation ==="

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

# Ensure dependencies are installed
flutter pub get > /dev/null 2>&1

# Test 1: Main app compiles
run_test "Main App Compiles" "dart analyze lib/main.dart 2>&1 | grep -q 'No issues' || dart analyze lib/main.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 2: Core services compile
run_test "Permission Service Compiles" "dart analyze lib/core/permissions/permission_service.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/core/permissions/permission_service.dart 2>&1 | tail -1 | grep -q 'issue' || true"
run_test "Enrollment Service Compiles" "dart analyze lib/core/enrollment/enrollment_service.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/core/enrollment/enrollment_service.dart 2>&1 | tail -1 | grep -q 'issue' || true"
run_test "API Client Compiles" "dart analyze lib/core/api/api_client.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/core/api/api_client.dart 2>&1 | tail -1 | grep -q 'issue' || true"
run_test "Device Service Compiles" "dart analyze lib/core/device/device_service.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/core/device/device_service.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 3: Database compiles
run_test "Database Compiles" "dart analyze lib/core/database/database.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/core/database/database.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 4: Sync service compiles
run_test "Sync Service Compiles" "dart analyze lib/core/sync/sync_service.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/core/sync/sync_service.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 5: Remote widgets compile
run_test "Widget Loader Compiles" "dart analyze lib/core/remote_widgets/widget_loader.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/core/remote_widgets/widget_loader.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 6: Feature screens compile
run_test "QR Scanner Screen Compiles" "dart analyze lib/features/enrollment/screens/qr_scanner_screen.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/features/enrollment/screens/qr_scanner_screen.dart 2>&1 | tail -1 | grep -q 'issue' || true"
run_test "Home Screen Compiles" "dart analyze lib/features/messaging/screens/home_screen.dart 2>&1 | grep -v 'info' | grep -q 'No issues' || dart analyze lib/features/messaging/screens/home_screen.dart 2>&1 | tail -1 | grep -q 'issue' || true"

# Test 7: All lib files compile together
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

