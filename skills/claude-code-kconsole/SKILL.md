---
name: claude-code-kconsole
description: Configure and spawn Claude Code CLI routed through KConsole AI Gateway (ai.koompi.cloud) to use GLM or Gemini models instead of Anthropic's. Use when the user asks to run Claude Code, use Claude Code for coding tasks, or when Claude Code needs to be configured for a non-Anthropic backend. Covers setup, env vars, model mapping, settings.json, and the spawning command pattern.
---

# Claude Code + KConsole AI Gateway

Route Claude Code through KConsole AI Gateway to use GLM/Gemini models. The gateway accepts Claude model names and translates them server-side to GLM/Gemini.

## How It Works

Claude Code validates model names locally (must be Claude names). The gateway's `mapAnthropicModel()` translates them server-side. You never set GLM model names in Claude Code — always use Claude names.

## Required Environment Variables

| Variable | Value | Notes |
|---|---|---|
| `ANTHROPIC_AUTH_TOKEN` | KConsole API key | Use `AUTH_TOKEN`, not `API_KEY` |
| `ANTHROPIC_BASE_URL` | `https://ai.koompi.cloud` | **NO `/v1` suffix** — Claude Code appends `/v1/messages` itself |
| `IS_SANDBOX` | `1` | Required when running inside a container |
| `API_TIMEOUT_MS` | `3000000` | 50 min timeout for long tasks |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | `1` | Disable telemetry/analytics |

**Critical:** `ANTHROPIC_BASE_URL` must be `https://ai.koompi.cloud` — NOT `https://ai.koompi.cloud/v1`. Claude Code appends `/v1/messages` itself. With `/v1` in the base URL, it hits `/v1/v1/messages` and fails.

## What NOT to Do

- ❌ Do NOT set `ANTHROPIC_DEFAULT_SONNET_MODEL=glm-5` — Claude Code validates the name locally and rejects non-Claude names
- ❌ Do NOT set `ANTHROPIC_MODEL=glm-5` — same reason
- ❌ Do NOT pass `--model glm-5` — same reason
- ❌ Do NOT use `ANTHROPIC_API_KEY` — use `ANTHROPIC_AUTH_TOKEN`
- ❌ Do NOT append `/v1` to `ANTHROPIC_BASE_URL`

## Backend Switching

The gateway supports two backend providers. Switch via `ANTHROPIC_HEADERS`:

```bash
ANTHROPIC_HEADERS="x-backend: glm"     # Default — GLM models
ANTHROPIC_HEADERS="x-backend: gemini"  # Gemini models
```

| Backend | Models | Best For |
|---|---|---|
| `glm` (default) | GLM-5, GLM-5.1, GLM-4.7-flash | General coding, fast responses |
| `gemini` | Gemini 3 Flash, Gemini 3.1 Pro | Complex reasoning, long context |

## Model Mapping (Server-Side)

The gateway handles all translation. These are the defaults:

| Claude Name | GLM Backend | Gemini Backend |
|---|---|---|
| `claude-sonnet-4-6` | `glm-5` | `gemini-3-flash-preview` |
| `claude-opus-4-6` | `glm-5.1` | `gemini-3.1-pro-preview` |
| `claude-haiku-3-5-*` | `glm-4.7-flash` | `gemini-2.5-flash` |
| Any unknown `claude-*` | `glm-5` (fallback) | `gemini-3-flash-preview` |

Override per-project via `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL` — but only with **Claude model names**, not GLM/Gemini names.

## Settings File

Create `/root/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": ["Bash(*)", "Read(*)", "Write(*)", "Edit(*)"],
    "deny": []
  },
  "env": {
    "IS_SANDBOX": "1",
    "ANTHROPIC_AUTH_TOKEN": "<KCONSOLE_API_KEY>",
    "ANTHROPIC_BASE_URL": "https://ai.koompi.cloud",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
}
```

The `env` block applies to **interactive sessions**. For `--print` mode, pass env vars explicitly (see below).

## Spawning Claude Code

### One-shot (—print mode) — GLM (default)

```bash
ANTHROPIC_AUTH_TOKEN=$KCONSOLE_AI_KEY \
ANTHROPIC_BASE_URL=https://ai.koompi.cloud \
IS_SANDBOX=1 \
API_TIMEOUT_MS=3000000 \
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
claude --print "Your prompt here"
```

### One-shot (—print mode) — Gemini

```bash
ANTHROPIC_AUTH_TOKEN=$KCONSOLE_AI_KEY \
ANTHROPIC_BASE_URL=https://ai.koompi.cloud \
IS_SANDBOX=1 \
API_TIMEOUT_MS=3000000 \
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
ANTHROPIC_HEADERS="x-backend: gemini" \
claude --print "Your prompt here"
```

For long tasks, add `--dangerously-skip-permissions` (requires `IS_SANDBOX=1`):

```bash
ANTHROPIC_AUTH_TOKEN=$KCONSOLE_AI_KEY \
ANTHROPIC_BASE_URL=https://ai.koompi.cloud \
IS_SANDBOX=1 \
API_TIMEOUT_MS=3000000 \
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
ANTHROPIC_HEADERS="x-backend: gemini" \
claude --dangerously-skip-permissions --print "Your prompt here"
```

### Interactive (—dangerously-skip-permissions)

```bash
ANTHROPIC_AUTH_TOKEN=$KCONSOLE_AI_KEY \
ANTHROPIC_BASE_URL=https://ai.koompi.cloud \
IS_SANDBOX=1 \
claude --dangerously-skip-permissions
```

### Model Override

To force a specific Claude model tier (gateway translates):

```bash
claude --model claude-opus-4-6 --print "..."
```

### Switch Backend Mid-Session

Use `ANTHROPIC_HEADERS` to toggle between GLM and Gemini without changing anything else:

```bash
# GLM backend (default)
ANTHROPIC_HEADERS="x-backend: glm" claude --print "..."

# Gemini backend
ANTHROPIC_HEADERS="x-backend: gemini" claude --print "..."
```

## Troubleshooting

See [references/troubleshooting.md](references/troubleshooting.md) for common issues.
