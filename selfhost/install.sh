#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# OpenClaw Self-Hosted Installer
# Provisions backing resources from KConsole (AI gateway, storage, tokens)
# then deploys OpenClaw on the user's machine via Docker Compose.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# When piped (curl | bash), stdin is the pipe — read from /dev/tty for prompts
if [ -t 0 ]; then
  TTY_IN="/dev/stdin"
else
  TTY_IN="/dev/tty"
fi

# ── Defaults ─────────────────────────────────────────────────────────────────
KCONSOLE_API="${KCONSOLE_API:-https://api-kconsole.koompi.cloud}"
KCONSOLE_FRONTEND="${KCONSOLE_FRONTEND:-https://kconsole.koompi.cloud}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/openclaw}"
PORT="${PORT:-8080}"

# Colors (always enable — output goes to terminal even when stdin is piped)
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Helpers ──────────────────────────────────────────────────────────────────
info()  { printf "${BLUE}ℹ${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}✔${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}⚠${NC}  %s\n" "$*"; }
fail()  { printf "${RED}✖${NC}  %s\n" "$*" >&2; exit 1; }
ask()   { printf "${CYAN}?${NC}  %s " "$1"; }

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1 found"
    return 0
  else
    return 1
  fi
}

# ── Banner ───────────────────────────────────────────────────────────────────
echo ""
printf "${BOLD}${CYAN}"
cat << 'EOF'
  _  _____  ____  __  __ ____ ___  ____  _
 | |/ / _ \/ __ \|  \/  |  _ \_ _|/ ___|| | __ ___      __
 | ' / | | | |  | | |\/| | |_) | || |   | |/ _` \ \ /\ / /
 | . \ |_| | |__| | |  | |  __/| || |___| | (_| |\ V  V /
 |_|\_\___/ \____/|_|  |_|_|  |___|\____|_|\__,_| \_/\_/
EOF
printf "${NC}"
echo ""
printf "${BOLD}  Self-Hosted Installer${NC}  •  Powered by KConsole\n"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# 1. Preflight checks
# ══════════════════════════════════════════════════════════════════════════════
info "Running preflight checks..."
echo ""

# Docker
if ! check_cmd docker; then
  fail "Docker is not installed. Install it from https://docs.docker.com/get-docker/"
fi
if ! docker info >/dev/null 2>&1; then
  fail "Docker daemon is not running. Start Docker and try again."
fi

# Docker Compose (v2 plugin or standalone)
if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
  ok "Docker Compose (plugin) found"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
  ok "Docker Compose (standalone) found"
else
  fail "Docker Compose is not installed. Install it from https://docs.docker.com/compose/install/"
fi

# curl or wget
if check_cmd curl; then
  HTTP_CLIENT="curl"
elif check_cmd wget; then
  HTTP_CLIENT="wget"
else
  fail "Neither curl nor wget found. Install one and try again."
fi

# Port availability
if command -v ss >/dev/null 2>&1; then
  if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
    fail "Port ${PORT} is already in use. Set PORT=<number> to use a different port."
  fi
elif command -v lsof >/dev/null 2>&1; then
  if lsof -i ":${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
    fail "Port ${PORT} is already in use. Set PORT=<number> to use a different port."
  fi
fi
ok "Port ${PORT} is available"

# RAM (recommend >= 4GB)
if [ -f /proc/meminfo ]; then
  total_kb=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
  total_gb=$((total_kb / 1024 / 1024))
  if [ "$total_gb" -lt 4 ]; then
    warn "System has ${total_gb}GB RAM. 4GB+ recommended for browser sidecar."
  else
    ok "${total_gb}GB RAM detected"
  fi
elif command -v sysctl >/dev/null 2>&1; then
  total_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  total_gb=$((total_bytes / 1024 / 1024 / 1024))
  if [ "$total_gb" -lt 4 ]; then
    warn "System has ${total_gb}GB RAM. 4GB+ recommended for browser sidecar."
  else
    ok "${total_gb}GB RAM detected"
  fi
fi

# Disk space (recommend >= 5GB free)
free_kb=$(df -k "${INSTALL_DIR%/*}" 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)
free_gb=$((free_kb / 1024 / 1024))
if [ "$free_gb" -lt 5 ]; then
  warn "Only ${free_gb}GB free disk space. 5GB+ recommended."
else
  ok "${free_gb}GB free disk space"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# 2. Choose AI provider
# ══════════════════════════════════════════════════════════════════════════════
echo "─────────────────────────────────────────────"
printf "${BOLD}  AI Provider Setup${NC}\n"
echo "─────────────────────────────────────────────"
echo ""
printf "  1) ${GREEN}KConsole AI Gateway${NC} (recommended)\n"
echo "     Access 20+ models via one key. Includes KStorage."
echo ""
echo "  2) Bring Your Own Key (BYOK)"
echo "     Use your own Anthropic/OpenAI/etc. API key."
echo ""

ask "Choose [1/2]:"
read -r PROVIDER_CHOICE < $TTY_IN
PROVIDER_CHOICE="${PROVIDER_CHOICE:-1}"

KCONSOLE_AI_KEY=""
KCONSOLE_API_TOKEN=""
KSTORAGE_API_KEY=""
BYOK_VARS=""

if [ "$PROVIDER_CHOICE" = "1" ]; then
  # ── KConsole device-code auth ────────────────────────────────────────────
  echo ""
  info "Authenticating with KConsole..."
  echo ""

  # Request device code
  if [ "$HTTP_CLIENT" = "curl" ]; then
    DC_RESPONSE=$(curl -sf -X POST "${KCONSOLE_API}/api/provision/device-code" \
      -H "Content-Type: application/json" 2>&1) || fail "Failed to reach KConsole API at ${KCONSOLE_API}"
  else
    DC_RESPONSE=$(wget -qO- --post-data='{}' --header="Content-Type: application/json" \
      "${KCONSOLE_API}/api/provision/device-code" 2>&1) || fail "Failed to reach KConsole API at ${KCONSOLE_API}"
  fi

  USER_CODE=$(echo "$DC_RESPONSE" | grep -o '"user_code":"[^"]*"' | cut -d'"' -f4)
  DEVICE_CODE=$(echo "$DC_RESPONSE" | grep -o '"device_code":"[^"]*"' | cut -d'"' -f4)
  VERIFY_URL=$(echo "$DC_RESPONSE" | grep -o '"verification_url":"[^"]*"' | cut -d'"' -f4)

  if [ -z "$USER_CODE" ] || [ -z "$DEVICE_CODE" ]; then
    fail "Failed to get device code from KConsole. Response: ${DC_RESPONSE}"
  fi

  echo "┌─────────────────────────────────────────┐"
  echo "│                                         │"
  printf "│   Open: ${BOLD}%-32s${NC}│\n" "$VERIFY_URL"
  printf "│   Code: ${BOLD}${YELLOW}%-32s${NC}│\n" "$USER_CODE"
  echo "│                                         │"
  echo "└─────────────────────────────────────────┘"
  echo ""
  info "Waiting for you to approve in the browser..."

  # Poll for approval (up to 10 minutes, every 5 seconds)
  TOKEN=""
  for i in $(seq 1 120); do
    sleep 5
    if [ "$HTTP_CLIENT" = "curl" ]; then
      POLL_RESPONSE=$(curl -sf -X POST "${KCONSOLE_API}/api/provision/device-token" \
        -H "Content-Type: application/json" \
        -d "{\"device_code\":\"${DEVICE_CODE}\"}" 2>&1) || true
    else
      POLL_RESPONSE=$(wget -qO- --post-data="{\"device_code\":\"${DEVICE_CODE}\"}" \
        --header="Content-Type: application/json" \
        "${KCONSOLE_API}/api/provision/device-token" 2>&1) || true
    fi

    if echo "$POLL_RESPONSE" | grep -q '"success":true'; then
      TOKEN=$(echo "$POLL_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
      break
    fi

    if echo "$POLL_RESPONSE" | grep -q '"expired_token"'; then
      fail "Device code expired. Please run the installer again."
    fi

    # Print a dot every 5 polls (25s)
    if [ $((i % 5)) -eq 0 ]; then
      printf "."
    fi
  done

  if [ -z "$TOKEN" ]; then
    echo ""
    fail "Timed out waiting for approval. Please run the installer again."
  fi

  echo ""
  ok "Authenticated with KConsole!"
  echo ""

  # ── Provision resources ──────────────────────────────────────────────────
  info "Provisioning AI Gateway + KStorage..."

  if [ "$HTTP_CLIENT" = "curl" ]; then
    PROV_RESPONSE=$(curl -sf -X POST "${KCONSOLE_API}/api/provision/selfhost" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${TOKEN}" \
      -d '{"template":"openclaw"}' 2>&1) || fail "Provisioning failed. Are you logged in?"
  else
    PROV_RESPONSE=$(wget -qO- --post-data='{"template":"openclaw"}' \
      --header="Content-Type: application/json" \
      --header="Authorization: Bearer ${TOKEN}" \
      "${KCONSOLE_API}/api/provision/selfhost" 2>&1) || fail "Provisioning failed. Are you logged in?"
  fi

  if ! echo "$PROV_RESPONSE" | grep -q '"success":true'; then
    ERR_MSG=$(echo "$PROV_RESPONSE" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
    fail "Provisioning failed: ${ERR_MSG:-unknown error}"
  fi

  KCONSOLE_AI_KEY=$(echo "$PROV_RESPONSE" | grep -o '"KCONSOLE_AI_KEY":"[^"]*"' | cut -d'"' -f4)
  KCONSOLE_API_TOKEN=$(echo "$PROV_RESPONSE" | grep -o '"KCONSOLE_API_TOKEN":"[^"]*"' | cut -d'"' -f4)
  KSTORAGE_API_KEY=$(echo "$PROV_RESPONSE" | grep -o '"KSTORAGE_API_KEY":"[^"]*"' | cut -d'"' -f4)

  ok "Resources provisioned!"
  OPENCLAW_IMAGE="image.koompi.org/kconsole/openclaw:latest"
  echo ""

elif [ "$PROVIDER_CHOICE" = "2" ]; then
  # ── BYOK ─────────────────────────────────────────────────────────────────
  echo ""
  echo "  Supported providers:"
  echo "    a) Anthropic   (ANTHROPIC_API_KEY)"
  echo "    b) OpenAI      (OPENAI_API_KEY)"
  echo "    c) OpenRouter   (OPENROUTER_API_KEY)"
  echo "    d) Gemini      (GEMINI_API_KEY)"
  echo "    e) Other       (enter variable name)"
  echo ""
  ask "Choose [a-e]:"
  read -r KEY_CHOICE < $TTY_IN

  case "${KEY_CHOICE:-a}" in
    a) VAR_NAME="ANTHROPIC_API_KEY" ;;
    b) VAR_NAME="OPENAI_API_KEY" ;;
    c) VAR_NAME="OPENROUTER_API_KEY" ;;
    d) VAR_NAME="GEMINI_API_KEY" ;;
    e)
      ask "Environment variable name:"
      read -r VAR_NAME < $TTY_IN
      ;;
    *) VAR_NAME="ANTHROPIC_API_KEY" ;;
  esac

  ask "Enter your API key:"
  read -rs API_KEY_VALUE < $TTY_IN
  echo ""

  if [ -z "$API_KEY_VALUE" ]; then
    fail "API key cannot be empty."
  fi

  BYOK_VARS="${VAR_NAME}=${API_KEY_VALUE}"
  OPENCLAW_IMAGE="coollabsio/openclaw:latest"
  ok "API key set for ${VAR_NAME}"
  echo ""
