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
# 1.5 Detect existing installation
# ══════════════════════════════════════════════════════════════════════════════
REUSE_ENV=false
EXISTING_KCONSOLE_AI_KEY=""
EXISTING_KCONSOLE_API_TOKEN=""
EXISTING_KSTORAGE_API_KEY=""
EXISTING_BYOK_VARS=""
EXISTING_OPENCLAW_IMAGE=""
EXISTING_TELEGRAM_BOT_TOKEN=""
EXISTING_TELEGRAM_ALLOW_FROM=""

# Helper: read a value from an existing .env file
read_env_val() {
  grep "^${1}=" "${INSTALL_DIR}/.env" 2>/dev/null | head -1 | cut -d'=' -f2-
}

if [ -f "${INSTALL_DIR}/.env" ]; then
  echo "─────────────────────────────────────────────"
  printf "${BOLD}  Existing Installation Detected${NC}\n"
  echo "─────────────────────────────────────────────"
  echo ""
  printf "${BLUE}ℹ${NC}  Found existing config at ${BOLD}%s${NC}\n" "${INSTALL_DIR}/.env"
  echo ""
  echo "  1) Reinstall (keep existing API keys & config)"
  echo "  2) Reconfigure (keep API keys, change settings)"
  echo "  3) Update images only (pull latest & restart)"
  echo "  4) Fresh install (new auth & provisioning)"
  echo ""
  ask "Choose [1-4]:"
  read -r REINSTALL_CHOICE < $TTY_IN
  REINSTALL_CHOICE="${REINSTALL_CHOICE:-1}"
  echo ""

  if [ "$REINSTALL_CHOICE" = "3" ]; then
    # ── Update only: pull + restart, then exit ─────────────────────────────
    info "Pulling latest images..."
    (cd "${INSTALL_DIR}" && $COMPOSE_CMD pull)
    echo ""
    info "Restarting..."
    (cd "${INSTALL_DIR}" && $COMPOSE_CMD up -d)
    echo ""
    ok "Updated! OpenClaw is running at http://localhost:$(read_env_val PORT)"
    exit 0
  fi

  if [ "$REINSTALL_CHOICE" = "1" ] || [ "$REINSTALL_CHOICE" = "2" ]; then
    # Read existing keys from .env
    EXISTING_KCONSOLE_AI_KEY=$(read_env_val KCONSOLE_AI_KEY)
    EXISTING_KCONSOLE_API_TOKEN=$(read_env_val KCONSOLE_API_TOKEN)
    EXISTING_KSTORAGE_API_KEY=$(read_env_val KSTORAGE_API_KEY)
    EXISTING_TELEGRAM_BOT_TOKEN=$(read_env_val TELEGRAM_BOT_TOKEN)
    EXISTING_TELEGRAM_ALLOW_FROM=$(read_env_val TELEGRAM_ALLOW_FROM)

    # Detect which image was used from docker-compose.yml
    if [ -f "${INSTALL_DIR}/docker-compose.yml" ]; then
      EXISTING_OPENCLAW_IMAGE=$(grep 'image:' "${INSTALL_DIR}/docker-compose.yml" | head -1 | awk '{print $2}')
    fi

    # Check for BYOK keys
    for var in ANTHROPIC_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY GEMINI_API_KEY; do
      val=$(read_env_val "$var")
      if [ -n "$val" ]; then
        EXISTING_BYOK_VARS="${var}=${val}"
        break
      fi
    done

    if [ -n "$EXISTING_KCONSOLE_AI_KEY" ] || [ -n "$EXISTING_BYOK_VARS" ]; then
      REUSE_ENV=true
      ok "Loaded existing API keys from .env"
    else
      warn "No API keys found in existing .env — will run fresh setup."
    fi
  fi
  # REINSTALL_CHOICE=4 falls through to fresh install (REUSE_ENV stays false)
fi

