#!/usr/bin/env bash
set -e

STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspace}"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

echo "[entrypoint] state dir: $STATE_DIR"
echo "[entrypoint] workspace dir: $WORKSPACE_DIR"

# ── Setup Persistent Storage for Tools ────────────────────────────────────────

echo "[entrypoint] setting up persistent tool storage in /data..."
mkdir -p "$NPM_CONFIG_PREFIX/bin" "$UV_TOOL_DIR/bin" "$UV_CACHE_DIR" "$GOPATH/bin"

# Linuxbrew persistence and symlinking
BREW_PERSIST_DIR="/data/linuxbrew"
if [ ! -d "$BREW_PERSIST_DIR" ]; then
    echo "[entrypoint] Initializing persistent linuxbrew storage..."
    mkdir -p "$BREW_PERSIST_DIR"
    if [ -d "/home/linuxbrew/.linuxbrew" ] && [ ! -L "/home/linuxbrew/.linuxbrew" ]; then
        cp -a /home/linuxbrew/.linuxbrew/* "$BREW_PERSIST_DIR/" || true
        cp -a /home/linuxbrew/.linuxbrew/.[!.]* "$BREW_PERSIST_DIR/" 2>/dev/null || true
    fi
    chown -R linuxbrew:linuxbrew "$BREW_PERSIST_DIR"
fi

if [ ! -L "/home/linuxbrew/.linuxbrew" ]; then
    rm -rf /home/linuxbrew/.linuxbrew
    ln -s "$BREW_PERSIST_DIR" /home/linuxbrew/.linuxbrew
    chown -h linuxbrew:linuxbrew /home/linuxbrew/.linuxbrew
fi

# Ensure tool paths survive login-shell PATH reset (/etc/profile overwrites PATH)
cat << 'EOF' > /etc/profile.d/custom-tools.sh
export NPM_CONFIG_PREFIX="/data/npm-global"
export UV_TOOL_DIR="/data/uv/tools"
export UV_CACHE_DIR="/data/uv/cache"
export GOPATH="/data/go"
export PATH="/data/npm-global/bin:/data/uv/tools/bin:/data/go/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/go/bin:$PATH"
EOF
chmod +x /etc/profile.d/custom-tools.sh

# Create a wrapper for brew to drop root privileges
cat << 'EOF' > "$NPM_CONFIG_PREFIX/bin/brew"
#!/bin/bash
if [ "$(id -u)" = "0" ]; then
    export HOME=/home/linuxbrew
    export USER=linuxbrew
    exec runuser -u linuxbrew -- /home/linuxbrew/.linuxbrew/bin/brew "$@"
else
    exec /home/linuxbrew/.linuxbrew/bin/brew "$@"
fi
EOF
chmod +x "$NPM_CONFIG_PREFIX/bin/brew"

# ── Install extra apt packages (if requested) ────────────────────────────────
if [ -n "${OPENCLAW_DOCKER_APT_PACKAGES:-}" ]; then
  echo "[entrypoint] installing extra packages: $OPENCLAW_DOCKER_APT_PACKAGES"
  apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      $OPENCLAW_DOCKER_APT_PACKAGES \
    && rm -rf /var/lib/apt/lists/*
fi

# ── Auto-generate OPENCLAW_GATEWAY_TOKEN if not provided ─────────────────────
if [ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
  GENERATED_TOKEN=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 32)
  export OPENCLAW_GATEWAY_TOKEN="$GENERATED_TOKEN"
  echo "[entrypoint] Auto-generated OPENCLAW_GATEWAY_TOKEN (gateway is internal-only, not exposed)"
fi
GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN"

# ── KConsole Cloud key injection ─────────────────────────────────────────────
# Users provide KCONSOLE_AI_KEY for the AI Gateway and KCONSOLE_API_TOKEN for
# the platform. We propagate them to the env vars openclaw expects.
# This runs BEFORE the provider check so KCONSOLE_AI_KEY satisfies it.

# AI Gateway: map KCONSOLE_AI_KEY → AI_GATEWAY_API_KEY + AI_GATEWAY_BASE_URL
KCONSOLE_AI="${KCONSOLE_AI_KEY:-}"
if [ -n "$KCONSOLE_AI" ]; then
  export AI_GATEWAY_API_KEY="$KCONSOLE_AI"
  echo "[entrypoint] AI_GATEWAY_API_KEY set from KCONSOLE_AI_KEY"
fi
# Always point to KOOMPI AI gateway unless user overrides
if [ -z "${AI_GATEWAY_BASE_URL:-}" ]; then
  export AI_GATEWAY_BASE_URL="https://ai.koompi.cloud/v1"
fi

# ── Telegram: default to allowlist policy (no pairing required) ───────────────
# If user hasn't explicitly set a DM policy, default to allowlist.
# Combined with TELEGRAM_ALLOW_FROM, this avoids the pairing flow entirely.
if [ -z "${TELEGRAM_DM_POLICY:-}" ]; then
  export TELEGRAM_DM_POLICY="allowlist"
fi

# ── Require at least one AI provider API key env var ─────────────────────────
# Providers always read API keys from env vars, never from JSON config.
HAS_PROVIDER=0
for key in ANTHROPIC_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY GEMINI_API_KEY \
           XAI_API_KEY GROQ_API_KEY MISTRAL_API_KEY CEREBRAS_API_KEY \
           VENICE_API_KEY MOONSHOT_API_KEY KIMI_API_KEY MINIMAX_API_KEY \
           ZAI_API_KEY AI_GATEWAY_API_KEY OPENCODE_API_KEY OPENCODE_ZEN_API_KEY \
           SYNTHETIC_API_KEY COPILOT_GITHUB_TOKEN XIAOMI_API_KEY; do
  [ -n "${!key:-}" ] && HAS_PROVIDER=1 && break
done
[ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ] && HAS_PROVIDER=1
[ -n "${OLLAMA_BASE_URL:-}" ] && HAS_PROVIDER=1
if [ "$HAS_PROVIDER" -eq 0 ]; then
  echo "[entrypoint] ERROR: At least one AI provider API key env var is required."
  echo "[entrypoint] Providers read API keys from env vars, never from the JSON config."
  echo "[entrypoint] Set KCONSOLE_AI_KEY (KConsole AI Gateway), or one of:"
  echo "[entrypoint]   ANTHROPIC_API_KEY, OPENAI_API_KEY, OPENROUTER_API_KEY, GEMINI_API_KEY,"
  echo "[entrypoint]   XAI_API_KEY, GROQ_API_KEY, MISTRAL_API_KEY, AI_GATEWAY_API_KEY, ..."
  echo "[entrypoint] Or: AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY (Bedrock), OLLAMA_BASE_URL (local)"
  exit 1
fi

mkdir -p "$STATE_DIR" "$WORKSPACE_DIR"
mkdir -p "$STATE_DIR/agents/main/sessions" "$STATE_DIR/credentials"
chmod 700 "$STATE_DIR"

# ── Seed KOOMPI Cloud docs to workspace (first run only) ─────────────────────
# These teach OpenClaw how to use KConsole, KStorage, and the AI Gateway.
KOOMPI_DOCS_DIR="$WORKSPACE_DIR/koompi-docs"
if [ -d "/app/skills" ] && [ ! -d "$KOOMPI_DOCS_DIR" ]; then
  echo "[entrypoint] seeding KOOMPI Cloud docs to $KOOMPI_DOCS_DIR..."
  cp -r /app/skills "$KOOMPI_DOCS_DIR"
fi

# Create AGENTS.md in workspace root so OpenClaw knows about KOOMPI docs
AGENTS_MD="$WORKSPACE_DIR/AGENTS.md"
if [ ! -f "$AGENTS_MD" ]; then
  cat > "$AGENTS_MD" <<'AGENTSEOF'
# KOOMPI Cloud Instructions

This instance runs on KOOMPI Cloud. KOOMPI-specific documentation is in the `koompi-docs/` directory.
Read `koompi-docs/README.md` for the full skill index.

When the user asks you to:
- Deploy an app / manage services → read `koompi-docs/kconsole.md`
- Upload files / get CDN links → read `koompi-docs/kstorage.md`
- Generate images or videos via AI → read `koompi-docs/kconsole-ai.md`
- Read/create Excel, PDF, Word, PowerPoint, images, charts, QR codes, barcodes, or OCR → read `koompi-docs/koompi-office/SKILL.md`
- Post or manage social media (Facebook, Instagram, TikTok, X, etc.) → read `koompi-docs/social-media-automation/SKILL.md`
- Manage Riverbase/KOOMPI BIZ shop (products, orders, inventory, discounts, storefront) → read `koompi-docs/koompi-biz/SKILL.md`
- Use Claude Code for coding → read `koompi-docs/claude-code-kconsole/SKILL.md`
- Use Codex CLI for coding → read `koompi-docs/codex-cli-kconsole/SKILL.md`

The API keys are already available as env vars:
- `$KCONSOLE_API_TOKEN` — KConsole API
- `$KSTORAGE_API_KEY` — KStorage
- `$KCONSOLE_AI_KEY` / `$AI_GATEWAY_API_KEY` — AI Gateway (https://ai.koompi.cloud/v1)

Pre-installed tools: Chromium (headless browser), ffmpeg, Python with pandas/openpyxl/reportlab/Pillow/matplotlib, uv, Go, Node.js, Linuxbrew.

## Admin Commands (run in terminal)
- \`oc-allow <telegram_id>\` — Add a Telegram user to the persistent allowlist (survives restarts) and hot-reload config
- \`oc-reload\` — Re-run configure.js and hot-reload openclaw config (picks up any changes)
AGENTSEOF
  echo "[entrypoint] created AGENTS.md in workspace"
fi

# Export state/workspace dirs so openclaw CLI + configure.js see them
export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_WORKSPACE_DIR="$WORKSPACE_DIR"

# Set HOME so that ~/.openclaw resolves to $STATE_DIR directly.
# This avoids "multiple state directories" warnings from openclaw doctor
# (symlinks are detected as separate paths).
export HOME="${STATE_DIR%/.openclaw}"

# ── Run custom init script (if provided) ─────────────────────────────────────
INIT_SCRIPT="${OPENCLAW_DOCKER_INIT_SCRIPT:-}"
if [ -n "$INIT_SCRIPT" ]; then
  if [ ! -f "$INIT_SCRIPT" ]; then
    echo "[entrypoint] WARNING: init script not found: $INIT_SCRIPT"
  else
    # Auto-make executable — volume mounts often lose +x
    chmod +x "$INIT_SCRIPT" 2>/dev/null || true
    echo "[entrypoint] running init script: $INIT_SCRIPT"
    "$INIT_SCRIPT" || echo "[entrypoint] WARNING: init script exited with code $?"
  fi
fi

# ── Configure openclaw from env vars ─────────────────────────────────────────
# Clear jiti cache before configure — memory-lancedb-pro recommends this
# after plugin upgrades, and it's harmless on fresh starts.
rm -rf /tmp/jiti/ 2>/dev/null || true
echo "[entrypoint] running configure..."
node /app/scripts/configure.js
chmod 600 "$STATE_DIR/openclaw.json"

# ── Hot-reload helper ────────────────────────────────────────────────────────
# Install `oc-reload` command so the agent (or user via exec) can re-run
# configure.js at runtime.  OpenClaw watches openclaw.json for changes,
# so this picks up new Telegram users, model changes, etc.
# without restarting the container.
cat > /usr/local/bin/oc-reload <<'RELOADEOF'
#!/bin/bash
echo "[oc-reload] re-running configure.js..."
node /app/scripts/configure.js
chmod 600 "${OPENCLAW_STATE_DIR:-/data/.openclaw}/openclaw.json"
echo "[oc-reload] done — openclaw will pick up changes automatically"
RELOADEOF
chmod +x /usr/local/bin/oc-reload

# Install `oc-allow` command to add Telegram users to the persistent allowlist.
# Usage: oc-allow 123456789           (add one user)
#        oc-allow 123456789 987654321 (add multiple)
# The file /data/config/telegram-allow.txt survives container restarts.
cat > /usr/local/bin/oc-allow <<'ALLOWEOF'
#!/bin/bash
ALLOW_FILE="/data/config/telegram-allow.txt"
mkdir -p /data/config
touch "$ALLOW_FILE"
if [ $# -eq 0 ]; then
  echo "Usage: oc-allow <telegram_user_id> [<id2> ...]"
  echo "Current allowlist:"
  echo "  env: ${TELEGRAM_ALLOW_FROM:-<not set>}"
  echo "  file: $(cat "$ALLOW_FILE" 2>/dev/null || echo '<empty>')"
  exit 0
fi
for id in "$@"; do
  if ! grep -qx "$id" "$ALLOW_FILE" 2>/dev/null; then
    echo "$id" >> "$ALLOW_FILE"
    echo "[oc-allow] added $id"
  else
    echo "[oc-allow] $id already in allowlist"
  fi
done
echo "[oc-allow] reloading config..."
oc-reload
ALLOWEOF
chmod +x /usr/local/bin/oc-allow

# Ensure /data/config exists for the persistent allowlist
mkdir -p /data/config

# ── Auto-fix doctor suggestions (e.g. enable configured channels) ─────────
echo "[entrypoint] running openclaw doctor --fix..."
cd /opt/openclaw/app
openclaw doctor --fix 2>&1 || true

# ── Read hooks path from generated config (if hooks enabled) ─────────────────
HOOKS_PATH=""
HOOKS_PATH=$(node -e "
  try {
    const c = JSON.parse(require('fs').readFileSync('$STATE_DIR/openclaw.json','utf8'));
    if (c.hooks && c.hooks.enabled) process.stdout.write(c.hooks.path || '/hooks');
  } catch {}
" 2>/dev/null || true)
if [ -n "$HOOKS_PATH" ]; then
  echo "[entrypoint] hooks enabled, path: $HOOKS_PATH (will bypass HTTP auth)"
fi

# ── Generate nginx config ────────────────────────────────────────────────────
AUTH_PASSWORD="${AUTH_PASSWORD:-}"
AUTH_USERNAME="${AUTH_USERNAME:-admin}"
NGINX_CONF="/etc/nginx/conf.d/openclaw.conf"

AUTH_BLOCK=""
if [ -n "$AUTH_PASSWORD" ]; then
  echo "[entrypoint] setting up nginx basic auth (user: $AUTH_USERNAME)"
  htpasswd -bc /etc/nginx/.htpasswd "$AUTH_USERNAME" "$AUTH_PASSWORD" 2>/dev/null
  AUTH_BLOCK='auth_basic "Openclaw";
        auth_basic_user_file /etc/nginx/.htpasswd;'
else
  echo "[entrypoint] no AUTH_PASSWORD set, nginx will not require authentication"
fi

# Build hooks location block (skips HTTP basic auth, openclaw validates hook token)
HOOKS_LOCATION_BLOCK=""
if [ -n "$HOOKS_PATH" ]; then
  HOOKS_LOCATION_BLOCK="location ${HOOKS_PATH} {
        proxy_pass http://127.0.0.1:${GATEWAY_PORT};
        proxy_set_header Authorization \\\$http_authorization;

        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP 127.0.0.1;
        proxy_set_header X-Forwarded-For 127.0.0.1;
        proxy_set_header X-Forwarded-Proto \\\$scheme;

        proxy_http_version 1.1;

        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;

        error_page 502 503 504 /starting.html;
    }"
fi

# Build browser sidecar location block (only when ENABLE_BROWSER_SIDECAR is set)
# Without this guard nginx fails to start on standalone deployments because the
# "browser" hostname doesn't resolve (it's only available in docker-compose).
BROWSER_LOCATION_BLOCK=""
BROWSER_SIDECAR_HOST="${BROWSER_SIDECAR_HOST:-browser}"
BROWSER_SIDECAR_PORT="${BROWSER_SIDECAR_PORT:-3000}"
if [ -n "${ENABLE_BROWSER_SIDECAR:-}" ]; then
  echo "[entrypoint] browser sidecar enabled at http://${BROWSER_SIDECAR_HOST}:${BROWSER_SIDECAR_PORT}"
  BROWSER_LOCATION_BLOCK="# Browser sidecar proxy (VNC web UI)
    location /browser/ {
        ${AUTH_BLOCK}

        proxy_pass http://${BROWSER_SIDECAR_HOST}:${BROWSER_SIDECAR_PORT}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP 127.0.0.1;
        proxy_set_header X-Forwarded-For 127.0.0.1;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;

        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }"
fi

# ── Write startup page for 502/503/504 while gateway boots ───────────────────
mkdir -p /usr/share/nginx/html
cat > /usr/share/nginx/html/starting.html <<'STARTPAGE'
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Openclaw - Starting</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: ui-sans-serif, system-ui, -apple-system, sans-serif; background: #0a0a0a; color: #e5e5e5; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
    .card { text-align: center; max-width: 480px; padding: 2.5rem; }
    h1 { font-size: 1.5rem; font-weight: 600; margin-bottom: 1rem; }
    p { color: #a3a3a3; line-height: 1.6; margin-bottom: 1.5rem; }
    .spinner { width: 32px; height: 32px; border: 3px solid #333; border-top-color: #e5e5e5; border-radius: 50%; animation: spin 0.8s linear infinite; margin: 0 auto 1.5rem; }
    @keyframes spin { to { transform: rotate(360deg); } }
    .retry { color: #737373; font-size: 0.85rem; }
  </style>
</head>
<body>
  <div class="card">
    <div class="spinner"></div>
    <h1>Openclaw is starting up</h1>
    <p>The gateway is initializing.</p>
    <p>This usually takes a few minutes.</p>
    <p class="retry">This page will auto-refresh.</p>
  </div>
  <script>setTimeout(function(){ location.reload(); }, 3000);</script>
</body>
</html>
STARTPAGE

cat > "$NGINX_CONF" <<NGINXEOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

map \$arg_token \$ocw_has_token {
    ''      0;
    default 1;
}

map "\$ocw_has_token:\$args" \$ocw_proxy_args {
    ~^1:    \$args;
    ~^0:.+  "\$args&token=${GATEWAY_TOKEN}";
    default "token=${GATEWAY_TOKEN}";
}

server {
    listen ${PORT:-8080} default_server;
    server_name _;
    absolute_redirect off;

    location = /healthz {
        access_log off;
        proxy_pass http://127.0.0.1:${GATEWAY_PORT}/;
        proxy_set_header Host \$host;
        proxy_connect_timeout 2s;
        error_page 502 503 504 = @healthz_fallback;
    }

    location @healthz_fallback {
        return 200 '{"ok":true,"gateway":"starting"}';
        default_type application/json;
    }

    ${HOOKS_LOCATION_BLOCK}

    location / {
        ${AUTH_BLOCK}

        proxy_pass http://127.0.0.1:${GATEWAY_PORT}\$uri?\$ocw_proxy_args;
        proxy_set_header Authorization "Bearer ${GATEWAY_TOKEN}";

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP 127.0.0.1;
        proxy_set_header X-Forwarded-For 127.0.0.1;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;

        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;

        error_page 502 503 504 /starting.html;
    }

    location = /starting.html {
        root /usr/share/nginx/html;
        internal;
    }

    ${BROWSER_LOCATION_BLOCK}
}
NGINXEOF

# ── Start nginx ──────────────────────────────────────────────────────────────
echo "[entrypoint] starting nginx on port ${PORT:-8080}..."
nginx

# ── Startup optimizations ──────────────────────────────────────────────────
# Ensure Node.js compile cache directory exists for faster restarts.
# NODE_COMPILE_CACHE (set in Dockerfile) persists V8 bytecode across restarts,
# making repeated CLI/gateway startup significantly faster.
mkdir -p "${NODE_COMPILE_CACHE:-/var/tmp/openclaw-compile-cache}"

# ── Clean up stale lock files ────────────────────────────────────────────────
rm -f /tmp/openclaw-gateway.lock 2>/dev/null || true
rm -f "$STATE_DIR/gateway.lock" 2>/dev/null || true

# ── Fix device scopes in paired.json ────────────────────────────────────────
# When the Telegram channel auto-pairs a device it only gets "operator.approvals"
# scope.  The agent's internal tools (cron, browser, gateway) need "operator.read"
# and "operator.write".  This fixer widens existing devices at startup (for
# container restarts) and runs in the background to catch first-run pairing.
PAIR_FILE="$STATE_DIR/devices/paired.json"

fix_device_scopes() {
  [ -f "$PAIR_FILE" ] || return 1
  python3 -c "
import json, sys, os
pf = '$PAIR_FILE'
with open(pf) as f:
    data = json.load(f)
changed = False
needed = ['operator.read', 'operator.write']
for dev in data.values():
    if not isinstance(dev, dict):
        continue
    scopes = dev.get('scopes', [])
    approved = dev.get('approvedScopes', [])
    for s in needed:
        if s not in scopes:
            scopes.append(s)
            changed = True
        if s not in approved:
            approved.append(s)
            changed = True
    dev['scopes'] = scopes
    dev['approvedScopes'] = approved
    for tok in dev.get('tokens', {}).values():
        if not isinstance(tok, dict):
            continue
        ts = tok.get('scopes', [])
        for s in needed:
            if s not in ts:
                ts.append(s)
                changed = True
        tok['scopes'] = ts
if changed:
    with open(pf, 'w') as f:
        json.dump(data, f, indent=2)
    print('[scope-fix] Device scopes updated — added operator.read + operator.write')
" 2>/dev/null
}

# Fix now (handles container restart with persisted paired.json)
fix_device_scopes || true

# Background watcher: fix scopes when paired.json appears after first Telegram pairing
(
  while true; do
    sleep 30
    fix_device_scopes 2>/dev/null && break
  done
) &

# ── Start openclaw gateway ───────────────────────────────────────────────────
echo "[entrypoint] starting openclaw gateway on port $GATEWAY_PORT..."

# cwd must be the app root so the gateway finds dist/control-ui/ assets
# "gateway run" = foreground mode; all config comes from openclaw.json
cd /opt/openclaw/app
exec openclaw gateway run
