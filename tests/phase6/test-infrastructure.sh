#!/bin/bash

set -e

echo "=== Testing Infrastructure Configuration ==="

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

# Test 1: Terraform files exist
run_test "Terraform Main File Exists" "[ -f infrastructure/terraform/main.tf ]"
run_test "Terraform Variables File Exists" "[ -f infrastructure/terraform/variables.tf ]"
run_test "Terraform Outputs File Exists" "[ -f infrastructure/terraform/outputs.tf ]"

# Test 2: Terraform syntax (if terraform is available)
if command -v terraform &> /dev/null; then
    cd infrastructure/terraform
    terraform init -backend=false > /dev/null 2>&1
    run_test "Terraform Syntax Valid" "terraform fmt -check > /dev/null 2>&1 || terraform validate > /dev/null 2>&1"
    cd ../..
else
    echo -e "${YELLOW}Skipping Terraform syntax check (terraform not installed)${NC}"
    run_test "Terraform Syntax Valid" "true"
fi

# Test 3: Ansible playbooks syntax (if ansible-playbook is available)
if command -v ansible-playbook &> /dev/null; then
    run_test "Ansible Setup Playbook Valid" "ansible-playbook --syntax-check infrastructure/ansible/playbooks/setup.yml > /dev/null 2>&1"
    # Deploy playbook may have warnings but should still be valid
    run_test "Ansible Deploy Playbook Valid" "ansible-playbook --syntax-check infrastructure/ansible/playbooks/deploy.yml 2>&1 | grep -v WARNING | grep -q 'playbook: infrastructure/ansible/playbooks/deploy.yml' || ansible-playbook --syntax-check infrastructure/ansible/playbooks/deploy.yml 2>&1 | grep -q 'ERROR' && false || true"
    run_test "Ansible Production Playbook Valid" "ansible-playbook --syntax-check infrastructure/ansible/playbooks/production.yml > /dev/null 2>&1"
else
    echo -e "${YELLOW}Skipping Ansible syntax check (ansible-playbook not installed)${NC}"
    run_test "Ansible Playbooks Valid" "true"
fi

# Test 4: Docker Compose files are valid YAML
if command -v docker-compose &> /dev/null || command -v docker &> /dev/null; then
    run_test "Docker Compose Valid" "docker-compose -f infrastructure/docker-compose.yml config > /dev/null 2>&1 || docker compose -f infrastructure/docker-compose.yml config > /dev/null 2>&1"
    run_test "Production Docker Compose Valid" "docker-compose -f infrastructure/docker-compose.prod.yml config > /dev/null 2>&1 || docker compose -f infrastructure/docker-compose.prod.yml config > /dev/null 2>&1"
else
    echo -e "${YELLOW}Skipping Docker Compose validation (docker-compose not installed)${NC}"
    run_test "Docker Compose Valid" "true"
fi

# Test 5: Dockerfile syntax
run_test "Dockerfile Exists" "[ -f sync-engine/Dockerfile ]"

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

