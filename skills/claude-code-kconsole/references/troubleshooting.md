# Troubleshooting

## "There's an issue with the selected model (X). It may not exist or you may not have access to it."

**Cause:** Claude Code validates model names locally against Anthropic's known model list.

**Fix:**
- Use Claude model names only (`claude-sonnet-4-6`, not `glm-5`)
- Remove any `ANTHROPIC_DEFAULT_*_MODEL` env vars set to non-Claude names
- Remove `--model glm-5` flag
- Let the gateway handle translation server-side

## Empty content response (content: [])

**Cause:** GLM-5 puts output into `reasoning_content` when `max_tokens` is too low, leaving `content` empty.

**Fix:** Gateway should enforce minimum `max_tokens` (≥1024) for GLM models, or map `reasoning_content` to `content` as fallback. If you control the gateway, check both fixes are applied in `anthropic-proxy.ts`.

## Claude Code hangs or times out

**Cause:** Default timeout is too low for complex tasks.

**Fix:** Set `API_TIMEOUT_MS=3000000` (50 minutes).

## Connection refused / 404 errors

**Cause:** Wrong `ANTHROPIC_BASE_URL`.

**Fix:** Must be `https://ai.koompi.cloud` — no `/v1` suffix. Claude Code appends `/v1/messages` itself.

## Claude Code works once then fails

**Cause:** Likely an intermittent issue, not a config problem. Check:
1. Gateway is returning consistent responses (test with curl)
2. No rate limiting hitting the API key
3. `ANTHROPIC_AUTH_TOKEN` (not `ANTHROPIC_API_KEY`) is set consistently

## Gemini models not working

**Cause:** Same as GLM — Claude Code only accepts Claude model names.

**Fix:** The gateway can route any Claude model name to Gemini. Ask the gateway admin to update `mapAnthropicModel()` to point `claude-sonnet-4-6` → a Gemini model instead of GLM.

## Verification Commands

```bash
# Test gateway accepts Claude model names:
curl -s https://ai.koompi.cloud/v1/messages \
  -H "Authorization: Bearer $KCONSOLE_AI_KEY" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"claude-sonnet-4-6","max_tokens":100,"messages":[{"role":"user","content":"hi"}]}'

# Test Claude Code end-to-end:
ANTHROPIC_AUTH_TOKEN=$KCONSOLE_AI_KEY \
ANTHROPIC_BASE_URL=https://ai.koompi.cloud \
IS_SANDBOX=1 \
claude --print "Reply with just: alive ✅"
```
