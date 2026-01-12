# Mobile App Setup Guide

This guide will help you deploy the Posduif mobile app to your Samsung tablet and complete QR code enrollment.

## Prerequisites

1. **Samsung Tablet Setup:**
   - Enable Developer Mode:
     - Go to Settings > About tablet
     - Tap "Build number" 7 times
   - Enable USB Debugging:
     - Go to Settings > Developer options
     - Enable "USB debugging"
     - Connect tablet via USB to your computer
   - Authorize computer when prompted on tablet

2. **Backend Services:**
   - PostgreSQL and Redis running (via Docker Compose)
   - Sync engine running on port 8080
   - ngrok tunnel active (for external access)

## Quick Setup

Run the setup script:

```bash
./scripts/quick-mobile-setup.sh
```

This will:
1. Start Docker Compose services (PostgreSQL, Redis)
2. Start the sync engine
3. Start ngrok tunnel
4. Create enrollment token
5. Display QR code URL

## Step-by-Step Manual Setup

### 1. Start Backend Services

```bash
# Start Docker Compose
cd infrastructure
docker-compose up -d

# Start sync engine (in another terminal)
cd sync-engine
go run ./cmd/sync-engine/main.go --config=../config/config.yaml
```

### 2. Start ngrok Tunnel

```bash
ngrok http 8080
```

Note the HTTPS URL (e.g., `https://xxxxx.ngrok-free.app`)

### 3. Create Enrollment Token

```bash
# Login as web user
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test_web_user","password":"any"}' \
  | grep -o '"token":"[^"]*' | cut -d'"' -f4)

# Create enrollment
ENROLL_RESP=$(curl -s -X POST http://localhost:8080/api/enrollment/create \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

# Extract enrollment URL
ENROLL_URL=$(echo "$ENROLL_RESP" | grep -o '"enrollment_url":"[^"]*' | cut -d'"' -f4)
echo "Enrollment URL: $ENROLL_URL"
```

### 4. Generate QR Code

You can generate a QR code using:

**Option A: Web App**
```bash
cd web
flutter run -d chrome
# Navigate to /enrollment and generate QR code
```

**Option B: Online Generator**
- Go to https://qr-code-generator.com/
- Paste the enrollment URL
- Generate and display QR code

**Option C: Python (if installed)**
```bash
pip install qrcode[pil]
python3 << EOF
import qrcode
qr = qrcode.QRCode()
qr.add_data('$ENROLL_URL')
qr.make()
img = qr.make_image()
img.save('/tmp/enrollment_qr.png')
EOF
open /tmp/enrollment_qr.png
```

### 5. Deploy Mobile App to Tablet

```bash
cd mobile

# Check device is connected
flutter devices

# Deploy and run
flutter run
```

The app will:
1. Request all permissions
2. Open QR scanner screen
3. Wait for you to scan the enrollment QR code

### 6. Complete Enrollment

1. Display the QR code on your computer screen
2. Point the tablet camera at the QR code
3. The app will automatically:
   - Validate the enrollment token
   - Complete enrollment
   - Fetch app instructions
   - Navigate to home screen

## Troubleshooting

### Device Not Detected

```bash
# Check ADB connection
adb devices

# If device shows as "unauthorized":
# - Check tablet screen for authorization prompt
# - Click "Allow" or "Always allow"

# Restart ADB
adb kill-server
adb start-server
adb devices
```

### Backend Not Accessible

- Check sync engine is running: `curl http://localhost:8080/health`
- Check ngrok is running: Open http://localhost:4040
- Verify ngrok URL is accessible from tablet's network

### QR Code Not Scanning

- Ensure good lighting
- Hold tablet steady
- Make sure QR code is clearly visible
- Check enrollment URL is correct and accessible

### Enrollment Fails

- Check enrollment token hasn't expired (1 hour default)
- Verify backend is accessible via ngrok URL
- Check sync engine logs: `tail -f /tmp/sync-engine.log`
- Verify database has test user: `psql -U posduif -d tenant_1 -c "SELECT * FROM users;"`

## Testing the Enrollment Flow

After successful enrollment:

1. **Verify in Database:**
   ```sql
   SELECT * FROM users WHERE user_type = 'mobile';
   SELECT * FROM enrollment_tokens WHERE used_at IS NOT NULL;
   ```

2. **Test App Instructions:**
   ```bash
   curl -H "X-Device-ID: <device-id>" \
     http://localhost:8080/api/app-instructions
   ```

3. **Test Sync:**
   ```bash
   curl -H "X-Device-ID: <device-id>" \
     http://localhost:8080/api/sync/incoming
   ```

## Next Steps

After enrollment:
- The mobile app is linked to the tenant
- Schema configuration is stored locally
- Database tables are configured dynamically using Drift ORM
- The app can sync with the backend

## Stopping Services

```bash
# Stop ngrok
pkill ngrok

# Stop sync engine
pkill -f sync-engine

# Stop Docker Compose
cd infrastructure
docker-compose down
```



