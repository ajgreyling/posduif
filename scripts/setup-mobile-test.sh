#!/bin/bash

set -e

# Script to set up mobile testing with QR code enrollment
# This script:
# 1. Starts the sync engine backend
# 2. Sets up ngrok tunnel (if needed)
# 3. Creates a test web user
# 4. Generates enrollment QR code
# 5. Provides instructions for mobile app deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Posduif Mobile Testing Setup ===${NC}"
echo ""

# Check if Docker Compose services are running
echo -e "${YELLOW}Checking Docker Compose services...${NC}"
cd "$PROJECT_ROOT/infrastructure"

# Check if PostgreSQL container is running
POSTGRES_RUNNING=$(docker ps --format "{{.Names}}" | grep -i postgres || echo "")
POSTGRES_CONTAINER_NAME=""

if [ -z "$POSTGRES_RUNNING" ]; then
    echo -e "${YELLOW}PostgreSQL container not running. Starting Docker Compose services...${NC}"
    docker-compose up -d postgres redis web-api > /dev/null 2>&1 || docker compose up -d postgres redis web-api > /dev/null 2>&1
    echo "Waiting for services to be ready..."
    sleep 10
    
    # Wait for PostgreSQL to be healthy
    echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
    MAX_WAIT=60
    WAITED=0
    POSTGRES_CONTAINER_NAME="posduif-postgres"
    export POSTGRES_CONTAINER_NAME
    while [ $WAITED -lt $MAX_WAIT ]; do
        if docker exec "$POSTGRES_CONTAINER_NAME" pg_isready -U posduif > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
            break
        fi
        sleep 2
        WAITED=$((WAITED + 2))
    done
    
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo -e "${RED}✗ PostgreSQL failed to start within $MAX_WAIT seconds${NC}"
        
        # Check if it's a PostgreSQL 18 volume compatibility issue
        if docker logs "$POSTGRES_CONTAINER_NAME" 2>&1 | grep -q "PostgreSQL data in:"; then
            echo -e "${YELLOW}Detected PostgreSQL 18 volume compatibility issue${NC}"
            echo -e "${YELLOW}PostgreSQL 18 requires a different volume mount path${NC}"
            echo -e "${YELLOW}Removing old volume to fix compatibility...${NC}"
            
            # Stop and remove the container
            docker stop "$POSTGRES_CONTAINER_NAME" > /dev/null 2>&1 || true
            docker rm "$POSTGRES_CONTAINER_NAME" > /dev/null 2>&1 || true
            
            # Find and remove the old postgres volume (try different possible names)
            cd "$PROJECT_ROOT/infrastructure"
            for vol_name in posduif_postgres_data infrastructure_postgres_data; do
                if docker volume inspect "$vol_name" > /dev/null 2>&1; then
                    echo -e "${YELLOW}Removing volume: $vol_name${NC}"
                    docker volume rm "$vol_name" > /dev/null 2>&1 || true
                fi
            done
            
            echo -e "${YELLOW}Restarting PostgreSQL with new volume...${NC}"
            cd "$PROJECT_ROOT/infrastructure"
            docker-compose up -d postgres > /dev/null 2>&1 || docker compose up -d postgres > /dev/null 2>&1
            
            # Wait again
            WAITED=0
            while [ $WAITED -lt $MAX_WAIT ]; do
                if docker exec "$POSTGRES_CONTAINER_NAME" pg_isready -U posduif > /dev/null 2>&1; then
                    echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
                    break
                fi
                sleep 2
                WAITED=$((WAITED + 2))
            done
            
            if [ $WAITED -ge $MAX_WAIT ]; then
                echo -e "${RED}✗ PostgreSQL still failed to start after volume fix${NC}"
                echo -e "${YELLOW}  Check logs: docker logs $POSTGRES_CONTAINER_NAME${NC}"
                exit 1
            fi
        else
            echo -e "${YELLOW}  Check logs: docker logs $POSTGRES_CONTAINER_NAME${NC}"
            exit 1
        fi
    fi
    POSTGRES_RUNNING="$POSTGRES_CONTAINER_NAME"
else
    echo -e "${GREEN}✓ Docker Compose services are running${NC}"
    # Set container name from running container
    POSTGRES_CONTAINER_NAME="$POSTGRES_RUNNING"
    export POSTGRES_CONTAINER_NAME
fi

