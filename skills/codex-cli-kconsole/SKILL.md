---
name: codex-cli-kconsole
description: Configure and spawn Codex CLI routed through KConsole AI Gateway (ai.koompi.cloud) to use GLM or Gemini models. Use when the user asks to run Codex, use Codex for coding tasks, or when Codex needs to be configured for a non-OpenAI backend.
---

# Codex CLI + KConsole AI Gateway

Route Codex CLI through KConsole AI Gateway to use GLM/Gemini models with full tool support.

## ⚠️ Docker Sandbox — No ACP Harness Needed

**You are already running inside a Docker container.** The entire container IS the sandbox.

- **Do NOT use `acp harness`** or any sandbox wrapper — there is no nested sandbox, no Seatbelt, no Landlock.
- **Spawn Codex directly** with `codex exec` or `codex` — it has full filesystem and network access inside the container.
- **`--full-auto` is safe** — the container is the isolation boundary. There is no risk of escaping.
- **No approval prompts** — use `--full-auto` to skip all tool approval since the container is already sandboxed.
- **`--skip-git-repo-check`** — always use this flag since the workspace is not a git repo by default.

### Spawn Codex as a Background Agent

```bash
# One-shot task (blocks until done)
codex exec --full-auto --skip-git-repo-check "Your coding task here"

# Quick task with specific model
codex exec --full-auto --skip-git-repo-check \
  -c model_provider=kconsole-gemini \
  -c model=gemini-3-flash-preview \
  "Analyze and refactor this code"
```

## Overview

Codex CLI (codex) is OpenAI's command-line coding assistant. By default, it requires an OpenAI API key and subscription. This skill enables Codex to work with KConsole AI Gateway, allowing you to use GLM or Gemini models instead of OpenAI's models.

**Key Features:**
- Use GLM-5, GLM-5.1, GLM-4.7-flash models
- Use Gemini 3 Flash, Gemini 3.1 Pro models
- Full tool support (file operations, shell commands, code execution)
- No OpenAI subscription required

## Prerequisites

Before configuring Codex, ensure:

1. **KConsole AI Gateway is running** at `https://ai.koompi.cloud`
2. **You have a valid KConsole API key** (format: `kpi_...`)
3. **Codex CLI is installed** (if not, see installation section below)

## Quick Start

### 1. Set API Key

```bash
export KCONSOLE_API_KEY="kpi_your_api_key_here"
```

Add to `~/.bashrc` for persistence:
```bash
echo 'export KCONSOLE_API_KEY="kpi_your_api_key_here"' >> ~/.bashrc
source ~/.bashrc
```

### 2. Configure Codex

Create or edit `~/.codex/config.toml`:

```toml
model_provider = "kconsole"
model = "glm-5"

[model_providers.kconsole]
name = "KConsole AI Gateway (GLM)"
base_url = "https://ai.koompi.cloud/v1"
env_key = "KCONSOLE_API_KEY"
wire_api = "responses"
compatibility_mode = "openai-chat"

[model_providers.kconsole-gemini]
name = "KConsole AI Gateway (Gemini)"
base_url = "https://ai.koompi.cloud/v1"
env_key = "KCONSOLE_API_KEY"
wire_api = "responses"
compatibility_mode = "openai-chat"
env_http_headers = { X_BACKEND = "gemini" }

[[model_metadata]]
model_slug = "glm-5"
context_window = 200000
supports_reasoning = true
thinking_mode = true

[[model_metadata]]
model_slug = "glm-5.1"
context_window = 200000
supports_reasoning = true
thinking_mode = true

[[model_metadata]]
model_slug = "gemini-3-flash-preview"
context_window = 1000000
supports_reasoning = true
thinking_mode = true

[[model_metadata]]
model_slug = "gemini-3.1-pro-preview"
context_window = 1000000
supports_reasoning = true
thinking_mode = true
```

### 3. Run Codex

