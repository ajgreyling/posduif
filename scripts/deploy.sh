#!/bin/bash

set -e

# Posduif Deployment Script
# This script handles deployment to production environments

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Deployment environment (dev, staging, prod)"
    echo "  -m, --method METHOD       Deployment method (docker, ansible, terraform)"
    echo "  -c, --config FILE        Configuration file path"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e prod -m docker"
    echo "  $0 -e staging -m ansible -c config/staging.yaml"
    exit 1
}

ENVIRONMENT="prod"
METHOD="docker"
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -m|--method)
            METHOD="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

echo -e "${YELLOW}=== Posduif Deployment ===${NC}"
echo -e "Environment: ${GREEN}${ENVIRONMENT}${NC}"
echo -e "Method: ${GREEN}${METHOD}${NC}"
echo ""

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Invalid environment. Must be dev, staging, or prod${NC}"
    exit 1
fi

# Build sync engine Docker image
build_image() {
    echo -e "${YELLOW}Building sync engine Docker image...${NC}"
    cd "$PROJECT_ROOT/sync-engine"
    docker build -t posduif/sync-engine:latest .
    docker tag posduif/sync-engine:latest posduif/sync-engine:${ENVIRONMENT}
    echo -e "${GREEN}✓ Docker image built successfully${NC}"
}

# Deploy using Docker Compose
deploy_docker() {
    echo -e "${YELLOW}Deploying with Docker Compose...${NC}"
    
    if [ -z "$CONFIG_FILE" ]; then
        CONFIG_FILE="$PROJECT_ROOT/infrastructure/docker-compose.prod.yml"
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Configuration file not found: $CONFIG_FILE${NC}"
        exit 1
    fi
    
    # Load environment variables
    if [ -f "$PROJECT_ROOT/.env.${ENVIRONMENT}" ]; then
        export $(cat "$PROJECT_ROOT/.env.${ENVIRONMENT}" | grep -v '^#' | xargs)
    fi
    
    cd "$PROJECT_ROOT/infrastructure"
    docker-compose -f docker-compose.prod.yml up -d
    
    echo -e "${GREEN}✓ Deployment completed${NC}"
}

# Deploy using Ansible
deploy_ansible() {
    echo -e "${YELLOW}Deploying with Ansible...${NC}"
    
    if ! command -v ansible-playbook &> /dev/null; then
        echo -e "${RED}Error: Ansible is not installed${NC}"
        exit 1
    fi
    
    INVENTORY_FILE="$PROJECT_ROOT/infrastructure/ansible/inventory/${ENVIRONMENT}.yml"
    if [ ! -f "$INVENTORY_FILE" ]; then
        echo -e "${YELLOW}Warning: Inventory file not found, using production template${NC}"
        INVENTORY_FILE="$PROJECT_ROOT/infrastructure/ansible/inventory/production.yml"
    fi
    
    cd "$PROJECT_ROOT/infrastructure/ansible"
    ansible-playbook -i "$INVENTORY_FILE" playbooks/production.yml
    
    echo -e "${GREEN}✓ Deployment completed${NC}"
}

# Deploy infrastructure with Terraform
deploy_terraform() {
    echo -e "${YELLOW}Deploying infrastructure with Terraform...${NC}"
    
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Error: Terraform is not installed${NC}"
        exit 1
    fi
    
    cd "$PROJECT_ROOT/infrastructure/terraform"
    
    terraform init
    terraform plan -out=tfplan -var="environment=${ENVIRONMENT}"
    
    echo -e "${YELLOW}Review the plan above. Continue? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        terraform apply tfplan
        echo -e "${GREEN}✓ Infrastructure deployed${NC}"
    else
        echo -e "${YELLOW}Deployment cancelled${NC}"
        exit 0
    fi
}

# Health check
health_check() {
    echo -e "${YELLOW}Performing health check...${NC}"
    
    # Determine health check URL based on environment
    if [ "$ENVIRONMENT" = "prod" ]; then
        HEALTH_URL="${HEALTH_CHECK_URL:-http://localhost:8080/health}"
    else
        HEALTH_URL="http://localhost:8080/health"
    fi
    
    for i in {1..10}; do
        if curl -f -s "$HEALTH_URL" > /dev/null; then
            echo -e "${GREEN}✓ Health check passed${NC}"
            return 0
        fi
        echo -e "${YELLOW}Waiting for service... ($i/10)${NC}"
        sleep 5
    done
    
    echo -e "${RED}✗ Health check failed${NC}"
    return 1
}

# Main deployment flow
main() {
    case $METHOD in
        docker)
            build_image
            deploy_docker
            ;;
        ansible)
            build_image
            deploy_ansible
            ;;
        terraform)
            deploy_terraform
            ;;
        *)
            echo -e "${RED}Error: Unknown deployment method: $METHOD${NC}"
            exit 1
            ;;
    esac
    
    # Perform health check
    sleep 10
    health_check || echo -e "${YELLOW}Warning: Health check failed, but deployment may still be in progress${NC}"
    
    echo ""
    echo -e "${GREEN}=== Deployment Complete ===${NC}"
}

main

