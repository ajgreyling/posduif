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

if ! docker-compose ps | grep -q "Up" && ! docker compose ps | grep -q "Up"; then
    echo -e "${YELLOW}Starting Docker Compose services...${NC}"
    docker-compose up -d > /dev/null 2>&1 || docker compose up -d > /dev/null 2>&1
    echo "Waiting for services to be ready..."
    sleep 10
else
    echo -e "${GREEN}✓ Docker Compose services are running${NC}"
fi

# Check if sync engine is running
echo -e "${YELLOW}Checking sync engine...${NC}"
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Sync engine is running${NC}"
else
    echo -e "${YELLOW}Starting sync engine...${NC}"
    cd "$PROJECT_ROOT/sync-engine"
    go run ./cmd/sync-engine/main.go --config=../config/config.yaml > /tmp/sync-engine.log 2>&1 &
    SYNC_ENGINE_PID=$!
    echo "Waiting for sync engine to start..."
    sleep 5
    
    if curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Sync engine started (PID: $SYNC_ENGINE_PID)${NC}"
    else
        echo -e "${RED}✗ Failed to start sync engine${NC}"
        exit 1
    fi
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
PGPASSWORD=secret psql -h localhost -U posduif -d tenant_1 -c "
    INSERT INTO users (id, username, user_type, online_status, created_at) 
    VALUES ('00000000-0000-0000-0000-000000000001', 'test_web_user', 'web', true, NOW()) 
    ON CONFLICT (username) DO NOTHING;
" > /dev/null 2>&1 || true

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

# Generate QR code using Python or provide URL
if command -v python3 &> /dev/null; then
    echo -e "${YELLOW}Generating QR code...${NC}"
    python3 << EOF
import qrcode
import sys

qr = qrcode.QRCode(version=1, box_size=10, border=5)
qr.add_data('$ENROLLMENT_URL')
qr.make(fit=True)

img = qr.make_image(fill_color="black", back_color="white")
img.save('/tmp/enrollment_qr.png')
print("QR code saved to /tmp/enrollment_qr.png")
EOF
    echo -e "${GREEN}✓ QR code saved to /tmp/enrollment_qr.png${NC}"
    echo -e "${YELLOW}  Open it with: open /tmp/enrollment_qr.png${NC}"
else
    echo -e "${YELLOW}Install python3 and qrcode[pil] to generate QR code image${NC}"
    echo -e "${YELLOW}  Or use an online QR code generator with URL: $ENROLLMENT_URL${NC}"
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
echo "  - Sync engine: kill $SYNC_ENGINE_PID (if started)"
echo "  - ngrok: kill $NGROK_PID (if started)"
echo "  - Docker Compose: cd infrastructure && docker-compose down"

