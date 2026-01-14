#!/bin/bash

set -e

# Posduif Setdown Script
# This script stops and removes Docker containers created by setup/deployment scripts

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
    echo "  -v, --volumes        Remove volumes as well"
    echo "  -n, --networks       Remove networks as well"
    echo "  -a, --all            Remove volumes and networks"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   Stop and remove containers only"
    echo "  $0 -v                Stop and remove containers and volumes"
    echo "  $0 -a                Stop and remove containers, volumes, and networks"
    exit 0
}

REMOVE_VOLUMES=false
REMOVE_NETWORKS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        -n|--networks)
            REMOVE_NETWORKS=true
            shift
            ;;
        -a|--all)
            REMOVE_VOLUMES=true
            REMOVE_NETWORKS=true
            shift
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

echo -e "${YELLOW}=== Posduif Setdown ===${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Function to stop docker-compose services
stop_compose_services() {
    local compose_file="$1"
    local description="$2"
    
    if [ ! -f "$compose_file" ]; then
        return 0
    fi
    
    echo -e "${YELLOW}Stopping services from $description...${NC}"
    
    cd "$(dirname "$compose_file")"
    
    # Try docker-compose first, fall back to docker compose
    if command -v docker-compose &> /dev/null; then
        if [ "$REMOVE_VOLUMES" = true ] && [ "$REMOVE_NETWORKS" = true ]; then
            docker-compose -f "$(basename "$compose_file")" down -v --remove-orphans 2>/dev/null || true
        elif [ "$REMOVE_VOLUMES" = true ]; then
            docker-compose -f "$(basename "$compose_file")" down -v --remove-orphans 2>/dev/null || true
        else
            docker-compose -f "$(basename "$compose_file")" down --remove-orphans 2>/dev/null || true
        fi
    elif docker compose version &> /dev/null; then
        if [ "$REMOVE_VOLUMES" = true ] && [ "$REMOVE_NETWORKS" = true ]; then
            docker compose -f "$(basename "$compose_file")" down -v --remove-orphans 2>/dev/null || true
        elif [ "$REMOVE_VOLUMES" = true ]; then
            docker compose -f "$(basename "$compose_file")" down -v --remove-orphans 2>/dev/null || true
        else
            docker compose -f "$(basename "$compose_file")" down --remove-orphans 2>/dev/null || true
        fi
    fi
    
    echo -e "${GREEN}✓ Stopped services from $description${NC}"
}

# Stop containers from docker-compose.yml (development)
COMPOSE_DEV="$PROJECT_ROOT/infrastructure/docker-compose.yml"
if [ -f "$COMPOSE_DEV" ]; then
    stop_compose_services "$COMPOSE_DEV" "docker-compose.yml (development)"
fi

# Stop containers from docker-compose.prod.yml (production)
COMPOSE_PROD="$PROJECT_ROOT/infrastructure/docker-compose.prod.yml"
if [ -f "$COMPOSE_PROD" ]; then
    stop_compose_services "$COMPOSE_PROD" "docker-compose.prod.yml (production)"
fi

# Stop any standalone containers that might have been created
echo -e "${YELLOW}Checking for standalone Posduif containers...${NC}"

CONTAINERS=$(docker ps -a --filter "name=posduif-" --format "{{.Names}}" 2>/dev/null || true)

if [ -n "$CONTAINERS" ]; then
    echo "Found containers:"
    echo "$CONTAINERS" | while read -r container; do
        echo "  - $container"
    done
    
    echo "$CONTAINERS" | while read -r container; do
        echo -e "${YELLOW}Stopping $container...${NC}"
        docker stop "$container" 2>/dev/null || true
        docker rm "$container" 2>/dev/null || true
        echo -e "${GREEN}✓ Removed $container${NC}"
    done
else
    echo -e "${GREEN}✓ No standalone Posduif containers found${NC}"
fi

# Remove volumes if requested
if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "${YELLOW}Removing Posduif volumes...${NC}"
    
    VOLUMES=$(docker volume ls --filter "name=posduif" --format "{{.Name}}" 2>/dev/null || true)
    
    if [ -n "$VOLUMES" ]; then
        echo "$VOLUMES" | while read -r volume; do
            echo -e "${YELLOW}Removing volume $volume...${NC}"
            docker volume rm "$volume" 2>/dev/null || true
            echo -e "${GREEN}✓ Removed volume $volume${NC}"
        done
    else
        # Try to remove volumes from compose files
        cd "$PROJECT_ROOT/infrastructure"
        if [ -f "docker-compose.yml" ]; then
            if command -v docker-compose &> /dev/null; then
                docker-compose -f docker-compose.yml down -v 2>/dev/null || true
            elif docker compose version &> /dev/null; then
                docker compose -f docker-compose.yml down -v 2>/dev/null || true
            fi
        fi
        echo -e "${GREEN}✓ Volumes removed${NC}"
    fi
fi

# Remove networks if requested
if [ "$REMOVE_NETWORKS" = true ]; then
    echo -e "${YELLOW}Removing Posduif networks...${NC}"
    
    NETWORKS=$(docker network ls --filter "name=posduif" --format "{{.Name}}" 2>/dev/null || true)
    
    if [ -n "$NETWORKS" ]; then
        echo "$NETWORKS" | while read -r network; do
            # Skip default bridge network
            if [ "$network" != "bridge" ]; then
                echo -e "${YELLOW}Removing network $network...${NC}"
                docker network rm "$network" 2>/dev/null || true
                echo -e "${GREEN}✓ Removed network $network${NC}"
            fi
        done
    else
        echo -e "${GREEN}✓ No Posduif networks found${NC}"
    fi
fi

# Clean up any orphaned containers
echo -e "${YELLOW}Cleaning up orphaned containers...${NC}"
docker container prune -f --filter "label=com.docker.compose.project=posduif" 2>/dev/null || true

echo ""
echo -e "${GREEN}=== Setdown Complete ===${NC}"
echo ""
echo "All Posduif Docker containers have been stopped and removed."
if [ "$REMOVE_VOLUMES" = true ]; then
    echo "Volumes have been removed."
fi
if [ "$REMOVE_NETWORKS" = true ]; then
    echo "Networks have been removed."
fi
echo ""
echo "To start services again, run:"
echo "  ./scripts/setup-dev.sh"
echo "  or"
echo "  cd infrastructure && docker-compose up -d"
