#!/bin/bash

set -e

echo "=== Running Posduif Test Suite ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run tests and track results
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "${YELLOW}Running: ${test_name}${NC}"
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

# Backend tests
if [ -d "sync-engine" ]; then
    echo ""
    echo "=== Backend Tests ==="
    cd sync-engine
    
    run_test "Backend Unit Tests" "go test ./... -v -short"
    run_test "Backend Integration Tests" "go test ./tests/integration -v"
    
    cd ..
fi

# Web tests
if [ -d "web" ]; then
    echo ""
    echo "=== Web App Tests ==="
    cd web
    
    run_test "Web Unit Tests" "flutter test"
    if [ -d "integration_test" ]; then
        run_test "Web Integration Tests" "flutter test integration_test/"
    fi
    
    cd ..
fi

# Mobile tests
if [ -d "mobile" ]; then
    echo ""
    echo "=== Mobile App Tests ==="
    cd mobile
    
    run_test "Mobile Unit Tests" "flutter test"
    if [ -d "test_driver" ]; then
        run_test "Mobile Integration Tests" "flutter drive --target=test_driver/app.dart"
    fi
    
    cd ..
fi

# E2E tests
if [ -d "tests/e2e" ]; then
    echo ""
    echo "=== E2E Tests ==="
    cd tests/e2e
    
    if [ -f "run.sh" ]; then
        run_test "E2E Test Suite" "./run.sh"
    fi
    
    cd ../..
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