```bash
# Using GLM (default) — full-auto is safe inside Docker
codex exec --full-auto --skip-git-repo-check "Your prompt here"

# Using Gemini
codex exec --full-auto --skip-git-repo-check -c model_provider=kconsole-gemini -c model=gemini-3-flash-preview "Your prompt"
```

## Installation

### Install Codex CLI

If Codex is not installed, install it with:

```bash
# Using npm
npm install -g @openai/codex

# Or using the official installer
curl -fsSL https://raw.githubusercontent.com/openai/codex/main/install.sh | bash
```

Verify installation:
```bash
codex --version
```

### Install from Source (Alternative)

```bash
git clone https://github.com/openai/codex.git
cd codex
cargo build --release
sudo cp target/release/codex /usr/local/bin/
```

## Configuration Details

### Provider Configuration

| Field | Description | GLM | Gemini |
|-------|-------------|-----|--------|
| `model_provider` | Provider name | `kconsole` | `kconsole-gemini` |
| `base_url` | Gateway URL | `https://ai.koompi.cloud/v1` | `https://ai.koompi.cloud/v1` |
| `env_key` | API key env var | `KCONSOLE_API_KEY` | `KCONSOLE_API_KEY` |
| `wire_api` | API protocol | `responses` | `responses` |
| `compatibility_mode` | Compatibility | `openai-chat` | `openai-chat` |
| `env_http_headers` | Custom headers | (none) | `{ X_BACKEND = "gemini" }` |

### Available Models

#### GLM Backend (Default)
- `glm-5` - General coding, fast responses, reasoning support
- `glm-5.1` - Advanced reasoning, complex tasks
- `glm-4.7-flash` - Fast, lightweight operations

#### Gemini Backend
- `gemini-3-flash-preview` - Fast, good for most tasks
- `gemini-3.1-pro-preview` - Complex reasoning, long context
- `gemini-2.5-pro` - Stable, production-ready
- `gemini-2.5-flash` - Balanced speed and quality

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `KCONSOLE_API_KEY` | Yes | Your KConsole API key (format: `kpi_...`) |

## Usage Examples

### Interactive Mode

```bash
# Start interactive session with GLM (full-auto, no approval prompts)
codex --full-auto

# Start with Gemini
codex --full-auto -c model_provider=kconsole-gemini -c model=gemini-3-flash-preview
```

### One-shot Commands

```bash
# Simple question
codex exec --full-auto --skip-git-repo-check "What is 2+2?"

# File operations
codex exec --full-auto --skip-git-repo-check "Read the README.md file"

# Code generation
codex exec --full-auto --skip-git-repo-check "Create a Python script that prints fibonacci sequence"

# Using Gemini for complex tasks
codex exec --full-auto --skip-git-repo-check \
  -c model_provider=kconsole-gemini \
  -c model=gemini-3.1-pro-preview \
  "Analyze this codebase and suggest improvements"
```

### In Trusted Projects

For projects in trusted directories, omit `--skip-git-repo-check`:

```toml
# Add to ~/.codex/config.toml
[projects."/path/to/your/project"]
trust_level = "trusted"
```

```bash
cd /path/to/your/project
codex exec "Your prompt"
```

## Switching Backends

### GLM to Gemini Mid-session

```bash
# Temporary switch for one command
codex exec --full-auto --skip-git-repo-check \
  -c model_provider=kconsole-gemini \
  -c model=gemini-3-flash-preview \
  "Your prompt"
```

### Permanent Switch

Edit `~/.codex/config.toml`:
```toml
model_provider = "kconsole-gemini"
model = "gemini-3-flash-preview"
```

## Troubleshooting

### "Missing environment variable: KCONSOLE_API_KEY"

**Solution:**
```bash
export KCONSOLE_API_KEY="kpi_your_key_here"
# Or add to ~/.bashrc
echo 'export KCONSOLE_API_KEY="kpi_your_key_here"' >> ~/.bashrc
source ~/.bashrc
```

