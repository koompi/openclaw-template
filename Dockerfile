ARG BASE_IMAGE=ghcr.io/coollabsio/openclaw-base:latest

FROM ${BASE_IMAGE}

ENV NODE_ENV=production \
    NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache \
    OPENCLAW_NO_RESPAWN=1

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    nginx \
    apache2-utils \
    chromium \
    xvfb \
    ffmpeg \
  && rm -rf /var/lib/apt/lists/*

# Remove default nginx site
RUN rm -f /etc/nginx/sites-enabled/default

COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

# Install memory-lancedb-pro plugin at build time.
# The plugin path is added to plugins.load.paths by configure.js.
RUN mkdir -p /app/plugins && cd /app/plugins \
  && npm init -y --silent 2>/dev/null \
  && npm install memory-lancedb-pro@beta --save --silent 2>&1 | tail -5

# Pre-install openclaw plugin bundled runtime deps at build time.
# Without this, openclaw runs `npm install` for each active plugin at every
# container start, adding ~7 minutes of download time.
# Pre-install common plugin dependencies to speed up startup
RUN mkdir -p /opt/openclaw/app/plugins/bundled \
    && cd /opt/openclaw/app/plugins/bundled \
    && npm install --silent @modelcontextprotocol/sdk@1.29.0 commander@^14.0.3 express@5.2.1 playwright-core@1.59.1 typebox@1.1.33 undici@8.1.0 ws@^8.20.0

# Bundle KOOMPI Cloud skill docs (KConsole, KStorage, AI Gateway)
COPY skills/ /app/skills/

# Pre-install koompi-office Python dependencies at build time so the agent
# can use Excel/PDF/Word/PowerPoint/Image/Charts/QR/Barcode immediately
# without waiting for pip install on every container start.
# Note: tiktokautouploader and phantomwright are removed to reduce image size.
RUN uv pip install --system --break-system-packages --no-cache \
    openpyxl pandas xlsxwriter pdfplumber reportlab \
    python-docx python-pptx Pillow matplotlib \
    qrcode python-barcode

# Set Chromium path for Playwright/Phantomwright (Debian package location)
ENV CHROMIUM_PATH="/usr/bin/chromium" \
    PLAYWRIGHT_BROWSERS_PATH="/root/.cache/ms-playwright"

ENV NPM_CONFIG_PREFIX="/data/npm-global" \
    UV_TOOL_DIR="/data/uv/tools" \
    UV_CACHE_DIR="/data/uv/cache" \
    GOPATH="/data/go" \
    PATH="/data/npm-global/bin:/data/uv/tools/bin:/data/go/bin:${PATH}"

ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:${PORT:-8080}/healthz || exit 1

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
