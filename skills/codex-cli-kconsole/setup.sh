#!/bin/bash
# Quick setup script for Codex + KConsole AI Gateway
# Usage: ./setup.sh

set -e

echo "🚀 Setting up Codex CLI with KConsole AI Gateway..."

# Check for API key
if [ -z "$KCONSOLE_API_KEY" ]; then
    echo "❌ Error: KCONSOLE_API_KEY environment variable not set"
    echo ""
    echo "Please set your API key:"
    echo "  export KCONSOLE_API_KEY=\"kpi_your_api_key_here\""
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Check if codex is installed
if ! command -v codex &> /dev/null; then
    echo "❌ Codex CLI not found. Installing..."
    npm install -g @openai/codex
fi

# Backup existing config
if [ -f ~/.codex/config.toml ]; then
    echo "📦 Backing up existing config..."
    cp ~/.codex/config.toml ~/.codex/config.toml.backup.$(date +%s)
fi

# Create codex directory if it doesn't exist
mkdir -p ~/.codex

# Copy sample config
echo "📝 Creating configuration..."
cat > ~/.codex/config.toml << 'EOF'
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
EOF

# Add API key to bashrc if not already there
if ! grep -q "KCONSOLE_API_KEY" ~/.bashrc 2>/dev/null; then
    echo "🔑 Adding API key to ~/.bashrc..."
    echo "" >> ~/.bashrc
    echo "# KConsole AI Gateway API Key for Codex" >> ~/.bashrc
    echo "export KCONSOLE_API_KEY=\"$KCONSOLE_API_KEY\"" >> ~/.bashrc
fi

# Test the connection
echo ""
echo "🧪 Testing connection..."
if codex exec --skip-git-repo-check "Reply with: Setup complete!" 2>&1 | grep -q "Setup complete"; then
    echo ""
    echo "✅ Setup successful!"
    echo ""
    echo "📚 Quick Start:"
    echo "  codex exec --skip-git-repo-check \"Your prompt here\""
    echo ""
    echo "🔄 To switch to Gemini:"
    echo "  codex exec --skip-git-repo-check -c model_provider=kconsole-gemini -c model=gemini-3-flash-preview \"Your prompt\""
    echo ""
    echo "📖 For more options, see SKILL.md"
else
    echo ""
    echo "⚠️  Setup completed but test failed. Please check:"
    echo "  1. Your API key is valid"
    echo "  2. KConsole gateway is accessible"
    echo "  3. Run: codex exec --skip-git-repo-check \"test\""
fi