### "Model 'X' is not supported"

**Cause:** Invalid model name for the selected backend.

**Solution:**
- GLM backend: Use `glm-5`, `glm-5.1`, `glm-4.7-flash`
- Gemini backend: Use `gemini-3-flash-preview`, `gemini-3.1-pro-preview`

Check available models:
```bash
curl -s https://ai.koompi.cloud/v1/models \
  -H "Authorization: Bearer $KCONSOLE_API_KEY" \
  -H "x-backend: gemini" | jq -r '.data[].id'
```

### "Not inside a trusted directory"

**Solution:**
- Add project to trusted list in config, OR
- Use `--skip-git-repo-check` flag

### "401 Unauthorized"

**Cause:** Invalid or missing API key.

**Solution:**
1. Verify API key format: `kpi_...`
2. Check `KCONSOLE_API_KEY` is set: `echo $KCONSOLE_API_KEY`
3. Test gateway directly:
   ```bash
   curl -s https://ai.koompi.cloud/v1/responses \
     -H "Authorization: Bearer $KCONSOLE_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"model":"glm-5","input":"hi"}'
   ```

### Tool Calls Not Working

**Symptoms:** Commands execute but results aren't processed correctly.

**Cause:** Gateway missing `thought_signature` injection for Gemini.

**Solution:** Ensure KConsole gateway is updated to inject `thought_signature` for Gemini backend tool calls.

### Sandbox Permission Errors

**Symptoms:** "read-only sandbox" or "permission denied" or "acp harness" errors

**Solution:** You are inside a Docker container — there is NO nested sandbox. Always use `--full-auto` which bypasses all sandbox/approval checks:
```bash
codex exec --full-auto --skip-git-repo-check "Your prompt"
```
Do NOT use `acp harness`, Seatbelt, or Landlock wrappers — they don't exist in this environment.

## Gateway Requirements

KConsole AI Gateway must support:

1. **`/v1/responses` endpoint** - Codex 0.118.0+ requires this
2. **Bearer token authentication** - Via `Authorization: Bearer <key>`
3. **Tool call format translation** - Convert between Responses API and backend format
4. **`thought_signature` injection** - For Gemini backend (required for tool calls)
5. **Null tool filtering** - Filter out tools with `function: null`

## API Compatibility

### Responses API Format

Codex sends requests in OpenAI Responses API format:
```json
{
  "model": "glm-5",
  "input": "user message",
  "tools": [...],
  "tool_choice": "auto"
}
```

Expected response format:
```json
{
  "id": "response_id",
  "object": "response",
  "created_at": 1234567890,
  "status": "completed",
  "model": "glm-5",
  "output": [
    {
      "id": "msg_xxx",
      "type": "message",
      "role": "assistant",
      "content": [
        {
          "type": "output_text",
          "text": "Response text"
        }
      ]
    }
  ],
  "usage": {
    "input_tokens": 10,
    "output_tokens": 20,
    "total_tokens": 30
  }
}
```

## Best Practices

1. **Use GLM for speed** - Faster responses for simple tasks
2. **Use Gemini for complexity** - Better reasoning for complex code analysis
3. **Set trust levels** - Add frequent projects to trusted list
4. **Persist API key** - Add to `~/.bashrc` for convenience
5. **Version control** - Keep backup of working config

## Related Resources

- [KConsole AI Gateway Documentation](../references/kconsole-gateway.md)
- [Codex CLI Official Docs](https://github.com/openai/codex)
- [OpenAI Responses API Spec](https://platform.openai.com/docs/api-reference/responses)
- [Troubleshooting Guide](../references/troubleshooting.md)

## Changelog

### 2026-04-05
- Initial skill creation
- Tested with GLM-5 and Gemini 3 Flash Preview
- Confirmed full tool support for both backends
- Added configuration for codex 0.118.0 with Responses API
