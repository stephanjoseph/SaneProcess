#!/bin/bash

# =============================================================================
# SaneApps Website Publisher
# Deploys website to Cloudflare Pages
# =============================================================================

set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
SITE_NAME="$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')-site"
CF_ACCOUNT_ID="2c267ab06352ba2522114c3081a8c5fa"
WEBSITE_DIR="$PROJECT_DIR/docs"

echo "--- Publishing $PROJECT_NAME website to Cloudflare Pages ---"

# Check website directory exists
if [ ! -d "$WEBSITE_DIR" ] || [ ! -f "$WEBSITE_DIR/index.html" ]; then
    echo "Error: No website found at $WEBSITE_DIR"
    osascript -e "display notification \"No website directory found\" with title \"$PROJECT_NAME Publisher\" subtitle \"Publication Failed\""
    exit 1
fi

# Deploy to Cloudflare Pages
echo "Deploying to Cloudflare Pages (project: $SITE_NAME)..."
CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT_ID" \
  npx wrangler pages deploy "$WEBSITE_DIR" \
  --project-name="$SITE_NAME" \
  --commit-dirty=true \
  --commit-message="Website update $(date +%Y-%m-%d)"

if [ $? -eq 0 ]; then
    echo "Publication successful!"
    osascript -e "display notification \"Website deployed to Cloudflare Pages\" with title \"$PROJECT_NAME Publisher\" subtitle \"Publication Complete\""
else
    echo "Publication failed!"
    osascript -e "display notification \"Cloudflare Pages deploy failed\" with title \"$PROJECT_NAME Publisher\" subtitle \"Publication Failed\""
    exit 1
fi

echo "--- Finished: $(date) ---"