# Check if web-api container is running
WEB_API_CONTAINER_NAME="posduif-web-api"
if docker ps --format "{{.Names}}" | grep -q "^${WEB_API_CONTAINER_NAME}$"; then
    echo -e "${GREEN}✓ Web API container is running${NC}"
    # Wait for web-api to be ready (check if port 8081 is accessible)
    echo -e "${YELLOW}Waiting for web-api to be ready...${NC}"
    MAX_WAIT=30
    WAITED=0
    while [ $WAITED -lt $MAX_WAIT ]; do
        if curl -s http://localhost:8081/api/auth/login > /dev/null 2>&1 || lsof -ti:8081 > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Web API is ready${NC}"
            break
        fi
        sleep 2
        WAITED=$((WAITED + 2))
    done
    
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo -e "${YELLOW}⚠ Web API may not be fully ready yet${NC}"
        echo -e "${YELLOW}  Check logs: docker logs $WEB_API_CONTAINER_NAME${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Web API container not found. Starting it...${NC}"
    cd "$PROJECT_ROOT/infrastructure"
    docker-compose up -d web-api > /dev/null 2>&1 || docker compose up -d web-api > /dev/null 2>&1
    sleep 5
    
    # Wait for web-api to be ready
    echo -e "${YELLOW}Waiting for web-api to be ready...${NC}"
    MAX_WAIT=30
    WAITED=0
    while [ $WAITED -lt $MAX_WAIT ]; do
        if curl -s http://localhost:8081/api/auth/login > /dev/null 2>&1 || lsof -ti:8081 > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Web API is ready${NC}"
            break
        fi
        sleep 2
        WAITED=$((WAITED + 2))
    done
    
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo -e "${YELLOW}⚠ Web API may not be fully ready yet${NC}"
        echo -e "${YELLOW}  Check logs: docker logs $WEB_API_CONTAINER_NAME${NC}"
    fi
fi

# Function to check and fix replication permissions
# Sets POSTGRES_CONTAINER_NAME as a global variable for use later in the script
check_and_fix_replication_permissions() {
    echo -e "${YELLOW}Checking PostgreSQL replication permissions...${NC}"
    
    # Check if PostgreSQL container exists and is running
    POSTGRES_CONTAINER=$(docker ps --format "{{.Names}}" | grep -i postgres | head -1)
    # Export container name for use later in script
    export POSTGRES_CONTAINER_NAME="$POSTGRES_CONTAINER"
    
    # If no container found, check if it exists but is stopped
    if [ -z "$POSTGRES_CONTAINER" ]; then
        POSTGRES_CONTAINER=$(docker ps -a --format "{{.Names}}" | grep -i postgres | head -1)
        if [ -n "$POSTGRES_CONTAINER" ]; then
            echo -e "${YELLOW}PostgreSQL container found but not running. Starting it...${NC}"
            docker start "$POSTGRES_CONTAINER" > /dev/null 2>&1
            sleep 3
        fi
    fi
    
    # Check if running in Docker or locally
    if [ -n "$POSTGRES_CONTAINER" ] && docker ps --format "{{.Names}}" | grep -q "$POSTGRES_CONTAINER" 2>/dev/null; then
        # Docker environment
        echo -e "${YELLOW}Detected Docker environment (container: $POSTGRES_CONTAINER)${NC}"
        
        # Check if posduif user has REPLICATION privilege
        # When POSTGRES_USER is set to posduif, posduif is the superuser (not postgres)
        # Connect to postgres database (system database) or tenant_1
        HAS_REPLICATION=$(docker exec "$POSTGRES_CONTAINER" psql -U posduif -d postgres -tAc "SELECT rolreplication FROM pg_roles WHERE rolname = 'posduif'" 2>/dev/null || docker exec "$POSTGRES_CONTAINER" psql -U posduif -d tenant_1 -tAc "SELECT rolreplication FROM pg_roles WHERE rolname = 'posduif'" 2>/dev/null || echo "f")
        
        if [ "$HAS_REPLICATION" = "t" ]; then
            echo -e "${GREEN}✓ posduif user already has REPLICATION privileges${NC}"
        else
            echo -e "${YELLOW}Granting REPLICATION privileges to posduif user...${NC}"
            # Try postgres database first, fallback to tenant_1
            if docker exec -i "$POSTGRES_CONTAINER" psql -U posduif -d postgres <<EOF > /dev/null 2>&1
ALTER USER posduif WITH REPLICATION;
EOF
            then
                echo -e "${GREEN}✓ REPLICATION privileges granted${NC}"
            elif docker exec -i "$POSTGRES_CONTAINER" psql -U posduif -d tenant_1 <<EOF > /dev/null 2>&1
ALTER USER posduif WITH REPLICATION;
EOF
            then
                echo -e "${GREEN}✓ REPLICATION privileges granted${NC}"
            else
                echo -e "${RED}✗ Failed to grant REPLICATION privileges${NC}"
                echo -e "${YELLOW}  Make sure PostgreSQL container is running and accessible${NC}"
                return 1
            fi
        fi
        
        # Verify the privilege was granted
        HAS_REPLICATION=$(docker exec "$POSTGRES_CONTAINER" psql -U posduif -d postgres -tAc "SELECT rolreplication FROM pg_roles WHERE rolname = 'posduif'" 2>/dev/null || docker exec "$POSTGRES_CONTAINER" psql -U posduif -d tenant_1 -tAc "SELECT rolreplication FROM pg_roles WHERE rolname = 'posduif'" 2>/dev/null || echo "f")
        if [ "$HAS_REPLICATION" != "t" ]; then
            echo -e "${RED}✗ Verification failed: posduif user does not have REPLICATION privileges${NC}"
            return 1
        fi
        
    else
        # Local PostgreSQL installation
        echo -e "${YELLOW}Detected local PostgreSQL installation${NC}"
        
        # Check if posduif user has REPLICATION privilege
        HAS_REPLICATION=$(sudo -u postgres psql -tAc "SELECT rolreplication FROM pg_roles WHERE rolname = 'posduif'" 2>/dev/null || echo "f")
        
        if [ "$HAS_REPLICATION" = "t" ]; then
            echo -e "${GREEN}✓ posduif user already has REPLICATION privileges${NC}"
        else
            echo -e "${YELLOW}Granting REPLICATION privileges to posduif user...${NC}"
            if sudo -u postgres psql <<EOF > /dev/null 2>&1
ALTER USER posduif WITH REPLICATION;
EOF
            then
                echo -e "${GREEN}✓ REPLICATION privileges granted${NC}"
            else
                echo -e "${RED}✗ Failed to grant REPLICATION privileges${NC}"
                echo -e "${YELLOW}  Make sure you have sudo access and PostgreSQL is running${NC}"
                return 1
            fi
        fi
        
        # Verify the privilege was granted
        HAS_REPLICATION=$(sudo -u postgres psql -tAc "SELECT rolreplication FROM pg_roles WHERE rolname = 'posduif'" 2>/dev/null || echo "f")
        if [ "$HAS_REPLICATION" != "t" ]; then
            echo -e "${RED}✗ Verification failed: posduif user does not have REPLICATION privileges${NC}"
            return 1
        fi
    fi
    
    return 0
}

