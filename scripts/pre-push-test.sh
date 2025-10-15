#!/bin/bash
# Pre-push test script - Run the same build tests as CI before pushing
# This catches build errors locally before they fail in CI

set -e

echo "🔨 Running pre-push build tests (same as CI)..."
echo ""

# Test 1: Debug build without code signing (CI environment simulation)
echo "📝 Test 1: Debug build without code signing..."
xcodebuild clean build \
  -scheme LaserGuide \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build-test \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" || true

# Check if build succeeded
if [ ! -d "build-test/Build/Products/Debug/LaserGuide.app" ]; then
    echo "❌ Debug build failed"
    exit 1
fi
echo "✅ Debug build succeeded"
echo ""

# Test 2: Release build with code signing (for deployment)
echo "📝 Test 2: Release build with code signing..."
xcodebuild clean build \
  -project LaserGuide.xcodeproj \
  -scheme LaserGuide \
  -configuration Release \
  -derivedDataPath build-release \
  2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" || true

# Check if build succeeded (look for any Release .app bundle)
RELEASE_APP=$(find build-release -name "LaserGuide.app" -path "*/Release/*" 2>/dev/null | head -1)
if [ -z "$RELEASE_APP" ]; then
    echo "❌ Release build failed - app not found"
    exit 1
fi
echo "✅ Release build succeeded"
echo ""

# Cleanup
echo "🧹 Cleaning up build artifacts..."
rm -rf build-test build-release

echo ""
echo "✅ All pre-push tests passed!"
echo "You can now safely push to main."
