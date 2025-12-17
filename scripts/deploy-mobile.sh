#!/bin/bash

# Quick script to deploy mobile app and set up enrollment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Deploying Posduif Mobile App ==="
echo ""

# Check if device is connected
echo "Checking for connected devices..."
cd "$PROJECT_ROOT/mobile"

DEVICES=$(flutter devices 2>&1 | grep -i "android" || echo "")
if [ -z "$DEVICES" ]; then
    echo "⚠ No Android device detected"
    echo ""
    echo "Please ensure:"
    echo "1. USB debugging is enabled on your Samsung tablet"
    echo "2. Tablet is connected via USB"
    echo "3. You've authorized the computer on the tablet"
    echo ""
    echo "To enable USB debugging:"
    echo "  Settings > About tablet > Tap 'Build number' 7 times"
    echo "  Settings > Developer options > Enable 'USB debugging'"
    echo ""
    read -p "Press Enter when device is connected..."
fi

# Get device ID
DEVICE_ID=$(flutter devices 2>&1 | grep -i "android" | head -1 | awk '{print $5}' || echo "")

if [ -z "$DEVICE_ID" ]; then
    echo "❌ Could not detect device. Trying to list all devices..."
    flutter devices
    read -p "Enter device ID (or press Enter to continue anyway): " DEVICE_ID
fi

# Build and deploy
echo ""
echo "Building and deploying to device..."
if [ -n "$DEVICE_ID" ]; then
    flutter run -d "$DEVICE_ID"
else
    flutter run
fi