else
  fail "Invalid choice. Run the installer again."
fi

# ══════════════════════════════════════════════════════════════════════════════
# 3. Configuration
# ══════════════════════════════════════════════════════════════════════════════
echo "─────────────────────────────────────────────"
printf "${BOLD}  Configuration${NC}\n"
echo "─────────────────────────────────────────────"
echo ""

# Password
ask "Set a password for the web UI (leave empty to auto-generate):"
read -rs AUTH_PASSWORD < $TTY_IN
echo ""

if [ -z "$AUTH_PASSWORD" ]; then
  AUTH_PASSWORD=$(openssl rand -base64 12 2>/dev/null || head -c 16 /dev/urandom | base64 | tr -d '=+/' | head -c 12)
  info "Generated password: ${BOLD}${AUTH_PASSWORD}${NC}"
fi

ask "Username [admin]:"
read -r AUTH_USERNAME < $TTY_IN
AUTH_USERNAME="${AUTH_USERNAME:-admin}"

echo ""
echo "─────────────────────────────────────────────"
printf "${BOLD}  Telegram Notification${NC}\n"
echo "─────────────────────────────────────────────"
echo ""
info "OpenClaw can send notifications via Telegram."
info "Create a bot with @BotFather to get a token."
echo ""

ask "Telegram Bot Token (leave empty to skip):"
read -r TELEGRAM_BOT_TOKEN < $TTY_IN

