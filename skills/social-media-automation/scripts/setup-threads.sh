#!/bin/bash
# Threads Setup Script
# Usage: ./setup-threads.sh

set -e

echo "=== Threads Setup ==="
echo ""
echo "Threads uses the Meta developer portal (same as Facebook/Instagram)."
echo ""

ENV_FILE="$HOME/.openclaw/workspace/.env"

if grep -q "THREADS_ACCESS_TOKEN" "$ENV_FILE" 2>/dev/null; then
  echo "✅ Threads already configured"
  read -p "   Reconfigure? (y/n): " RECONFIG
  [ "$RECONFIG" != "y" ] && exit 0
fi

echo "Step 1: Ensure you have a Meta app (same as Facebook setup)"
echo "  → https://developers.facebook.com/apps"
echo ""
echo "Step 2: Add Threads API product in your app dashboard"
echo "  → App Dashboard → Add Product → Threads API"
echo ""
echo "Step 3: Get your Threads access token"
echo "  → Use the same flow as Facebook, but add threads_basic + threads_content_publish permissions"
echo ""
read -p "Paste your Threads access token: " TOKEN

# Verify token by getting user info
echo ""
echo "Verifying token..."
RESP=$(curl -s "https://graph.threads.net/v1.0/me?fields=id,username&access_token=$TOKEN")

THREADS_USER_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id','FAILED'))" 2>/dev/null)
THREADS_USERNAME=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('username','FAILED'))" 2>/dev/null)

if [ "$THREADS_USER_ID" = "FAILED" ]; then
  echo "❌ Token verification failed: $RESP"
  exit 1
fi

echo "  ✅ User: $THREADS_USERNAME ($THREADS_USER_ID)"

# Test post
echo "Testing post..."
TEST_RESP=$(curl -s -X POST "https://graph.threads.net/v1.0/$THREADS_USER_ID/threads" \
  -H "Content-Type: application/json" \
  -d "{\"media_type\":\"TEXT\",\"text\":\"🤖 Automation test — configured via OpenClaw\",\"access_token\":\"$TOKEN\"}")

CREATION_ID=$(echo "$TEST_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id','FAILED'))" 2>/dev/null)

if [ "$CREATION_ID" = "FAILED" ]; then
  echo "❌ Post creation failed: $TEST_RESP"
  exit 1
fi

# Publish the post
PUBLISH_RESP=$(curl -s -X POST "https://graph.threads.net/v1.0/$THREADS_USER_ID/threads/publish" \
  -H "Content-Type: application/json" \
  -d "{\"creation_id\":\"$CREATION_ID\",\"access_token\":\"$TOKEN\"}")

echo "  ✅ Test post published"

# Save
sed -i '/^THREADS_/d' "$ENV_FILE" 2>/dev/null
echo "THREADS_ACCESS_TOKEN=$TOKEN" >> "$ENV_FILE"
echo "THREADS_USER_ID=$THREADS_USER_ID" >> "$ENV_FILE"
echo "THREADS_USERNAME=$THREADS_USERNAME" >> "$ENV_FILE"

echo "✅ Threads setup complete!"
