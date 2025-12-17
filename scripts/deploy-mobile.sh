#!/bin/bash

# Quick script to deploy mobile app and set up enrollment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Deploying Posduif Mobile App ==="
echo ""

cd "$PROJECT_ROOT/mobile"

# Ensure dependencies are installed
echo "📦 Installing Flutter dependencies..."
flutter pub get

# Check if device is connected
echo ""
echo "Checking for connected devices..."
DEVICES=$(flutter devices 2>&1 | grep -i "android" || echo "")
if [ -z "$DEVICES" ]; then
    echo "⚠ No Android device detected"
    echo ""
    echo "Please ensure:"
    echo "1. USB debugging is enabled on your Samsung tablet"
    echo "2. Tablet is connected via USB or wireless ADB"
    echo "3. You've authorized the computer on the tablet"
    echo ""
    echo "To enable USB debugging:"
    echo "  Settings > About tablet > Tap 'Build number' 7 times"
    echo "  Settings > Developer options > Enable 'USB debugging'"
    echo ""
    echo "For wireless debugging:"
    echo "  Settings > Developer options > Wireless debugging > Pair device"
    echo ""
    read -p "Press Enter when device is connected..."
fi

# Get device ID - try to find Android device (supports both USB and wireless)
DEVICE_ID=$(flutter devices 2>&1 | grep -i "android" | head -1 | awk '{for(i=1;i<=NF;i++) if($i ~ /^adb-|^[a-f0-9]+$/) {print $i; exit}}' || echo "")

if [ -z "$DEVICE_ID" ]; then
    echo "❌ Could not detect device. Listing all devices..."
    flutter devices
    echo ""
    read -p "Enter device ID (or press Enter to use default): " MANUAL_DEVICE_ID
    if [ -n "$MANUAL_DEVICE_ID" ]; then
        DEVICE_ID="$MANUAL_DEVICE_ID"
    fi
fi

# Build and deploy
echo ""
echo "🚀 Building and deploying to device..."
if [ -n "$DEVICE_ID" ]; then
    echo "   Target device: $DEVICE_ID"
    flutter run -d "$DEVICE_ID"
else
    echo "   Using default device"
    flutter run
fi

