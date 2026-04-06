#!/bin/bash
# TikTok Uploader Setup Script
# Uses tiktokautouploader library with Phantomwright stealth engine
# EXPERIMENTAL ONLY - Do not use on main accounts

set -e

echo "=== TikTok Uploader Setup (Experimental) ==="
echo "⚠️  WARNING: This uses browser automation, not official API."
echo "⚠️  Use a TEST account only. Never use your main account."
echo "⚠️  No spamming. Stay within 1-3 posts/day."
echo ""

ENV_FILE="$HOME/.openclaw/workspace/.env"

if grep -q "TIKTOK_" "$ENV_FILE" 2>/dev/null; then
  echo "✅ TikTok already configured"
  read -p "   Reconfigure? (y/n): " RECONFIG
  [ "$RECONFIG" != "y" ] && exit 0
fi

# Check dependencies
echo "Step 1: Checking dependencies..."
python3 -c "from tiktokautouploader import upload_tiktok" 2>/dev/null && echo "  ✅ tiktokautouploader installed" || {
  echo "  ❌ tiktokautouploader not installed"
  echo "  Run: pip3 install tiktokautouploader"
  echo "  Then: phantomwright_driver install chromium"
  exit 1
}

echo ""
echo "Step 2: Get cookies from your browser"
echo "  1. Open tiktok.com in your browser and log into your TEST account"
echo "  2. Press F12 → Application → Cookies → tiktok.com"
echo "  3. Copy values for: sessionid, sid_tt, sessionid_ss, password_auth_status"
echo ""
read -p "TikTok username: " USERNAME
read -p "sessionid value: " SESSIONID
read -p "sid_tt value: " SID_TT
read -p "sessionid_ss value: " SESSIONID_SS
read -p "password_auth_status value: " PASS_AUTH

# Create cookie file
COOKIE_DIR="$HOME/.openclaw/workspace/social-media-automation/mcp-servers/tiktok-uploader"
COOKIE_FILE="$COOKIE_DIR/TK_cookies_${USERNAME}.json"

python3 -c "
import json
cookies = [
    {'name': 'sessionid', 'value': '$SESSIONID', 'domain': '.tiktok.com', 'path': '/', 'httpOnly': True, 'secure': True, 'sameSite': 'Lax', 'expires': 1893456000},
    {'name': 'sid_tt', 'value': '$SID_TT', 'domain': '.tiktok.com', 'path': '/', 'httpOnly': True, 'secure': True, 'sameSite': 'Lax', 'expires': 1893456000},
    {'name': 'sessionid_ss', 'value': '$SESSIONID_SS', 'domain': '.tiktok.com', 'path': '/', 'httpOnly': True, 'secure': True, 'sameSite': 'Lax', 'expires': 1893456000},
    {'name': 'password_auth_status', 'value': '$PASS_AUTH', 'domain': '.tiktok.com', 'path': '/', 'httpOnly': True, 'secure': True, 'sameSite': 'Lax', 'expires': 1893456000}
]
with open('$COOKIE_FILE', 'w') as f:
    json.dump(cookies, f, indent=4)
print('  ✅ Cookie file created')
"

# Test upload
echo ""
echo "Step 3: Test upload..."
read -p "  Path to a test video file (mp4): " VIDEO_PATH

if [ ! -f "$VIDEO_PATH" ]; then
  echo "  ❌ File not found: $VIDEO_PATH"
  exit 1
fi

# Copy video to tiktok-uploader dir
cp "$VIDEO_PATH" "$COOKIE_DIR/test-video.mp4"

cd "$COOKIE_DIR"
xvfb-run --auto-servernum --server-args='-screen 0 1280x720x24' python3 -c "
from tiktokautouploader import upload_tiktok
result = upload_tiktok(
    video='test-video.mp4',
    description='🤖 Test upload via OpenClaw Social Media Skill',
    accountname='$USERNAME',
    stealth=True,
    headless=False,
    suppressprint=False
)
print(f'Result: {result}')
" 2>&1

echo ""
echo "✅ TikTok setup complete!"
echo "   Username: $USERNAME"
echo "   Cookie file: $COOKIE_FILE"
echo ""
echo "⚠️  REMINDERS:"
echo "   - Test account only"
echo "   - Max 1-3 posts/day"
echo "   - Always use stealth=True"
echo "   - Cookies expire — refresh from browser when upload fails"
echo "   - No spamming"