if [ "$REUSE_ENV" = "true" ]; then
  # ── Reuse existing keys ────────────────────────────────────────────────
  KCONSOLE_AI_KEY="$EXISTING_KCONSOLE_AI_KEY"
  KCONSOLE_API_TOKEN="$EXISTING_KCONSOLE_API_TOKEN"
  KSTORAGE_API_KEY="$EXISTING_KSTORAGE_API_KEY"
  BYOK_VARS="$EXISTING_BYOK_VARS"
  TELEGRAM_BOT_TOKEN="$EXISTING_TELEGRAM_BOT_TOKEN"
  TELEGRAM_ALLOW_FROM="$EXISTING_TELEGRAM_ALLOW_FROM"

  if [ -n "$EXISTING_OPENCLAW_IMAGE" ]; then
    OPENCLAW_IMAGE="$EXISTING_OPENCLAW_IMAGE"
  elif [ -n "$KCONSOLE_AI_KEY" ]; then
    OPENCLAW_IMAGE="image.koompi.org/koompiclaw/openclaw:latest"
  else
    OPENCLAW_IMAGE="coollabsio/openclaw:latest"
  fi

  # Determine model from existing config
  OPENCLAW_PRIMARY_MODEL=$(read_env_val OPENCLAW_PRIMARY_MODEL)
  if [ -z "$OPENCLAW_PRIMARY_MODEL" ]; then
    if [ -n "$KCONSOLE_AI_KEY" ]; then
      OPENCLAW_PRIMARY_MODEL="kconsole/glm-5-turbo"
    else
      OPENCLAW_PRIMARY_MODEL="opencode/kimi-k2.5"
    fi
  fi

  if [ "$REINSTALL_CHOICE" = "1" ]; then
    # Full reinstall — also reuse config values
    AUTH_PASSWORD=$(read_env_val AUTH_PASSWORD)
    AUTH_USERNAME=$(read_env_val AUTH_USERNAME)
    PORT=$(read_env_val PORT)
    PORT="${PORT:-8080}"
    OPENCLAW_GATEWAY_TOKEN=$(read_env_val OPENCLAW_GATEWAY_TOKEN)
    OPENCLAW_ALLOWED_ORIGINS=$(read_env_val OPENCLAW_ALLOWED_ORIGINS)
    info "Reusing existing configuration."
    echo ""
  fi
  # REINSTALL_CHOICE=2 falls through to the config prompts below
