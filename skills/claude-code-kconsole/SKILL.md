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

### Critical: workdir Must Be the Project Folder

**Always `cd` into the project directory before spawning Claude Code.** If you don't, it defaults to `/opt/openclaw/app` (read-only) and files won't persist.

```bash
cd /data/workspace/my-project && \
ANTHROPIC_AUTH_TOKEN=$KCONSOLE_AI_KEY \
ANTHROPIC_BASE_URL=https://ai.koompi.cloud \
IS_SANDBOX=1 \
API_TIMEOUT_MS=3000000 \
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
ANTHROPIC_HEADERS="x-backend: gemini" \
claude --model claude-sonnet-4-6 --permission-mode bypassPermissions --print "Your prompt here"
```

### One-shot (—print mode) — GLM (default)

```bash
cd /path/to/project && \
ANTHROPIC_AUTH_TOKEN=$KCONSOLE_AI_KEY \
ANTHROPIC_BASE_URL=https://ai.koompi.cloud \
IS_SANDBOX=1 \
API_TIMEOUT_MS=3000000 \
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
claude --model claude-sonnet-4-6 --permission-mode bypassPermissions --print "Your prompt here"
```

### One-shot (—print mode) — Gemini

```bash
cd /path/to/project && \
ANTHROPIC_AUTH_TOKEN=$KCONSOLE_AI_KEY \
ANTHROPIC_BASE_URL=https://ai.koompi.cloud \
IS_SANDBOX=1 \
API_TIMEOUT_MS=3000000 \
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
ANTHROPIC_HEADERS="x-backend: gemini" \
claude --model claude-sonnet-4-6 --permission-mode bypassPermissions --print "Your prompt here"
```

### Model Override

To force a specific Claude model tier (gateway translates):

```bash
claude --model claude-opus-4-6 --permission-mode bypassPermissions --print "..."
```

### Switch Backend Mid-Session

Use `ANTHROPIC_HEADERS` to toggle between GLM and Gemini without changing anything else:

```bash
# GLM backend (default)
ANTHROPIC_HEADERS="x-backend: glm" claude --permission-mode bypassPermissions --print "..."

# Gemini backend
ANTHROPIC_HEADERS="x-backend: gemini" claude --permission-mode bypassPermissions --print "..."
```

### Using exec Tool to Spawn (from OpenClaw)

When spawning from OpenClaw, use `pty: true` and set `workdir` to the project folder:

```
exec(command="claude --model claude-sonnet-4-6 --permission-mode bypassPermissions --print 'Your prompt'", workdir="/data/workspace/my-project", pty=true, timeout=300, background=true, env={
  ANTHROPIC_AUTH_TOKEN: process.env.KCONSOLE_AI_KEY,
  ANTHROPIC_BASE_URL: "https://ai.koompi.cloud",
  IS_SANDBOX: "1",
  API_TIMEOUT_MS: "3000000",
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: "1",
  ANTHROPIC_HEADERS: "x-backend: gemini"
})
```

## Notes

- **`--permission-mode bypassPermissions`** is the current flag (replaces the deprecated `--dangerously-skip-permissions`). Requires `IS_SANDBOX=1`.
- **`thought_signature` fix:** The gateway now injects Google's dummy `thought_signature` into `functionCall` parts, resolving the error Claude Code had when using tools with Gemini/GLM backends. This is handled server-side — no client config needed.
- **Gemini 3 models confirmed working** — both `gemini-3-flash-preview` (Sonnet) and `gemini-3.1-pro-preview` (Opus) work with full tool use.
- **GLM-5 confirmed working** — full tool use after the same `thought_signature` fix.
- **No Claude subscription needed** — the KConsole AI Gateway translates Claude Code's Anthropic API calls to GLM/Gemini server-side.

## Troubleshooting

See [references/troubleshooting.md](references/troubleshooting.md) for common issues.
