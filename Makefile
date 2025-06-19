.PHONY: help clean dev build-debug build-release build-zip version-patch version-minor version-major

# Get current version
CURRENT_VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")

# Default target
help:
	@echo "Available commands:"
	@echo "  make dev             - Build debug version and launch"
	@echo "  make build-debug     - Build debug version only"
	@echo "  make build-release   - Build release version"
	@echo "  make build-zip       - Build release version and create zip"
	@echo "  make clean           - Remove build artifacts"
	@echo ""
	@echo "Version management (current: v$(CURRENT_VERSION)):"
	@echo "  make version-patch - Patch release (x.x.Z)"
	@echo "  make version-minor - Minor release (x.Y.0)"
	@echo "  make version-major - Major release (X.0.0)"

# Clean build artifacts
clean:
	@echo "🗑️  Cleaning build artifacts..."
	@rm -rf build/
	@rm -f CursorFinder.zip
	@rm -rf ~/Library/Developer/Xcode/DerivedData/CursorFinder-*
	@find . -name ".DS_Store" -delete
	@echo "✅ Clean complete"

# Development build and launch
dev: build-debug
	@echo "🚀 Launching app..."
	@killall CursorFinder 2>/dev/null || true
	@open build/Build/Products/Debug/CursorFinder.app

# Debug build
build-debug:
	@echo "🔨 Building debug version..."
	@xcodebuild -project CursorFinder.xcodeproj \
		-scheme CursorFinder \
		-configuration Debug \
		-derivedDataPath build \
		build
	@echo "✅ Build complete!"
	@echo "App location: $$(pwd)/build/Build/Products/Debug/CursorFinder.app"

# Release build
build-release:
	@echo "📦 Building release version..."
	@xcodebuild -project CursorFinder.xcodeproj \
		-scheme CursorFinder \
		-configuration Release \
		-derivedDataPath build \
		-archivePath build/CursorFinder.xcarchive \
		archive
	@echo "✅ Release build complete!"

# Release build and create zip
build-zip: clean build-release
	@echo "🎁 Creating zip file..."
	@cd build/CursorFinder.xcarchive/Products/Applications && \
		zip -r ../../../../CursorFinder.zip CursorFinder.app
	@echo "✅ Created CursorFinder.zip"
	@ls -lh CursorFinder.zip

# Version management
version-patch:
	@$(MAKE) _bump-version TYPE=patch

version-minor:
	@$(MAKE) _bump-version TYPE=minor

version-major:
	@$(MAKE) _bump-version TYPE=major

_bump-version:
	@# Fetch latest remote tags
	@echo "🔄 Fetching latest tags from remote..."
	@git fetch --tags --quiet
	@# Get latest version (check both local and remote)
	@LATEST_VERSION=$$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0") && \
	LATEST_TAG_COMMIT=$$(git rev-list -n 1 v$$LATEST_VERSION 2>/dev/null || echo "") && \
	HEAD_COMMIT=$$(git rev-parse HEAD) && \
	if [ "$$LATEST_TAG_COMMIT" = "$$HEAD_COMMIT" ]; then \
		echo "❌ Current commit (HEAD) is already tagged as v$$LATEST_VERSION!" && \
		echo "" && \
		echo "Please create a new commit before releasing:" && \
		echo "   1. Make code changes" && \
		echo "   2. git add . && git commit -m 'your changes'" && \
		echo "   3. git push" && \
		echo "   4. make version-patch/minor/major" && \
		exit 1; \
	fi && \
	if [ -n "$$(git status --porcelain)" ]; then \
		echo "❌ Uncommitted changes detected!" && \
		echo "" && \
		git status --short && \
		echo "" && \
		echo "Please commit your changes first:" && \
		echo "   git add ." && \
		echo "   git commit -m 'your message'" && \
		exit 1; \
	fi && \
	IFS='.' read -r MAJOR MINOR PATCH <<< "$$LATEST_VERSION" && \
	case $(TYPE) in \
		major) NEW_VERSION="$$((MAJOR + 1)).0.0" ;; \
		minor) NEW_VERSION="$${MAJOR}.$$((MINOR + 1)).0" ;; \
		patch) NEW_VERSION="$${MAJOR}.$${MINOR}.$$((PATCH + 1))" ;; \
	esac && \
	echo "📊 Current version: v$$LATEST_VERSION → New version: v$$NEW_VERSION" && \
	if git tag -l "v$$NEW_VERSION" | grep -q . || git ls-remote --tags origin "refs/tags/v$$NEW_VERSION" | grep -q .; then \
		echo "❌ Tag v$$NEW_VERSION already exists!" && \
		echo "" && \
		echo "Please check latest tags:" && \
		echo "   git fetch --tags" && \
		echo "   git tag -l | sort -V | tail -5" && \
		exit 1; \
	fi && \
	git tag "v$$NEW_VERSION" && \
	echo "✅ Created tag: v$$NEW_VERSION" && \
	echo "" && \
	echo "📤 To release, run:" && \
	echo "   git push origin v$$NEW_VERSION" && \
	echo "" && \
	echo "GitHub Actions will automatically:" && \
	echo "  - Create release" && \
	echo "  - Build app" && \
	echo "  - Update Formula"