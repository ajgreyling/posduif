#!/bin/bash

set -e

echo "=========================================="
echo "  Phase 3: Flutter Web Application"
echo "  Complete Test Suite"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TOTAL_PASSED=0
TOTAL_FAILED=0

# Function to run a test suite
run_test_suite() {
    local suite_name=$1
    local test_script=$2
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Running: ${suite_name}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ ! -f "$test_script" ]; then
        echo -e "${RED}Error: Test script not found: ${test_script}${NC}"
        ((TOTAL_FAILED++))
        return 1
    fi
    
    if bash "$test_script"; then
        echo ""
        echo -e "${GREEN}✓ ${suite_name} completed successfully${NC}"
        ((TOTAL_PASSED++))
        echo ""
        return 0
    else
        echo ""
        echo -e "${RED}✗ ${suite_name} failed${NC}"
        ((TOTAL_FAILED++))
        echo ""
        return 1
    fi
}

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run all test suites
run_test_suite "Flutter Setup Tests" "${SCRIPT_DIR}/test-flutter-setup.sh"
run_test_suite "Flutter Structure Tests" "${SCRIPT_DIR}/test-flutter-structure.sh"
run_test_suite "Flutter Build Tests" "${SCRIPT_DIR}/test-flutter-build.sh"
run_test_suite "Flutter Widget Tests" "${SCRIPT_DIR}/test-flutter-widgets.sh"

# Final Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Phase 3 Test Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}Test Suites Passed: ${TOTAL_PASSED}${NC}"
if [ $TOTAL_FAILED -gt 0 ]; then
    echo -e "${RED}Test Suites Failed: ${TOTAL_FAILED}${NC}"
    echo ""
    echo -e "${RED}Phase 3 testing FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}Test Suites Failed: ${TOTAL_FAILED}${NC}"
    echo ""
    echo -e "${GREEN}✓ Phase 3 testing PASSED${NC}"
    echo ""
    echo -e "${GREEN}All Flutter web application components are working correctly!${NC}"
    exit 0
fi

