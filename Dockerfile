ARG BASE_IMAGE=ghcr.io/coollabsio/openclaw-base:latest

FROM ${BASE_IMAGE}

ENV NODE_ENV=production

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    nginx \
    apache2-utils \
    chromium \
    xvfb \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
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

# Bundle KOOMPI Cloud skill docs (KConsole, KStorage, AI Gateway)
COPY skills/ /app/skills/

# Pre-install koompi-office Python dependencies at build time so the agent
# can use Excel/PDF/Word/PowerPoint/Image/Charts/QR/Barcode immediately
# without waiting for pip install on every container start.
# Also install TikTok uploader deps for social-media-automation skill.
RUN uv pip install --system --no-cache \
    openpyxl pandas xlsxwriter pdfplumber reportlab \
    python-docx python-pptx Pillow matplotlib \
    qrcode python-barcode \
    tiktokautouploader

# Install Phantomwright Chromium driver for TikTok stealth browser automation
RUN python3 -c "from phantomwright.driver import install; install('chromium')" 2>&1 | tail -3 || true

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
