#!/bin/bash
# Sync Japanese documentation from English versions
# This ensures .ja.md files stay in sync with their English counterparts

set -e

DOCS=(
    "README.md"
    ".github/workflows/README.md"
)

echo "📝 Syncing Japanese documentation..."

for doc in "${DOCS[@]}"; do
    ja_doc="${doc%.md}.ja.md"

    if [ -f "$doc" ]; then
        echo "  Copying $doc -> $ja_doc"
        cp "$doc" "$ja_doc"
    else
        echo "  ⚠️  Warning: $doc not found"
    fi
done

echo "✅ Japanese documentation synced"
echo ""
echo "Note: These are direct copies. Consider translating them later if needed."
