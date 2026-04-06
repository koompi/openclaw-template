# Codex CLI + KConsole AI Gateway

## Quick Reference

### Commands

| Command | Description |
|--------|-------------|
| `codex` | Start interactive session |
| `codex exec " | Run one-shot command |
| `codex exec --skip-git-repo-check " | Run in non-git directory |
| `codex review` | Run code review |
| `codex resume` | Resume previous session |
| `codex --help` | Show help |

| `codex --version` | Show version |

### Environment Variables

| Variable | Required | Default |
|---------|----------|---------|
| `KCONSOLE_API_KEY` | Yes | - |

### Config file location
`~/.codex/config.toml`

### Example usage

```bash
# Set API key
export KCONSOLE_API_KEY="kpi_your_key_here"

# Run codex in a project
cd /path/to/your/project
codex exec "Create a hello world Python script"

# Or with Gemini
codex exec --skip-git-repo-check \
  -c model_provider=kconsole-gemini \
  -c model=gemini-3-flash-preview \
  "Analyze the code"
```

## Switching Providers

```bash
# GLM (default)
model_provider = "kconsole"
model = "glm-5"

# Gemini
model_provider = "kconsole-gemini"
model = "gemini-3-flash-preview"
```

Or via config file:
```toml
model_provider = "kconsole-gemini"
model = "gemini-3-flash-preview"
```

## Common issues

| Issue | Solution |
|-------|----------|
| 401 Unauthorized | Check API key is set and valid |
| Missing env var | Export KCONSOLE_API_KEY |
| Not trusted directory | Use --skip-git-repo-check |
| Tools not working | Gateway needs thought_signature support |

## Test connection

```bash
# Test gateway
curl -s https://ai.koompi.cloud/v1/responses \
  -H "Authorization: Bearer $KCONSOLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"glm-5","input":"test"}'
```