# Check and fix replication permissions
if ! check_and_fix_replication_permissions; then
    echo -e "${RED}✗ Failed to set up replication permissions${NC}"
    echo -e "${YELLOW}  The sync engine requires REPLICATION privileges to create logical replication slots${NC}"
    echo -e "${YELLOW}  You can manually fix this by running: scripts/fix-replication-permissions.sh${NC}"
    exit 1
fi

# Verify PostgreSQL connection and permissions for sync engine
echo -e "${YELLOW}Verifying PostgreSQL connection and permissions...${NC}"
if [ -n "$POSTGRES_CONTAINER_NAME" ]; then
    # Test connection and verify replication privileges
    if docker exec "$POSTGRES_CONTAINER_NAME" psql -U posduif -d tenant_1 -tAc "SELECT rolreplication FROM pg_roles WHERE rolname = 'posduif'" 2>/dev/null | grep -q "t"; then
        # Verify we can query the database (simulating sync engine connection)
        if docker exec "$POSTGRES_CONTAINER_NAME" psql -U posduif -d tenant_1 -tAc "SELECT 1" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PostgreSQL connection verified (Docker container: $POSTGRES_CONTAINER_NAME)${NC}"
            echo -e "${GREEN}✓ Replication privileges confirmed${NC}"
        else
            echo -e "${RED}✗ Failed to verify PostgreSQL connection${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ Replication privileges not found for posduif user${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Could not verify PostgreSQL connection (container not found)${NC}"
    echo -e "${YELLOW}  Sync engine will attempt to connect via localhost:5432${NC}"
fi

# Check if sync engine is running and kill any old instances
echo -e "${YELLOW}Checking sync engine...${NC}"

# Kill any existing sync-engine processes
KILLED_PROCESSES=false
if pgrep -f "sync-engine" > /dev/null 2>&1 || pgrep -f "/tmp/sync-engine" > /dev/null 2>&1; then
    echo -e "${YELLOW}Stopping existing sync engine processes...${NC}"
    pkill -f "sync-engine" 2>/dev/null || true
    pkill -f "/tmp/sync-engine" 2>/dev/null || true
    KILLED_PROCESSES=true
    sleep 2
