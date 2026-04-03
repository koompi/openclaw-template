---
name: kstorage
description: Upload files to KStorage (KOOMPI's S3-compatible object storage) and get public CDN URLs. Use when you are asked to upload a file, store an asset, get a CDN link, or host media. Also for checking storage usage or managing uploaded files.
---

# KStorage Skill

KOOMPI Cloud's S3/R2-compatible object storage with CDN. Upload any file → get a public URL instantly.

## Config

- **API Key:** Available as `$KSTORAGE_API_KEY` env var (or `/data/workspace/.env` → `KSTORAGE_API_KEY`)
- **Auth Header:** `x-api-key: sk_...` (bucket-scoped key, NOT Bearer token)
- **CDN Base:** `https://storage.koompi.cloud`
- **API Base:** `https://api-kconsole.koompi.cloud`
- **Upload Path:** `/api/storage/` (no org ID needed — key is bucket-scoped)

## Upload Flow (3-Step)

### Step 1 — Get Upload Token
```bash
KEY="$KSTORAGE_API_KEY"
FILENAME="my-file.png"
FILESIZE=$(stat -c%s "$FILENAME")
CONTENT_TYPE="image/png"

# POST with JSON body — NOT GET with query params!
curl -s -X POST "https://api-kconsole.koompi.cloud/api/storage/upload-token" \
  -H "x-api-key: $KEY" \
  -H "Content-Type: application/json" \
  -d "{\"filename\":\"$FILENAME\",\"contentType\":\"$CONTENT_TYPE\",\"size\":$FILESIZE,\"visibility\":\"public\"}"
```

Returns JSON:
```json
{
  "success": true,
  "data": {
    "uploadUrl": "https://...",
    "objectId": "65d...",
    "key": "org_.../public/uuid.png",
    "expiresIn": 300
  }
}
```

### Step 2 — Upload Binary to R2
```bash
curl -s -X PUT \
  -H "Content-Type: $CONTENT_TYPE" \
  -H "Cache-Control: public, max-age=31536000" \
  --data-binary "@$FILENAME" \
  "$UPLOAD_URL"
```

### Step 3 — Confirm Upload (REQUIRED!)
**CRITICAL:** Must call this within 1 hour or the file is auto-deleted.

```bash
curl -s -X POST "https://api-kconsole.koompi.cloud/api/storage/complete" \
  -H "x-api-key: $KEY" \
  -H "Content-Type: application/json" \
  -d "{\"objectId\":\"$OBJECT_ID\"}"
```

### Public URL
```
https://storage.koompi.cloud/{key}
```

## One-Liner Script

For quick uploads, combine all steps:

```bash
upload_to_kstorage() {
  local FILE="$1"
  local KEY="$KSTORAGE_API_KEY"
  local FNAME=$(basename "$FILE")
  local FSIZE=$(stat -c%s "$FILE")
  local CTYPE=$(file --mime-type -b "$FILE")
  local API="https://api-kconsole.koompi.cloud/api/storage"

  # Step 1: Get upload token (POST with JSON body)
  local RESP=$(curl -s -X POST "$API/upload-token" \
    -H "x-api-key: $KEY" \
    -H "Content-Type: application/json" \
    -d "{\"filename\":\"$FNAME\",\"contentType\":\"$CTYPE\",\"size\":$FSIZE,\"visibility\":\"public\"}")

  local UPLOAD_URL=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['uploadUrl'])")
  local OBJECT_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['objectId'])")
  local OBJ_KEY=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['key'])")

  # Step 2: Upload binary to R2
  curl -s -X PUT -H "Content-Type: $CTYPE" --data-binary "@$FILE" "$UPLOAD_URL"

  # Step 3: Confirm upload (objectId, NOT key!)
  curl -s -X POST "$API/complete" \
    -H "x-api-key: $KEY" \
    -H "Content-Type: application/json" \
    -d "{\"objectId\":\"$OBJECT_ID\"}"

  echo "https://storage.koompi.cloud/$OBJ_KEY"
}
```

## Other Operations

### List Objects
```bash
curl -s "https://api-kconsole.koompi.cloud/api/storage/objects?page=1&limit=50&visibility=public" \
  -H "x-api-key: $KSTORAGE_API_KEY"
```

### Get Private File URL (pre-signed, temporary)
```bash
curl -s "https://api-kconsole.koompi.cloud/api/storage/objects/{objectId}/url?expiresIn=600" \
  -H "x-api-key: $KSTORAGE_API_KEY"
```

### Delete Object
```bash
curl -s -X DELETE "https://api-kconsole.koompi.cloud/api/storage/objects/{objectId}" \
  -H "x-api-key: $KSTORAGE_API_KEY"
```

### Bulk Delete
```bash
curl -s -X POST "https://api-kconsole.koompi.cloud/api/storage/objects/bulk-delete" \
  -H "x-api-key: $KSTORAGE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"objectIds": ["65d...", "65e..."]}'
```

## Riverbase Upload (HQ Endpoint)

For BIS/Riverbase product images, use the HQ endpoint for auto-resizing (max 1920px):

```bash
# HQ upload (auto-resize to max 1920px width)
curl -s -X POST "https://lite-api.riverbase.org/uploads/s3/hq" \
  -H "Authorization: Bearer $BIS_TOKEN" \
  -F "file=@image.jpg"
```

Returns the CDN URL directly.

## Common Use Cases

- **Generated images** from KConsole AI Gateway → upload to KStorage for sharing
- **Social media assets** (logos, covers, banners) → CDN links for embedding
- **Product images** for Riverbase/BIS shops
- **Any file** you want a shareable link for

## ⚠️ Common Mistakes

1. **Using GET for upload-token** — it's POST with JSON body, not GET with query params
2. **Using `Authorization: Bearer`** — KStorage uses `x-api-key` header, not Bearer tokens
3. **Sending `key` to complete** — it requires `objectId`, not `key`
4. **Reading response.uploadUrl** — data is nested: `response.data.uploadUrl`
6. **Forgetting to confirm** — unconfirmed uploads are auto-deleted after 1 hour
