#!/bin/bash
# Facebook Page Setup Script
# Usage: ./setup-facebook.sh

set -e

echo "=== Facebook Page Setup ==="
echo ""

# Check for existing config
ENV_FILE="$HOME/.openclaw/workspace/.env"
if grep -q "FB_PAGE_ACCESS_TOKEN" "$ENV_FILE" 2>/dev/null; then
  echo "✅ Facebook already configured in .env"
  echo "   Page ID: $(grep FB_PAGE_ID $ENV_FILE | cut -d= -f2)"
  read -p "   Reconfigure? (y/n): " RECONFIG
  [ "$RECONFIG" != "y" ] && exit 0
fi

echo "Step 1: Create Meta App"
echo "  → Go to https://developers.facebook.com/apps"
echo "  → Create App → Business type"
echo "  → Name it anything (e.g. 'My Automation')"
echo "  → IGNORE 'Facebook Login unavailable' error"
echo ""
echo "Step 2: Get Page Token"
echo "  → Go to https://developers.facebook.com/tools/explorer"
echo "  → Select your Page in the dropdown"
echo "  → Add permissions: pages_manage_posts, pages_read_engagement"
echo "  → Click 'Generate Access Token'"
echo ""
read -p "Paste your token: " USER_TOKEN

echo ""
echo "Step 3: Getting Page Token..."
RESP=$(curl -s "https://graph.facebook.com/v21.0/me/accounts?access_token=$USER_TOKEN")

PAGE_NAME=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['name'])" 2>/dev/null)
PAGE_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])" 2>/dev/null)
PAGE_TOKEN=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['access_token'])" 2>/dev/null)

if [ -z "$PAGE_ID" ]; then
  echo "❌ Failed to get page info. Check your token."
  echo "   Response: $RESP"
  exit 1
fi

echo "  ✅ Page: $PAGE_NAME"
echo "  ✅ Page ID: $PAGE_ID"
echo ""

# Test posting
echo "Step 4: Testing post..."
TEST_RESP=$(curl -s -X POST "https://graph.facebook.com/v21.0/$PAGE_ID/feed" \
  -d "message=🤖 Automation test post — configured via OpenClaw Social Media Skill" \
  -d "access_token=$PAGE_TOKEN")

TEST_POST_ID=$(echo "$TEST_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id','FAILED'))" 2>/dev/null)

if [ "$TEST_POST_ID" = "FAILED" ]; then
  echo "❌ Test post failed: $TEST_RESP"
  exit 1
fi

echo "  ✅ Test post published: $TEST_POST_ID"
echo ""

# Save to .env
if ! grep -q "FB_PAGE_ACCESS_TOKEN" "$ENV_FILE" 2>/dev/null; then
  echo "" >> "$ENV_FILE"
fi
sed -i '/^FB_PAGE_/d' "$ENV_FILE" 2>/dev/null
echo "FB_PAGE_ACCESS_TOKEN=$PAGE_TOKEN" >> "$ENV_FILE"
echo "FB_PAGE_ID=$PAGE_ID" >> "$ENV_FILE"

echo "✅ Facebook setup complete!"
echo "   Page: $PAGE_NAME ($PAGE_ID)"
echo "   Token saved to .env"