fi

# Kill any process using port 8080
if lsof -ti:8080 > /dev/null 2>&1; then
    if [ "$KILLED_PROCESSES" = false ]; then
        echo -e "${YELLOW}Stopping process on port 8080...${NC}"
    fi
    lsof -ti:8080 | xargs kill -9 2>/dev/null || true
    sleep 2
fi

# Check if sync engine is still running after cleanup
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Sync engine still responding after cleanup attempt${NC}"
    echo -e "${YELLOW}  Manually stop it and run this script again${NC}"
    exit 1
fi

# Always rebuild to ensure latest code
echo -e "${YELLOW}Building sync engine...${NC}"
cd "$PROJECT_ROOT/sync-engine"

# Build the sync engine binary
if go build -o /tmp/sync-engine ./cmd/sync-engine/main.go; then
    echo -e "${GREEN}✓ Sync engine built successfully${NC}"
else
    echo -e "${RED}✗ Failed to build sync engine${NC}"
    exit 1
fi

echo -e "${YELLOW}Starting sync engine...${NC}"
/tmp/sync-engine --config="$PROJECT_ROOT/config/config.yaml" > /tmp/sync-engine.log 2>&1 &
SYNC_ENGINE_PID=$!
echo "Waiting for sync engine to start..."
sleep 5

if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Sync engine started (PID: $SYNC_ENGINE_PID)${NC}"
else
    echo -e "${RED}✗ Failed to start sync engine${NC}"
    echo -e "${YELLOW}  Check logs: tail -f /tmp/sync-engine.log${NC}"
    exit 1
fi

# Check for ngrok
NGROK_AVAILABLE=false
if command -v ngrok &> /dev/null; then
    NGROK_AVAILABLE=true
    echo -e "${GREEN}✓ ngrok is available${NC}"
else
    echo -e "${YELLOW}⚠ ngrok not found. Install from https://ngrok.com/download${NC}"
    echo -e "${YELLOW}  Or use your local IP address if on same network${NC}"
fi

# Get public URL
PUBLIC_URL=""
if [ "$NGROK_AVAILABLE" = true ]; then
    echo -e "${YELLOW}Setting up ngrok tunnel...${NC}"
    # Kill any existing ngrok processes
    pkill ngrok 2>/dev/null || true
    sleep 2
    
    # Start ngrok
    ngrok http 8080 > /tmp/ngrok.log 2>&1 &
    NGROK_PID=$!
    sleep 3
    
    # Get ngrok URL
    PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | head -1 | cut -d'"' -f4)
    
    if [ -n "$PUBLIC_URL" ]; then
        echo -e "${GREEN}✓ ngrok tunnel established: $PUBLIC_URL${NC}"
    else
        echo -e "${YELLOW}⚠ Could not get ngrok URL. Using localhost${NC}"
        PUBLIC_URL="http://localhost:8080"
    fi
else
    # Get local IP
    LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    if [ -n "$LOCAL_IP" ]; then
        PUBLIC_URL="http://$LOCAL_IP:8080"
        echo -e "${GREEN}✓ Using local IP: $PUBLIC_URL${NC}"
        echo -e "${YELLOW}  Make sure your tablet is on the same network${NC}"
    else
        PUBLIC_URL="http://localhost:8080"
        echo -e "${YELLOW}⚠ Using localhost. This may not work from tablet${NC}"
    fi
fi

# Create test web user if needed
echo -e "${YELLOW}Setting up test user...${NC}"
cd "$PROJECT_ROOT"

# Ensure we have the PostgreSQL container name
if [ -z "$POSTGRES_CONTAINER_NAME" ]; then
    POSTGRES_CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep -i postgres | head -1)
fi

# Use docker exec to ensure we're connecting to Docker PostgreSQL, not local instance
if [ -n "$POSTGRES_CONTAINER_NAME" ]; then
    docker exec -i "$POSTGRES_CONTAINER_NAME" psql -U posduif -d tenant_1 <<EOF > /dev/null 2>&1 || true
    INSERT INTO users (id, username, user_type, online_status, created_at) 
    VALUES ('00000000-0000-0000-0000-000000000001', 'test_web_user', 'web', true, NOW()) 
    ON CONFLICT (username) DO NOTHING;
EOF
else
    echo -e "${YELLOW}⚠ Could not find PostgreSQL container. Skipping test user creation.${NC}"
fi

# Login and create enrollment token
echo -e "${YELLOW}Creating enrollment token...${NC}"
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test_web_user","password":"any"}')

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}✗ Failed to login${NC}"
    exit 1
fi