else

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
TELEGRAM_BOT_TOKEN=""
TELEGRAM_ALLOW_FROM=""

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

  # ── Choose organization ──────────────────────────────────────────────────
  info "Fetching your organizations..."

  if [ "$HTTP_CLIENT" = "curl" ]; then
    ME_RESPONSE=$(curl -sf "${KCONSOLE_API}/api/auth/me" \
      -H "Authorization: Bearer ${TOKEN}" 2>&1) || fail "Failed to fetch user info."
  else
    ME_RESPONSE=$(wget -qO- --header="Authorization: Bearer ${TOKEN}" \
      "${KCONSOLE_API}/api/auth/me" 2>&1) || fail "Failed to fetch user info."
  fi

  # Extract org names and IDs (simple grep-based parsing)
  ORG_IDS=""
  ORG_NAMES=""
  ORG_COUNT=0
  # Parse memberships array — each has "organization":{"_id":"...","name":"..."}
  ORG_IDS=$(echo "$ME_RESPONSE" | grep -o '"organization":{[^}]*}' | grep -o '"_id":"[^"]*"' | cut -d'"' -f4)
  ORG_NAMES=$(echo "$ME_RESPONSE" | grep -o '"organization":{[^}]*}' | grep -o '"name":"[^"]*"' | cut -d'"' -f4)

  # Convert to arrays
  ORG_ID_ARR=()
  ORG_NAME_ARR=()
  while IFS= read -r line; do
    [ -n "$line" ] && ORG_ID_ARR+=("$line")
  done <<< "$ORG_IDS"
  while IFS= read -r line; do
    [ -n "$line" ] && ORG_NAME_ARR+=("$line")
  done <<< "$ORG_NAMES"
  ORG_COUNT=${#ORG_ID_ARR[@]}

  SELECTED_ORG_ID=""
  if [ "$ORG_COUNT" -eq 0 ]; then
    warn "No organizations found. Will use default."
  elif [ "$ORG_COUNT" -eq 1 ]; then
    SELECTED_ORG_ID="${ORG_ID_ARR[0]}"
    ok "Using organization: ${ORG_NAME_ARR[0]}"
  else
    echo ""
    echo "  Your organizations:"
    for i in $(seq 0 $((ORG_COUNT - 1))); do
      printf "    %d) %s\n" "$((i + 1))" "${ORG_NAME_ARR[$i]}"
    done
    echo ""
    ask "Choose organization [1-${ORG_COUNT}]:"
    read -r ORG_CHOICE < $TTY_IN
    ORG_CHOICE="${ORG_CHOICE:-1}"

    # Validate choice
    ORG_IDX=$((ORG_CHOICE - 1))
    if [ "$ORG_IDX" -ge 0 ] && [ "$ORG_IDX" -lt "$ORG_COUNT" ]; then
      SELECTED_ORG_ID="${ORG_ID_ARR[$ORG_IDX]}"
      ok "Using organization: ${ORG_NAME_ARR[$ORG_IDX]}"
    else
      SELECTED_ORG_ID="${ORG_ID_ARR[0]}"
      warn "Invalid choice. Using: ${ORG_NAME_ARR[0]}"
    fi
  fi
  echo ""

  # ── Provision resources ──────────────────────────────────────────────────
  info "Provisioning AI Gateway + KStorage..."

  PROV_BODY="{\"template\":\"openclaw\""
  if [ -n "$SELECTED_ORG_ID" ]; then
    PROV_BODY="${PROV_BODY},\"organizationId\":\"${SELECTED_ORG_ID}\""
  fi
  PROV_BODY="${PROV_BODY}}"

  if [ "$HTTP_CLIENT" = "curl" ]; then
    PROV_RESPONSE=$(curl -sf -X POST "${KCONSOLE_API}/api/provision/selfhost" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${TOKEN}" \
      -d "${PROV_BODY}" 2>&1) || fail "Provisioning failed. Are you logged in?"
  else
    PROV_RESPONSE=$(wget -qO- --post-data="${PROV_BODY}" \
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
  OPENCLAW_PRIMARY_MODEL="kconsole/glm-5-turbo"
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
  OPENCLAW_PRIMARY_MODEL="opencode/kimi-k2.5"
  ok "API key set for ${VAR_NAME}"
  echo ""
else
  fail "Invalid choice. Run the installer again."
fi

fi  # end of if REUSE_ENV (else = fresh install block)

# ══════════════════════════════════════════════════════════════════════════════
# 3. Configuration
# ══════════════════════════════════════════════════════════════════════════════
# Skip config prompts if doing a full reinstall (choice 1) with reused config
if [ "$REUSE_ENV" = "true" ] && [ "${REINSTALL_CHOICE:-}" = "1" ]; then
  : # config already loaded above
else

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
  printf "${BLUE}ℹ${NC}  Generated password: ${BOLD}%s${NC}\n" "${AUTH_PASSWORD}"
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
read -rs TELEGRAM_BOT_TOKEN < $TTY_IN
echo ""

if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
  MASKED_TOKEN="${TELEGRAM_BOT_TOKEN:0:6}****${TELEGRAM_BOT_TOKEN: -4}"
  ok "Bot token set (${MASKED_TOKEN})"
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

fi  # end of config prompts

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# 4. Write files
# ══════════════════════════════════════════════════════════════════════════════
info "Setting up ${INSTALL_DIR}..."
mkdir -p "${INSTALL_DIR}"

# Auto-detect public IP for allowed origins
if [ -z "${OPENCLAW_ALLOWED_ORIGINS:-}" ]; then
  PUBLIC_IP=""
  if [ "$HTTP_CLIENT" = "curl" ]; then
    PUBLIC_IP=$(curl -sf --max-time 5 https://ifconfig.me 2>/dev/null || curl -sf --max-time 5 https://api.ipify.org 2>/dev/null || true)
  else
    PUBLIC_IP=$(wget -qO- --timeout=5 https://ifconfig.me 2>/dev/null || wget -qO- --timeout=5 https://api.ipify.org 2>/dev/null || true)
  fi
  if [ -n "$PUBLIC_IP" ]; then
    OPENCLAW_ALLOWED_ORIGINS="http://${PUBLIC_IP}:${PORT},http://localhost:${PORT},http://127.0.0.1:${PORT}"
    info "Detected public IP: ${PUBLIC_IP}"
  else
    OPENCLAW_ALLOWED_ORIGINS="http://localhost:${PORT},http://127.0.0.1:${PORT}"
    warn "Could not detect public IP. Add your IP/domain to OPENCLAW_ALLOWED_ORIGINS in .env if needed."
  fi
fi

# Generate gateway token (reuse existing if available)
if [ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
  OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 64)
fi

# ── .env ─────────────────────────────────────────────────────────────────────
cat > "${INSTALL_DIR}/.env" << ENVEOF
# OpenClaw Self-Hosted — generated by install.sh
# $(date -u +"%Y-%m-%dT%H:%M:%SZ")

PORT=${PORT}
AUTH_USERNAME=${AUTH_USERNAME}
AUTH_PASSWORD=${AUTH_PASSWORD}
OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
OPENCLAW_ALLOWED_ORIGINS=${OPENCLAW_ALLOWED_ORIGINS}

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

# Model
OPENCLAW_PRIMARY_MODEL=${OPENCLAW_PRIMARY_MODEL}
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
info "Waiting for OpenClaw to start (this can take up to 2 minutes)..."
HEALTHY=false
for i in $(seq 1 60); do
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
  warn "OpenClaw did not respond within 2 minutes."
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
