#!/bin/bash

# Quick setup for mobile testing - starts backend and ngrok, generates QR code

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "🚀 Posduif Mobile Setup"
echo ""

# Step 1: Start backend services
echo "1️⃣ Starting backend services..."
cd infrastructure
if ! docker-compose ps | grep -q "Up"; then
    docker-compose up -d
    echo "   Waiting for services..."
    sleep 10
fi
cd ..

# Step 2: Start sync engine if not running
if ! curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "2️⃣ Starting sync engine..."
    cd sync-engine
    go run ./cmd/sync-engine/main.go --config=../config/config.yaml > /tmp/sync-engine.log 2>&1 &
    echo "   Sync engine starting (check /tmp/sync-engine.log for logs)"
    sleep 5
    cd ..
else
    echo "2️⃣ ✓ Sync engine already running"
fi

# Step 3: Start ngrok
echo "3️⃣ Starting ngrok tunnel..."
pkill ngrok 2>/dev/null || true
sleep 2

ngrok http 8080 > /tmp/ngrok.log 2>&1 &
NGROK_PID=$!
sleep 4

# Get ngrok URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$NGROK_URL" ]; then
    echo "   ⚠ Could not get ngrok URL. Check http://localhost:4040"
    echo "   Using localhost instead (may not work from tablet)"
    NGROK_URL="http://localhost:8080"
else
    echo "   ✓ ngrok URL: $NGROK_URL"
fi

# Step 4: Create test user and enrollment token
echo "4️⃣ Creating enrollment token..."

# Ensure test user exists
PGPASSWORD=secret psql -h localhost -U posduif -d tenant_1 -c "
    INSERT INTO users (id, username, user_type, online_status, created_at) 
    VALUES ('00000000-0000-0000-0000-000000000001', 'test_web_user', 'web', true, NOW()) 
    ON CONFLICT (username) DO NOTHING;
" > /dev/null 2>&1 || true

# Login
LOGIN_RESP=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test_web_user","password":"any"}')

TOKEN=$(echo "$LOGIN_RESP" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "   ❌ Failed to login"
    exit 1
fi

# Create enrollment
ENROLL_RESP=$(curl -s -X POST http://localhost:8080/api/enrollment/create \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

ENROLL_TOKEN=$(echo "$ENROLL_RESP" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p' | head -1)
ENROLL_URL="$NGROK_URL/api/enrollment/$ENROLL_TOKEN"

echo "   ✓ Enrollment URL: $ENROLL_URL"

# Step 5: Generate QR code
echo "5️⃣ Generating QR code..."

# Try to use web app to generate QR, or provide URL
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 ENROLLMENT QR CODE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "URL: $ENROLL_URL"
echo ""
echo "You can:"
echo "  1. Open the web app: cd web && flutter run -d chrome"
echo "  2. Navigate to /enrollment and generate QR code"
echo "  3. Or use an online QR generator: https://qr-code-generator.com/"
echo "     Paste this URL: $ENROLL_URL"
echo ""

# Try to open web enrollment if possible
if command -v open &> /dev/null; then
    echo "Opening QR code generator..."
    open "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$ENROLL_URL" 2>/dev/null || true
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📲 NEXT STEPS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Ensure your Samsung tablet is connected via USB"
echo "2. Enable USB debugging on the tablet:"
echo "   Settings > About tablet > Tap 'Build number' 7 times"
echo "   Settings > Developer options > Enable 'USB debugging'"
echo ""
echo "3. Deploy the mobile app:"
echo "   cd mobile && flutter run"
echo ""
echo "4. The app will open with QR scanner"
echo "5. Scan the QR code displayed above"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To stop services:"
echo "  pkill ngrok"
echo "  docker-compose -f infrastructure/docker-compose.yml down"
echo ""



