.PHONY: help clean dev build-debug build-release build-release-zip version-patch version-minor version-major

# 現在のバージョンを取得
CURRENT_VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")

# デフォルトターゲット
help:
	@echo "使用可能なコマンド:"
	@echo "  make dev             - デバッグビルド＆起動"
	@echo "  make build-debug     - デバッグビルドのみ"
	@echo "  make build-release   - リリースビルド"
	@echo "  make build-release-zip - リリースビルド＆zip作成"
	@echo "  make clean           - ビルド成果物を削除"
	@echo ""
	@echo "バージョン管理 (現在: v$(CURRENT_VERSION)):"
	@echo "  make version-patch - パッチリリース (x.x.Z)"
	@echo "  make version-minor - マイナーリリース (x.Y.0)"
	@echo "  make version-major - メジャーリリース (X.0.0)"

# クリーンアップ
clean:
	@echo "🗑️  クリーンアップ中..."
	@rm -rf build/
	@rm -f CursorFinder.zip
	@rm -rf ~/Library/Developer/Xcode/DerivedData/CursorFinder-*
	@find . -name ".DS_Store" -delete
	@echo "✅ クリーンアップ完了"

# 開発用ビルド＆起動
dev: build-debug
	@echo "🚀 アプリを起動中..."
	@killall CursorFinder 2>/dev/null || true
	@open build/Build/Products/Debug/CursorFinder.app

# デバッグビルド
build-debug:
	@echo "🔨 デバッグビルド中..."
	@xcodebuild -project CursorFinder.xcodeproj \
		-scheme CursorFinder \
		-configuration Debug \
		-derivedDataPath build \
		build
	@echo "✅ ビルド完了!"
	@echo "アプリの場所: $$(pwd)/build/Build/Products/Debug/CursorFinder.app"

# リリースビルド
build-release:
	@echo "📦 リリースビルド中..."
	@xcodebuild -project CursorFinder.xcodeproj \
		-scheme CursorFinder \
		-configuration Release \
		-derivedDataPath build \
		-archivePath build/CursorFinder.xcarchive \
		archive
	@echo "✅ リリースビルド完了!"

# リリースビルド＆zip作成
build-release-zip: clean build-release
	@echo "🎁 zipファイルを作成中..."
	@cd build/CursorFinder.xcarchive/Products/Applications && \
		zip -r ../../../../CursorFinder.zip CursorFinder.app
	@echo "✅ CursorFinder.zip を作成しました"
	@ls -lh CursorFinder.zip

# バージョン管理
version-patch:
	@$(MAKE) _bump-version TYPE=patch

version-minor:
	@$(MAKE) _bump-version TYPE=minor

version-major:
	@$(MAKE) _bump-version TYPE=major

_bump-version:
	@# 未コミットの変更をチェック
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "❌ 未コミットの変更があります！" && \
		echo "" && \
		git status --short && \
		echo "" && \
		echo "先にコミットしてください:" && \
		echo "   git add ." && \
		echo "   git commit -m 'your message'" && \
		exit 1; \
	fi
	@# バージョンを分解
	@IFS='.' read -r MAJOR MINOR PATCH <<< "$(CURRENT_VERSION)" && \
	case $(TYPE) in \
		major) NEW_VERSION="$$((MAJOR + 1)).0.0" ;; \
		minor) NEW_VERSION="$${MAJOR}.$$((MINOR + 1)).0" ;; \
		patch) NEW_VERSION="$${MAJOR}.$${MINOR}.$$((PATCH + 1))" ;; \
	esac && \
	echo "🏷️  新しいバージョン: v$$NEW_VERSION" && \
	if git tag -l "v$$NEW_VERSION" | grep -q .; then \
		echo "❌ タグ v$$NEW_VERSION は既に存在します！" && \
		echo "" && \
		echo "リモートにプッシュされていない場合:" && \
		echo "   git push origin v$$NEW_VERSION" && \
		echo "" && \
		echo "タグを削除してやり直す場合:" && \
		echo "   git tag -d v$$NEW_VERSION" && \
		exit 1; \
	fi && \
	git tag "v$$NEW_VERSION" && \
	echo "✅ タグを作成しました: v$$NEW_VERSION" && \
	echo "" && \
	echo "📤 リリースするには以下を実行:" && \
	echo "   git push origin v$$NEW_VERSION" && \
	echo "" && \
	echo "これでGitHub Actionsが自動的に:" && \
	echo "  - リリースを作成" && \
	echo "  - アプリをビルド" && \
	echo "  - Formulaを更新"