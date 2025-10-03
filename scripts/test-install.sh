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

echo "🔏 Verifying code signature..."
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | tee /tmp/codesign_output.txt

# Check if properly signed (not adhoc)
if grep -q "Signature=adhoc" /tmp/codesign_output.txt; then
    echo "⚠️  Warning: App is only adhoc signed (not properly code signed)"
    SIGNATURE_STATUS="adhoc"
elif grep -q "Authority=Apple Development:" /tmp/codesign_output.txt || grep -q "Authority=Developer ID Application:" /tmp/codesign_output.txt; then
    echo "✅ App is properly code signed with Apple certificate"
    SIGNATURE_STATUS="signed"

    # Show certificate details
    grep "Authority=" /tmp/codesign_output.txt | head -1
    grep "TeamIdentifier=" /tmp/codesign_output.txt || true
else
    echo "❌ Unexpected signature status"
    SIGNATURE_STATUS="unknown"
fi

# Test Gatekeeper assessment
echo ""
echo "🔍 Testing Gatekeeper assessment..."
if spctl -a -vvv -t install "$APP_PATH" 2>&1 | tee /tmp/spctl_output.txt; then
    echo "✅ App passes Gatekeeper check"
else
    if grep -q "no usable signature" /tmp/spctl_output.txt; then
        echo "⚠️  App does not pass Gatekeeper (no usable signature)"
    else
        echo "⚠️  App does not pass Gatekeeper check"
        cat /tmp/spctl_output.txt
    fi
fi

rm -f /tmp/codesign_output.txt /tmp/spctl_output.txt

echo ""
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
