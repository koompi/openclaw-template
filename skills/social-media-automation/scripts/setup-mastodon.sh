#!/bin/bash
# Mastodon Setup Script
# Usage: ./setup-mastodon.sh [instance_url]

set -e

echo "=== Mastodon Setup ==="
echo ""

ENV_FILE="$HOME/.openclaw/workspace/.env"
INSTANCE="${1:-mastodon.social}"

if grep -q "MASTODON_ACCESS_TOKEN" "$ENV_FILE" 2>/dev/null; then
  echo "✅ Mastodon already configured"
  echo "   Instance: $(grep MASTODON_INSTANCE_URL $ENV_FILE | cut -d= -f2)"
  read -p "   Reconfigure? (y/n): " RECONFIG
  [ "$RECONFIG" != "y" ] && exit 0
fi

echo "Instance: https://$INSTANCE"
echo ""
echo "Get your access token:"
echo "  → Go to https://$INSTANCE/settings/applications"
echo "  → Create new application"
echo "  → Scopes: read, write, follow"
echo "  → Copy the access token"
echo ""
read -p "Paste your Mastodon access token: " TOKEN

# Verify
echo "Verifying..."
RESP=$(curl -s "https://$INSTANCE/api/v1/accounts/verify_credentials" \
  -H "Authorization: Bearer $TOKEN")

USERNAME=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('username','FAILED'))" 2>/dev/null)

if [ "$USERNAME" = "FAILED" ]; then
  echo "❌ Token verification failed: $RESP"
  exit 1
fi

echo "  ✅ Connected: @$USERNAME@$INSTANCE"

sed -i '/^MASTODON_/d' "$ENV_FILE" 2>/dev/null
echo "MASTODON_INSTANCE_URL=https://$INSTANCE" >> "$ENV_FILE"
echo "MASTODON_ACCESS_TOKEN=$TOKEN" >> "$ENV_FILE"

echo "✅ Mastodon setup complete!"
