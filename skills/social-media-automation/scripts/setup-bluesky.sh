#!/bin/bash
# Bluesky Setup Script (easiest — no app review needed)
# Usage: ./setup-bluesky.sh

set -e

echo "=== Bluesky Setup ==="
echo ""
echo "Bluesky is the easiest platform to automate — no app review, no developer account."
echo ""

ENV_FILE="$HOME/.openclaw/workspace/.env"

if grep -q "BLUESKY_HANDLE" "$ENV_FILE" 2>/dev/null; then
  echo "✅ Bluesky already configured"
  echo "   Handle: $(grep BLUESKY_HANDLE $ENV_FILE | cut -d= -f2)"
  read -p "   Reconfigure? (y/n): " RECONFIG
  [ "$RECONFIG" != "y" ] && exit 0
fi

read -p "Your Bluesky handle (e.g. user.bsky.social): " HANDLE
read -sp "Your Bluesky App Password (from Settings > App Passwords): " APP_PASS
echo ""

# Test: create session
echo ""
echo "Testing connection..."
SESSION=$(curl -s -X POST "https://bsky.social/xrpc/com.atproto.server.createSession" \
  -H "Content-Type: application/json" \
  -d "{\"identifier\":\"$HANDLE\",\"password\":\"$APP_PASS\"}")

DID=$(echo "$SESSION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('did','FAILED'))" 2>/dev/null)

if [ "$DID" = "FAILED" ]; then
  echo "❌ Authentication failed. Check handle and app password."
  exit 1
fi

echo "  ✅ Connected: $DID"

# Save
sed -i '/^BLUESKY_/d' "$ENV_FILE" 2>/dev/null
echo "BLUESKY_HANDLE=$HANDLE" >> "$ENV_FILE"
echo "BLUESKY_APP_PASSWORD=$APP_PASS" >> "$ENV_FILE"
echo "BLUESKY_DID=$DID" >> "$ENV_FILE"

echo "✅ Bluesky setup complete!"
