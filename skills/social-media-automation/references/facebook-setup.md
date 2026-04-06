# Facebook Page Automation Setup Guide

## Prerequisites
- A Facebook Page (any Page works, personal account stays safe)
- Meta Developer account (free, anyone can create)

## Step 1: Create Meta App
1. Go to https://developers.facebook.com/apps
2. Click **Create App** → select **Business** type
3. Name it anything (e.g. "AyEye Automation")
4. Ignore any "Facebook Login unavailable" error — it's irrelevant

## Step 2: Get Your Credentials
From your App Dashboard → **Settings → Basic**, note:
- **App ID** (a number)
- **App Secret** (click "Show" to reveal)

## Step 3: Generate a User Token
1. Go to https://developers.facebook.com/tools/explorer (Graph API Explorer)
2. In the top dropdown, select **your User account** (NOT the Page)
3. Click **Add a permission** → add `pages_show_list`, `pages_manage_posts`, `pages_read_engagement`
4. Click **Generate Access Token**
5. Copy the token — this is your **short-lived User Token** (~1 hour)

## Step 4: Exchange for Long-Lived User Token (60 days)
```bash
curl -s "https://graph.facebook.com/v21.0/oauth/access_token?grant_type=fb_exchange_token&client_id={APP_ID}&client_secret={APP_SECRET}&fb_exchange_token={SHORT_LIVED_TOKEN}"
```
Returns a token with `expires_in: ~5184000` (~60 days).

**Or use the Access Token Debugger:** https://developers.facebook.com/tools/debug/accesstoken → paste token → click "Extend Access Token"

## Step 5: Generate Never-Expiring Page Token
Use the long-lived User Token from Step 4:
```bash
curl -s "https://graph.facebook.com/v21.0/me/accounts?access_token={LONG_LIVED_USER_TOKEN}"
```
The `access_token` in the response for your Page will **never expire**.

**Verify:** Paste the Page token into the Access Token Debugger → "Expires" should say "Never".

## Step 6: Post to Page
```bash
curl -s -X POST "https://graph.facebook.com/v21.0/{PAGE_ID}/feed" \
  -d "message=Your post content here" \
  -d "access_token={NEVER_EXPIRING_PAGE_TOKEN}"
```
Returns `{"id": "PAGEID_POSTID"}` on success.

## Key Lessons
- **User token ≠ Page token.** User token accesses your profile; Page token accesses your Page.
- **Short-lived Page tokens expire in ~1 hour.** Always exchange for never-expiring via the flow above.
- **"Facebook Login unavailable" error** is harmless. We only need Page permissions, not Login.
- **Page bans don't affect personal account.** Pages are disposable containers.
- **Rate limits:** ~25 posts/day, ~500 comments/day — more than enough for normal use.
- **Never-expiring tokens can be invalidated** if you change your Facebook password, de-authorize the app, or remove Page admin role.
- **Page ID** found in Graph API Explorer response or Page URL.

## Token Flow Summary
```
Short-lived User Token (1 hour)
    ↓ exchange with App ID + Secret
Long-lived User Token (60 days)
    ↓ GET /me/accounts
Never-Expiring Page Token (∞)
```

## Useful Endpoints
| Action | Method | Endpoint |
|---|---|---|
| Post | POST | `/{page_id}/feed` |
| Post with image | POST | `/{page_id}/photos` with `url` or `source` param |
| Get posts | GET | `/{page_id}/posts?fields=id,message,created_time` |
| Get comments | GET | `/{post_id}/comments?fields=id,message,from,created_time` |
| Reply to comment | POST | `/{comment_id}/comments` |
| Delete post | DELETE | `/{post_id}` |
| Delete comment | DELETE | `/{comment_id}` |
