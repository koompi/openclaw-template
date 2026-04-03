# KOOMPI AI Gateway — Image & Video Generation

Unified OpenAI-compatible API for text, image, and video generation (Gemini, Imagen, Veo, GLM).

## Config

- **Base URL:** `https://ai.koompi.cloud/v1`
- **API Key:** `$KCONSOLE_AI_KEY` env var (also exported as `$AI_GATEWAY_API_KEY`)
- **Auth:** `Authorization: Bearer $KCONSOLE_AI_KEY`

```typescript
import OpenAI from "openai";
const openai = new OpenAI({
  baseURL: "https://ai.koompi.cloud/v1",
  apiKey: process.env.KCONSOLE_AI_KEY
});
```

---

## Available Models

```bash
curl -X GET "https://ai.koompi.cloud/v1/models" -H "Authorization: Bearer $KCONSOLE_AI_KEY"
```

**Text/Chat:** `gemini-3.1-pro-preview`, `gemini-3-flash-preview`, `glm-5-turbo`, `glm-5`, `glm-4.7-flash`

**Image:** `gemini-3.1-flash-image-preview` (fast), `gemini-3-pro-image-preview` (high quality), `imagen-3.0-generate-001`

**Video:** `veo-3.1-lite-generate-preview` (text only), `veo-3.1-generate-preview` (supports reference images)

---

## Chat Completions

```bash
curl -s -X POST "https://ai.koompi.cloud/v1/chat/completions" \
  -H "Authorization: Bearer $KCONSOLE_AI_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "glm-5-turbo", "messages": [{"role":"user","content":"Hello"}], "stream": true}'
```

---

## Image Generation

Standard `/v1/images/generations` endpoint.

### Parameters

| Param | Description |
|---|---|
| `model` | Image model |
| `prompt` | Text description |
| `size` | Aspect ratio: `1024x1024` (1:1), `1792x1024` (16:9), `1024x1792` (9:16), `1152x896` (4:3) |
| `response_format` | Use `b64_json` |
| `image` | Base64 input image (image-to-image or first frame for video) |
| `reference_image` | Base64 reference for style guidance (Veo 3.1 full only) |
| `image_url` | URL — gateway downloads and converts |

### Text-to-Image
```bash
curl -s -X POST "https://ai.koompi.cloud/v1/images/generations" \
  -H "Authorization: Bearer $KCONSOLE_AI_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-3.1-flash-image-preview",
    "prompt": "A futuristic cyberpunk city under rain",
    "n": 1,
    "size": "1024x1024",
    "response_format": "b64_json"
  }' | python3 -c "
import sys,json,base64
d = json.load(sys.stdin)['data'][0]['b64_json']
with open('output.png','wb') as f: f.write(base64.b64decode(d))
print('Saved: output.png')
"
```

### Image-to-Image (via URL)
```bash
curl -s -X POST "https://ai.koompi.cloud/v1/images/generations" \
  -H "Authorization: Bearer $KCONSOLE_AI_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-3.1-flash-image-preview",
    "prompt": "Transform into watercolor style",
    "image_url": "https://example.com/photo.jpg",
    "response_format": "b64_json"
  }'
```

### Image-to-Image (base64, large payload → temp file)
```bash
python3 -c "
import json, base64, subprocess, os
key = os.environ.get('KCONSOLE_AI_KEY', '')
with open('/data/workspace/input.jpg','rb') as f: img_b64 = base64.b64encode(f.read()).decode()
with open('/tmp/req.json','w') as f: json.dump({
  'model':'gemini-3.1-flash-image-preview',
  'prompt':'Add sunset sky background',
  'reference_image':img_b64,
  'response_format':'b64_json'
}, f)
r = subprocess.run(['curl','-s','-X','POST','https://ai.koompi.cloud/v1/images/generations',
  '-H',f'Authorization: Bearer {key}','-H','Content-Type: application/json',
  '-d','@/tmp/req.json'], capture_output=True, text=True, timeout=120)
data = json.loads(r.stdout)
img = base64.b64decode(data['data'][0]['b64_json'])
with open('/data/workspace/output.png','wb') as f: f.write(img)
print('Saved, size:', len(img))
"
```

---

## Video Generation

⚠️ Video takes **2–10 minutes**. Gateway polls Google automatically and returns MP4 as b64_json.

### Text-to-Video
```bash
curl -s -X POST "https://ai.koompi.cloud/v1/images/generations" \
  -H "Authorization: Bearer $KCONSOLE_AI_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "veo-3.1-lite-generate-preview", "prompt": "A waterfall in a forest", "n": 1}' \
  --max-time 600 > /tmp/veo_resp.json && \
python3 -c "
import json,base64
d = json.load(open('/tmp/veo_resp.json'))['data'][0]['b64_json']
with open('/data/workspace/output.mp4','wb') as f: f.write(base64.b64decode(d))
print('Saved: output.mp4')
"
```

### Image-to-Video (animate from first frame)
```bash
python3 -c "
import json, base64, subprocess, os
key = os.environ.get('KCONSOLE_AI_KEY', '')
with open('/data/workspace/first_frame.jpg','rb') as f: img_b64 = base64.b64encode(f.read()).decode()
with open('/tmp/veo_req.json','w') as f: json.dump({
  'model': 'veo-3.1-generate-preview',
  'prompt': 'The person starts walking forward',
  'image': img_b64, 'n': 1
}, f)
r = subprocess.run(['curl','-s','-X','POST','https://ai.koompi.cloud/v1/images/generations',
  '-H',f'Authorization: Bearer {key}','-H','Content-Type: application/json',
  '-d','@/tmp/veo_req.json'], capture_output=True, text=True, timeout=600)
data = json.loads(r.stdout)
vid = base64.b64decode(data['data'][0]['b64_json'])
with open('/data/workspace/output.mp4','wb') as f: f.write(vid)
print('Saved, size:', len(vid))
"
```

### Reference Image (preserve person/style, Veo 3.1 full only)
Use `reference_image` param alongside prompt (and optionally `image` for first frame).

---

## ⚠️ Limitations & Notes

- **Veo Lite:** Text prompt only. No reference image.
- **Veo Full (`veo-3.1-generate-preview`):** Supports `image` (first frame) + `reference_image` (style/face). Can combine both.
- **Gemini Pro Image:** Rejects reference images < 1024px — use `gemini-3.1-flash-image-preview` for small refs.
- **Large base64 payloads:** Always write to `/tmp/req.json` and use `curl -d @/tmp/req.json` to avoid shell arg limits.
- **Cambodian content:** Always specify "Khmer/Cambodian script only, NO Thai text" in prompts — never use Thai script for Khmer.
- **Long video timeout:** Use `--max-time 600` for cURL, or `timeout: 10 * 60 * 1000` for SDKs.