if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
  ask "Allowed Telegram user IDs (comma-separated):"
  read -r TELEGRAM_ALLOW_FROM < $TTY_IN
  if [ -z "$TELEGRAM_ALLOW_FROM" ]; then
    warn "No user IDs set — bot will not respond to anyone."
  fi
else
  TELEGRAM_ALLOW_FROM=""
  info "Skipping Telegram setup."
fi

echo ""
echo "─────────────────────────────────────────────"
printf "${BOLD}  Network & Directory${NC}\n"
echo "─────────────────────────────────────────────"
echo ""

ask "Port [${PORT}]:"
read -r USER_PORT < $TTY_IN
PORT="${USER_PORT:-$PORT}"

ask "Install directory [${INSTALL_DIR}]:"
read -r USER_DIR < $TTY_IN
INSTALL_DIR="${USER_DIR:-$INSTALL_DIR}"

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# 4. Write files
# ══════════════════════════════════════════════════════════════════════════════
info "Setting up ${INSTALL_DIR}..."
mkdir -p "${INSTALL_DIR}"

# ── .env ─────────────────────────────────────────────────────────────────────
cat > "${INSTALL_DIR}/.env" << ENVEOF
# OpenClaw Self-Hosted — generated by install.sh
# $(date -u +"%Y-%m-%dT%H:%M:%SZ")

