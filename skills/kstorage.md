# KStorage — KOOMPI Cloud Object Storage

Upload files → get public CDN URLs. S3/R2-compatible.

## Config

- **API Key:** `$KSTORAGE_API_KEY` env var
- **Auth Header:** `x-api-key: sk_...` (NOT Bearer token)
- **CDN Base:** `https://storage.koompi.cloud`
- **API Base:** `https://api-kconsole.koompi.cloud`

---

## Upload Flow (3 Steps)

### Step 1 — Get Upload Token
```bash
KEY="$KSTORAGE_API_KEY"
FILENAME="my-file.png"
FILESIZE=$(stat -c%s "$FILENAME")
CONTENT_TYPE="image/png"

curl -s -X POST "https://api-kconsole.koompi.cloud/api/storage/upload-token" \
  -H "x-api-key: $KEY" \
  -H "Content-Type: application/json" \
  -d "{\"filename\":\"$FILENAME\",\"contentType\":\"$CONTENT_TYPE\",\"size\":$FILESIZE,\"visibility\":\"public\"}"
```

Returns: `{ "success": true, "data": { "uploadUrl": "...", "objectId": "...", "key": "..." } }`

### Step 2 — Upload Binary to R2
```bash
curl -s -X PUT \
  -H "Content-Type: $CONTENT_TYPE" \
  --data-binary "@$FILENAME" \
  "$UPLOAD_URL"
```

### Step 3 — Confirm Upload (REQUIRED within 1 hour)
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

---

## One-Liner Upload Function

```bash
upload_to_kstorage() {
  local FILE="$1"
  local KEY="$KSTORAGE_API_KEY"
  local FNAME=$(basename "$FILE")
  local FSIZE=$(stat -c%s "$FILE")
  local CTYPE=$(file --mime-type -b "$FILE")
  local API="https://api-kconsole.koompi.cloud/api/storage"

  # Step 1: Get upload token
  local RESP=$(curl -s -X POST "$API/upload-token" \
    -H "x-api-key: $KEY" \
    -H "Content-Type: application/json" \
    -d "{\"filename\":\"$FNAME\",\"contentType\":\"$CTYPE\",\"size\":$FSIZE,\"visibility\":\"public\"}")

  local UPLOAD_URL=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['uploadUrl'])")
  local OBJECT_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['objectId'])")
  local OBJ_KEY=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['key'])")

  # Step 2: Upload binary
  curl -s -X PUT -H "Content-Type: $CTYPE" --data-binary "@$FILE" "$UPLOAD_URL"

  # Step 3: Confirm
  curl -s -X POST "$API/complete" \
    -H "x-api-key: $KEY" \
    -H "Content-Type: application/json" \
    -d "{\"objectId\":\"$OBJECT_ID\"}"

  echo "https://storage.koompi.cloud/$OBJ_KEY"
}
```

---

## Other Operations

```bash
# List objects
curl -s "https://api-kconsole.koompi.cloud/api/storage/objects?page=1&limit=50&visibility=public" \
  -H "x-api-key: $KSTORAGE_API_KEY"

# Get pre-signed URL for private file
curl -s "https://api-kconsole.koompi.cloud/api/storage/objects/{objectId}/url?expiresIn=600" \
  -H "x-api-key: $KSTORAGE_API_KEY"

# Delete object
curl -s -X DELETE "https://api-kconsole.koompi.cloud/api/storage/objects/{objectId}" \
  -H "x-api-key: $KSTORAGE_API_KEY"
```

---

## ⚠️ Common Mistakes

1. **GET for upload-token** — it's POST with JSON body
2. **Bearer token** — KStorage uses `x-api-key`, not `Authorization: Bearer`
3. **`key` for confirm** — confirm requires `objectId`, not `key`
4. **Forgetting to confirm** — unconfirmed uploads auto-delete after 1 hour
5. **response.uploadUrl** — it's nested: `response.data.uploadUrl`