ENROLLMENT_RESPONSE=$(curl -s -X POST http://localhost:8080/api/enrollment/create \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

ENROLLMENT_TOKEN=$(echo "$ENROLLMENT_RESPONSE" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p' | head -1)
ENROLLMENT_URL="$PUBLIC_URL/api/enrollment/$ENROLLMENT_TOKEN"

echo -e "${GREEN}✓ Enrollment token created${NC}"
echo ""
echo -e "${YELLOW}=== Enrollment Information ===${NC}"
echo -e "Enrollment URL: ${GREEN}$ENROLLMENT_URL${NC}"
echo -e "Token: ${GREEN}$ENROLLMENT_TOKEN${NC}"
echo ""

# Setup Python environment for QR code generation
PYTHON_CMD=""
VENV_WE_ACTIVATED=false

if command -v python3 &> /dev/null; then
    echo -e "${YELLOW}Setting up Python environment for QR code generation...${NC}"
    
    # Check if already in a virtual environment
    if [ -n "$VIRTUAL_ENV" ]; then
        echo -e "${GREEN}✓ Already in virtual environment: $VIRTUAL_ENV${NC}"
        PYTHON_CMD="python3"
    else
        # Check for venv in project root
        VENV_DIR="$PROJECT_ROOT/venv"
        if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/activate" ]; then
            echo -e "${YELLOW}Activating existing virtual environment...${NC}"
            source "$VENV_DIR/bin/activate"
            PYTHON_CMD="python3"
            VENV_WE_ACTIVATED=true
        else
            # Create new venv
            echo -e "${YELLOW}Creating virtual environment...${NC}"
            python3 -m venv "$VENV_DIR"
            source "$VENV_DIR/bin/activate"
            PYTHON_CMD="python3"
            VENV_WE_ACTIVATED=true
            echo -e "${GREEN}✓ Virtual environment created${NC}"
        fi
    fi
    
    # Check if qrcode is installed
    if ! $PYTHON_CMD -c "import qrcode" 2>/dev/null; then
        echo -e "${YELLOW}Installing qrcode[pil]...${NC}"
        $PYTHON_CMD -m pip install --quiet qrcode[pil]
        echo -e "${GREEN}✓ qrcode[pil] installed${NC}"
    else
        echo -e "${GREEN}✓ qrcode module already available${NC}"
    fi
    
    # Generate QR code
    echo -e "${YELLOW}Generating QR code...${NC}"
    QR_OUTPUT=$($PYTHON_CMD << EOF 2>&1
import qrcode
import sys

try:
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data('$ENROLLMENT_URL')
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    img.save('/tmp/enrollment_qr.png')
    print("QR code saved to /tmp/enrollment_qr.png")
    sys.exit(0)
except Exception as e:
    print(f"Error generating QR code: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    )
    QR_EXIT_CODE=$?
    
    if [ $QR_EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ QR code saved to /tmp/enrollment_qr.png${NC}"
        echo -e "${YELLOW}  Open it with: open /tmp/enrollment_qr.png${NC}"
    else
        echo -e "${RED}✗ Failed to generate QR code${NC}"
        if [ -n "$QR_OUTPUT" ]; then
            echo -e "${RED}  Error: $QR_OUTPUT${NC}"
        fi
        echo -e "${YELLOW}  Use an online QR code generator with URL: $ENROLLMENT_URL${NC}"
    fi
    
    # Deactivate venv if we activated it ourselves
    if [ "$VENV_WE_ACTIVATED" = true ]; then
        deactivate 2>/dev/null || true
    fi
else
    echo -e "${YELLOW}⚠ python3 not found. Cannot generate QR code image${NC}"
    echo -e "${YELLOW}  Install python3 or use an online QR code generator with URL: $ENROLLMENT_URL${NC}"
fi

echo ""
echo -e "${YELLOW}=== Next Steps ===${NC}"
echo "1. Deploy mobile app to tablet:"
echo -e "   ${GREEN}cd mobile && flutter run${NC}"
echo ""
echo "2. The app will open with QR scanner"
echo ""
echo "3. Display the QR code (from /tmp/enrollment_qr.png or online generator)"
echo ""
echo "4. Scan the QR code with the tablet"
echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "To stop services:"
if [ -n "$SYNC_ENGINE_PID" ]; then
    echo "  - Sync engine: kill $SYNC_ENGINE_PID"
fi
if [ -n "$NGROK_PID" ]; then
    echo "  - ngrok: kill $NGROK_PID"
fi
echo "  - Docker Compose: cd infrastructure && docker-compose down"
echo "  - Cleanup binary: rm -f /tmp/sync-engine"

