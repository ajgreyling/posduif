#!/bin/bash

# Posduif Health Check Script
# Checks the health of all Posduif services

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

HEALTH_URL="${HEALTH_URL:-http://localhost:8080/health}"
TIMEOUT=5

check_service() {
    local service_name=$1
    local url=$2
    
    echo -n "Checking $service_name... "
    
    if curl -f -s --max-time $TIMEOUT "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

check_database() {
    local host=${POSTGRES_HOST:-localhost}
    local port=${POSTGRES_PORT:-5432}
    local user=${POSTGRES_USER:-posduif}
    local db=${POSTGRES_DB:-tenant_1}
    
    echo -n "Checking PostgreSQL... "
    
    if PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "$host" -p "$port" -U "$user" -d "$db" -c "SELECT 1" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

check_redis() {
    local host=${REDIS_HOST:-localhost}
    local port=${REDIS_PORT:-6379}
    
    echo -n "Checking Redis... "
    
    if redis-cli -h "$host" -p "$port" ping > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

main() {
    echo -e "${YELLOW}=== Posduif Health Check ===${NC}"
    echo ""
    
    FAILED=0
    
    # Check sync engine
    check_service "Sync Engine" "$HEALTH_URL" || ((FAILED++))
    
    # Check database
    if [ -n "$POSTGRES_HOST" ] || command -v psql &> /dev/null; then
        check_database || ((FAILED++))
    else
        echo -e "${YELLOW}Skipping PostgreSQL check (psql not available)${NC}"
    fi
    
    # Check Redis
    if command -v redis-cli &> /dev/null; then
        check_redis || ((FAILED++))
    else
        echo -e "${YELLOW}Skipping Redis check (redis-cli not available)${NC}"
    fi
    
    echo ""
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All services healthy${NC}"
        exit 0
    else
        echo -e "${RED}✗ $FAILED service(s) failed${NC}"
        exit 1
    fi
}

main



