#!/bin/bash
# Test Homebrew installation and app launch
set -e

TAP_NAME="kawaz/laserguide"
APP_NAME="LaserGuide"
APP_PATH="/Applications/${APP_NAME}.app"

echo "🧹 Cleaning up previous installation..."
brew uninstall --cask laserguide 2>/dev/null || true
pkill -9 "$APP_NAME" 2>/dev/null || true

echo "🔄 Updating tap..."
brew untap "$TAP_NAME" 2>/dev/null || true
brew tap "$TAP_NAME"

echo "📦 Installing $APP_NAME..."
brew install --cask laserguide --no-quarantine

echo "✅ Installation complete"

echo "🚀 Launching app..."
open "$APP_PATH"
sleep 3

echo "🔍 Verifying app is running..."
if ps aux | grep -v grep | grep "$APP_PATH" > /dev/null; then
    pid=$(ps aux | grep -v grep | grep "$APP_PATH" | awk '{print $2}')
    echo "✅ $APP_NAME is running (PID: $pid)"
    
    echo ""
    echo "📋 Manual verification checklist:"
    echo "  1. Move mouse - laser should appear"
    echo "  2. Stop moving - laser disappears after 0.3s"
    echo "  3. Scroll fast and release - laser disappears immediately"
    echo ""
    echo "App is ready for testing!"
    exit 0
else
    echo "❌ $APP_NAME is not running"
    exit 1
fi
