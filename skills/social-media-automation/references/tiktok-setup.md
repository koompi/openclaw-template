# TikTok Automation Setup

## Approach
Uses [tiktokautouploader](https://github.com/haziq-exe/TikTokAutoUploader) with [Phantomwright](https://pypi.org/project/phantomwright/) stealth engine.

**This is NOT the official TikTok API.** It uses browser automation. The official TikTok Content Posting API requires Login Kit, app review, and a video demo — taking weeks to set up. This library gets us posting immediately but is less reliable.

## ⚠️ Warnings
- **Experiment only** — never use on main accounts
- **Test account only** — use a throwaway account
- **No spamming** — max 1-3 posts/day
- **Cookies expire** — refresh from browser when uploads fail
- **Datacenter IP risk** — residential proxy recommended for production use

## Installation

```bash
pip3 install tiktokautouploader
phantomwright_driver install chromium
```

Requires Node.js (npm) for JS dependencies built under the hood.

## Authentication (Cookie-based)

The library stores cookies in `TK_cookies_<username>.json` in the working directory.

### How to get cookies:
1. Log into your TEST TikTok account in a browser
2. F12 → **Application** → **Cookies** → `tiktok.com`
3. Copy values for: `sessionid`, `sid_tt`, `sessionid_ss`, `password_auth_status`
4. Run `./scripts/setup-tiktok.sh` which creates the cookie file automatically

### Cookie file format:
```json
[
  {"name": "sessionid", "value": "...", "domain": ".tiktok.com", "path": "/", "httpOnly": true, "secure": true, "sameSite": "Lax"},
  {"name": "sid_tt", "value": "...", "domain": ".tiktok.com", "path": "/", "httpOnly": true, "secure": true, "sameSite": "Lax"},
  {"name": "sessionid_ss", "value": "...", "domain": ".tiktok.com", "path": "/", "httpOnly": true, "secure": true, "sameSite": "Lax"},
  {"name": "password_auth_status", "value": "...", "domain": ".tiktok.com", "path": "/", "httpOnly": true, "secure": true, "sameSite": "Lax"}
]
```

### Important: `document.cookie` does NOT work!
TikTok sets session cookies as HttpOnly. You MUST get them from Application → Cookies tab, not from the Console.

## Upload Usage

```python
from tiktokautouploader import upload_tiktok

# ⚠️ Always use stealth=True
result = upload_tiktok(
    video='path/to/video.mp4',
    description='Your caption here',
    accountname='your_username',
    hashtags=['#fun', '#viral'],
    stealth=True,         # REQUIRED - adds human-like delays
    headless=False,       # Headed mode (uses Xvfb on servers)
    suppressprint=False,
    copyrightcheck=False
)
```

### Key parameters:
| Parameter | Required | Notes |
|---|---|---|
| `video` | ✅ | Path to mp4 file |
| `description` | ✅ | Caption |
| `accountname` | ✅ | TikTok username |
| `stealth` | ✅ | ALWAYS True — prevents TikTok from blocking the final post |
| `headless` | ❌ | False on servers (use Xvfb), True on desktop |
| `hashtags` | ❌ | List of hashtags |
| `sound_name` | ❌ | TikTok sound name to add |
| `schedule` | ❌ | 'HH:MM' format |
| `copyrightcheck` | ❌ | Runs copyright check before uploading |

## Known Issues & Fixes

### Tutorial popup blocking upload
TikTok shows a `react-joyride` tutorial overlay for new accounts that blocks clicks.
Fix: Remove the overlay before the library tries to dismiss popups.

In `/usr/local/lib/python3.10/dist-packages/tiktokautouploader/function.py`:
```python
# Before the existing "Cancel" button check, add:
if page.locator("#react-joyride-portal").is_visible():
    page.evaluate("document.getElementById('react-joyride-portal')?.remove()")
```

### Upload starts but doesn't publish (exit code 1)
This happens when `stealth=True` is not set. TikTok detects the automated post action and silently blocks it.
**Fix:** Always use `stealth=True`.

### Cookies expired
Re-export from browser and update the cookie file.

### Cookie Expiration (Important!)
TikTok session cookies are **short-lived** — typically **1-7 days** depending on login method:
- Line OAuth: ~1-3 days
- Email/password: ~3-7 days
- Browser session: expires when you close browser

**Our cookie files have hardcoded expiry dates** (for compatibility with the library's `check_expiry()` function). The real expiration is controlled by TikTok's servers, not the cookie file.

**Rule: If an upload fails, do NOT retry blindly.** Treat failure as "cookies expired" and:
1. Ask Boss to re-export cookies from browser
2. Update the cookie file
3. Try again

**Recommended:** Refresh cookies every 2-3 days for reliability, or whenever an upload fails.

## Running on a Server (no GUI)

```bash
xvfb-run --auto-servernum --server-args='-screen 0 1280x720x24' python3 upload.py
```

Requires: `apt-get install xvfb`

## Tested Configuration (2026-04-01)
- **Library:** tiktokautouploader v5.8
- **Browser:** Chromium via Phantomwright
- **Python:** 3.10+
- **OS:** Ubuntu 22.04 (server, no GUI)
- **Account:** @ayeye_67 (test account)
- **Result:** ✅ Video uploaded successfully with `stealth=True`
