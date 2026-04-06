---
name: social-media
description: Post, read, reply, and manage content across social media platforms via official APIs. Supports Facebook (Meta Graph API), Instagram (Graph API), Threads API, TikTok Content Posting API, X/Twitter API v2, YouTube Data API v3, LinkedIn API, Pinterest API v5, Bluesky (AT Protocol), and Mastodon. Use when Boss asks to post on social media, schedule content, read comments, reply to engagement, upload media, or manage multiple social accounts. Also use when setting up social media automation for a new page/account.
---

# Social Media Automation Skill

Unified skill for managing social media through **official APIs only**. No browsers, no bots, no detection risk.

## Platform Quick Reference

| Platform | API | Auth | Cost | App Review? |
|---|---|---|---|---|
| **Facebook** | Meta Graph API v21.0 | OAuth 2.0 / Page Token | Free | Yes (live permissions) |
| **Instagram** | Instagram Graph API | OAuth 2.0 (via Meta) | Free | Yes |
| **Threads** | Threads API | OAuth 2.0 | Free | Yes |
| **TikTok** | Content Posting API v2 | OAuth 2.0 | Free | Yes |
| **X/Twitter** | X API v2 | OAuth 2.0 PKCE | $100/mo (Basic) | No |
| **YouTube** | Data API v3 | OAuth 2.0 | Free (quota) | Yes (audit) |
| **LinkedIn** | Marketing API v2 | OAuth 2.0 (3-legged) | Free | Yes (MDP) |
| **Pinterest** | API v5 | OAuth 2.0 | Free | Yes |
| **Bluesky** | AT Protocol (XRPC) | App Password | Free | No |
| **Mastodon** | Mastodon API v1 | OAuth 2.0 / Token | Free | No |

## Configuration

All credentials stored in `~/.openclaw/workspace/.env` or platform-specific config files.

### Facebook
```
FB_PAGE_ACCESS_TOKEN=<never-expiring-page-token>
FB_PAGE_ID=<page_id>
```
⚠️ Always generate a **never-expiring Page token** via the exchange flow (see `references/facebook-setup.md`). Short-lived tokens expire in ~1 hour.

### Instagram
```
IG_ACCESS_TOKEN=<token>
IG_BUSINESS_ACCOUNT_ID=<id>
```
⚠️ Requires Professional (Business/Creator) account linked to a Facebook Page.

### Threads
```
THREADS_ACCESS_TOKEN=<token>
THREADS_USER_ID=<user_id>
```

### TikTok (Browser Automation - Experimental)
```
# Cookies stored in mcp-servers/tiktok-uploader/TK_cookies_<username>.json
# Get from browser: F12 → Application → Cookies → tiktok.com
# Required cookies: sessionid, sid_tt, sessionid_ss, password_auth_status
# ⚠️ Test account only! Never main account!
```

### X/Twitter
```
X_ACCESS_TOKEN=<token>
X_CLIENT_ID=<id>
X_CLIENT_SECRET=<secret>
```

### YouTube
```
YOUTUBE_ACCESS_TOKEN=<token>
YOUTUBE_CLIENT_ID=<id>
YOUTUBE_CLIENT_SECRET=<secret>
```

### LinkedIn
```
LINKEDIN_ACCESS_TOKEN=<token>
LINKEDIN_PERSON_ID=<id>
```

### Pinterest
```
PINTEREST_ACCESS_TOKEN=<token>
PINTEREST_ADVERTISER_ID=<id>
```

### Bluesky
```
BLUESKY_HANDLE=<handle>
BLUESKY_APP_PASSWORD=<password>
```

### Mastodon
```
MASTODON_INSTANCE_URL=<https://mastodon.social>
MASTODON_ACCESS_TOKEN=<token>
```

## Common Operations Per Platform

### Facebook
- **Post:** `POST /v21.0/{page_id}/feed` → `{message, access_token}`
- **Post with image:** `POST /v21.0/{page_id}/photos` → `{url, message, access_token}`
- **Read posts:** `GET /v21.0/{page_id}/posts?fields=id,message,created_time`
- **Read comments:** `GET /v21.0/{post_id}/comments?fields=id,message,from,created_time`
- **Reply to comment:** `POST /v21.0/{comment_id}/comments` → `{message, access_token}`
- **Delete post:** `DELETE /v21.0/{post_id}`
- **Delete comment:** `DELETE /v21.0/{comment_id}`

### Instagram
- **Publish post:** `POST /v21.0/{ig_user_id}/media` (create container) → `POST /v21.0/{ig_user_id}/media_publish` (publish)
- **Publish Reel:** Same as post with `media_type=REELS`
- **Read comments:** `GET /v21.0/{media_id}/comments`
- **Reply to comment:** `POST /v21.0/{comment_id}/replies`

### Threads
- **Post:** `POST https://graph.threads.net/v1.0/{user_id}/threads` → `{media_type, text, access_token}`
- **Reply:** `POST https://graph.threads.net/v1.0/{post_id}/reply` → `{text, access_token}`
- **Get posts:** `GET https://graph.threads.net/v1.0/{user_id}/threads`

### TikTok (Browser Automation - Experimental ⚠️)
- **Upload video:** `upload_tiktok(video, description, accountname, stealth=True)`
- Uses `tiktokautouploader` library with Phantomwright stealth engine
- Cookie-based auth (not OAuth) — export from browser
- **Always use `stealth=True`** — without it, TikTok blocks the final post
- **Test account only** — never main account
- Cookies expire (1-7 days) — refresh from browser when uploads fail. Do NOT retry blindly on failure.
- Setup: `./scripts/setup-tiktok.sh`
- Full docs: `references/tiktok-setup.md`

### X/Twitter
- **Post tweet:** `POST /2/tweets` → `{text: "..."}`
- **Post with media:** Upload to `POST /2/media/upload` first, then tweet with `media.media_ids`
- **Read tweets:** `GET /2/users/{id}/tweets`
- **Reply:** `POST /2/tweets` → `{text: "...", reply: {in_reply_to_tweet_id: "..."}}`

### Bluesky
- **Post:** `POST https://bsky.social/xrpc/com.atproto.repo.createRecord` → `{repo, collection: "app.bsky.feed.post", record: {text: "..."}}`
- **Read feed:** `GET https://bsky.social/xrpc/app.bsky.feed.getTimeline`
- **Reply:** Same as post with `record.reply` fields (`root`, `parent`)

### Mastodon
- **Post:** `POST /api/v1/statuses` → `{status: "..."}`
- **Read timeline:** `GET /api/v1/timelines/home`
- **Reply:** `POST /api/v1/statuses` → `{status: "...", in_reply_to_id: "..."}`

## Setup Scripts

Use `scripts/setup-facebook.sh` through `scripts/setup-bluesky.sh` for guided setup per platform.

## Important Notes

- **Always use official APIs** — never browser automation for posting
- **User token ≠ Page token** for Meta platforms — always get Page token via `/me/accounts`
- **Token refresh:** Most tokens expire. Use refresh tokens where available.
- **Rate limits:** Respect them. 429 responses include `retry_after`.
- **Content guidelines:** Each platform has rules. Don't spam. Quality > quantity.
- **Media uploads:** Typically a 2-step process (upload → reference in post). See platform docs.
- **App Review:** Most platforms require app review for live/production permissions. Test in dev mode first.

## Batch Posting Workflow

For cross-platform posting (same content to multiple platforms):

1. Generate content (text + media) once
2. Post to each platform sequentially with platform-specific formatting
3. Track post IDs in a log file
4. Monitor comments/replies across platforms via cron job

See `scripts/cross-post.sh` for the batch posting utility.
