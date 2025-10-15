#!/bin/bash
# Quick build and run for local development

set -e

echo "🔨 Building LaserGuide (Debug)..."
xcodebuild -project LaserGuide.xcodeproj \
  -scheme LaserGuide \
  -configuration Debug \
  clean build \
  -derivedDataPath ./build-local \
  2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" || true

if [ ! -d "build-local/Build/Products/Debug/LaserGuide.app" ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build succeeded"
echo ""

# Kill any running instances
echo "🛑 Stopping any running instances..."
pkill -9 LaserGuide 2>/dev/null || true
sleep 1

echo "🚀 Launching LaserGuide..."
open build-local/Build/Products/Debug/LaserGuide.app

sleep 2

# Check if running
if ps aux | grep -v grep | grep "build-local/Build/Products/Debug/LaserGuide.app" > /dev/null; then
    pid=$(ps aux | grep -v grep | grep "build-local/Build/Products/Debug/LaserGuide.app" | awk '{print $2}')
    echo "✅ LaserGuide is running (PID: $pid)"
    echo ""
    echo "📋 Test the multi-display PPI correction:"
    echo "  1. Move mouse between displays with different PPI"
    echo "  2. Verify laser lines point accurately to cursor on both displays"
    echo "  3. Check distance indicators are correct when mouse is off-screen"
else
    echo "❌ Failed to launch"
    exit 1
fi
