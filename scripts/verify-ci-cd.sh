#!/bin/bash
# Verify CI/CD workflow completion and release creation
set -e

REPO="kawaz/LaserGuide"
TIMEOUT=120
INTERVAL=10

echo "🔍 Waiting for CI/CD workflows to complete..."
sleep 15

elapsed=0
while [ $elapsed -lt $TIMEOUT ]; do
    # Check workflow status
    runs=$(gh run list --repo "$REPO" --limit 3 --json status,conclusion,name)
    
    # Check if all runs completed
    in_progress=$(echo "$runs" | jq -r '.[] | select(.status == "in_progress") | .name' | wc -l | tr -d ' ')
    
    if [ "$in_progress" -eq 0 ]; then
        echo "✅ All workflows completed"
        
        # Show results
        echo "$runs" | jq -r '.[] | "\(.name): \(.conclusion)"'
        
        # Check for failures (ignore Code Quality)
        failures=$(echo "$runs" | jq -r '.[] | select(.conclusion == "failure" and .name != "Code Quality") | .name')
        if [ -n "$failures" ]; then
            echo "❌ Workflow failures detected:"
            echo "$failures"
            exit 1
        fi
        
        # Verify release created
        echo ""
        echo "🔍 Checking for new release..."
        latest_release=$(gh release list --repo "$REPO" --limit 1 --json tagName,publishedAt | jq -r '.[0]')
        tag=$(echo "$latest_release" | jq -r '.tagName')
        published=$(echo "$latest_release" | jq -r '.publishedAt')
        echo "✅ Latest release: $tag (published: $published)"
        
        exit 0
    fi
    
    echo "⏳ Workflows still running... ($elapsed/$TIMEOUT seconds)"
    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))
done

echo "❌ Timeout waiting for workflows"
exit 1
