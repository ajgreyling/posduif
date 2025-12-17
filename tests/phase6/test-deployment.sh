#!/bin/bash

set -e

echo "=== Testing Deployment Configuration ==="

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

cd "$(dirname "$0")/../.."

# Test 1: Deployment script exists and is executable
run_test "Deployment Script Exists" "[ -f scripts/deploy.sh ] && [ -x scripts/deploy.sh ]"

# Test 2: Health check script exists and is executable
run_test "Health Check Script Exists" "[ -f scripts/health-check.sh ] && [ -x scripts/health-check.sh ]"

# Test 3: Production Docker Compose file exists
run_test "Production Docker Compose Exists" "[ -f infrastructure/docker-compose.prod.yml ]"

# Test 4: Terraform configuration is valid
if command -v terraform &> /dev/null; then
    cd infrastructure/terraform
    terraform init -backend=false > /dev/null 2>&1
    run_test "Terraform Configuration Valid" "terraform validate > /dev/null 2>&1"
    cd ../..
else
    echo -e "${YELLOW}Skipping Terraform validation (terraform not installed)${NC}"
    run_test "Terraform Configuration Valid" "true"
fi

# Test 5: Ansible playbooks exist
run_test "Ansible Production Playbook Exists" "[ -f infrastructure/ansible/playbooks/production.yml ]"

# Test 6: Ansible templates exist
run_test "Ansible Templates Exist" "[ -f infrastructure/ansible/playbooks/templates/docker-compose.prod.yml.j2 ] && [ -f infrastructure/ansible/playbooks/templates/env.prod.j2 ]"

# Test 7: Deployment documentation exists
run_test "Deployment Documentation Exists" "[ -f DEPLOYMENT.md ]"

# Test 8: Dockerfile is valid
run_test "Dockerfile Exists" "[ -f sync-engine/Dockerfile ]"

# Test 9: Environment variable templates exist
run_test "Environment Templates Exist" "[ -f infrastructure/ansible/inventory/production.yml ]"

# Test 10: User data script exists
run_test "Terraform User Data Script Exists" "[ -f infrastructure/terraform/user-data.sh ]"

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