PORT=${PORT}
AUTH_USERNAME=${AUTH_USERNAME}
AUTH_PASSWORD=${AUTH_PASSWORD}

# KConsole Cloud Keys
KCONSOLE_AI_KEY=${KCONSOLE_AI_KEY}
KCONSOLE_API_TOKEN=${KCONSOLE_API_TOKEN}
KSTORAGE_API_KEY=${KSTORAGE_API_KEY}
AI_GATEWAY_BASE_URL=https://ai.koompi.cloud/v1

# BYOK (if using your own key)
${BYOK_VARS}

# Telegram Notifications
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
TELEGRAM_ALLOW_FROM=${TELEGRAM_ALLOW_FROM}
TELEGRAM_DM_POLICY=allowlist

# Model (auto-selected if empty)
# OPENCLAW_PRIMARY_MODEL=opencode/kimi-k2.5
ENVEOF

ok "Wrote ${INSTALL_DIR}/.env"

# ── docker-compose.yml ───────────────────────────────────────────────────────
cat > "${INSTALL_DIR}/docker-compose.yml" << COMPOSEEOF
services:
  openclaw:
    image: ${OPENCLAW_IMAGE}
    ports:
      - "\${PORT:-8080}:\${PORT:-8080}"
    env_file:
      - .env
    environment:
      - OPENCODE_API_KEY=\${KCONSOLE_AI_KEY}
      - OPENCLAW_PRIMARY_MODEL=opencode/kimi-k2.5
      - BROWSER_CDP_URL=http://browser:9223
      - BROWSER_DEFAULT_PROFILE=openclaw
      - BROWSER_EVALUATE_ENABLED=true
    volumes:
      - openclaw-data:/data
    depends_on:
      - browser
    restart: unless-stopped

  browser:
    image: coollabsio/openclaw-browser:latest
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - CHROME_CLI=--remote-debugging-port=9222
    volumes:
      - browser-data:/config
    shm_size: 2g
    restart: unless-stopped

volumes:
  openclaw-data:
  browser-data:
COMPOSEEOF

ok "Wrote ${INSTALL_DIR}/docker-compose.yml"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# 5. Pull & start
# ══════════════════════════════════════════════════════════════════════════════
info "Pulling Docker images (this may take a minute)..."
(cd "${INSTALL_DIR}" && $COMPOSE_CMD pull)
echo ""

info "Starting OpenClaw..."
(cd "${INSTALL_DIR}" && $COMPOSE_CMD up -d)
echo ""

# ── Health check ─────────────────────────────────────────────────────────────
info "Waiting for OpenClaw to start..."
HEALTHY=false
for i in $(seq 1 30); do
  if [ "$HTTP_CLIENT" = "curl" ]; then
    STATUS=$(curl -sf -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/healthz" 2>/dev/null) || STATUS="000"
  else
    STATUS=$(wget -qS -O /dev/null "http://localhost:${PORT}/healthz" 2>&1 | awk '/HTTP\// {print $2}' | tail -1) || STATUS="000"
  fi

  if [ "$STATUS" = "200" ] || [ "$STATUS" = "401" ]; then
    HEALTHY=true
    break
  fi
  sleep 2
done

echo ""
if [ "$HEALTHY" = "true" ]; then
  printf "${GREEN}${BOLD}"
  echo "┌─────────────────────────────────────────────────┐"
  echo "│                                                 │"
  echo "│   OpenClaw is running!                          │"
  printf "│   URL:      ${NC}${BOLD}http://localhost:%-22s${GREEN}${BOLD}│\n" "${PORT}"
  printf "│   Username: ${NC}${BOLD}%-37s${GREEN}${BOLD}│\n" "${AUTH_USERNAME}"
  printf "│   Password: ${NC}${BOLD}%-37s${GREEN}${BOLD}│\n" "${AUTH_PASSWORD}"
  echo "│                                                 │"
  echo "└─────────────────────────────────────────────────┘"
  printf "${NC}\n"
else
  warn "OpenClaw did not respond within 60 seconds."
  warn "Check logs with: cd ${INSTALL_DIR} && ${COMPOSE_CMD} logs -f"
fi

echo ""
echo "  Useful commands:"
echo "    cd ${INSTALL_DIR}"
echo "    ${COMPOSE_CMD} logs -f        # View logs"
echo "    ${COMPOSE_CMD} restart        # Restart"
echo "    ${COMPOSE_CMD} down           # Stop"
echo "    ${COMPOSE_CMD} pull && ${COMPOSE_CMD} up -d  # Update"
echo ""
