# Social Media Automation
# Official API integrations for social media management via OpenClaw

## Supported Platforms

| Platform | Status | Notes |
|---|---|---|
| ✅ Facebook | Ready | Meta Graph API, tested & working |
| ✅ TikTok | Experimental | Browser automation via tiktokautouploader, tested on @ayeye_67 |
| 🚧 Instagram | Planned | Via Meta Graph API, needs Professional account |
| 🚧 Threads | Planned | Via Meta Graph API |
| 🚧 X/Twitter | Planned | API v2 (paid tier required) |
| 🚧 Bluesky | Planned | AT Protocol, no app review needed |
| 🚧 Mastodon | Planned | Any instance, no app review |
| 🚧 YouTube | Planned | Data API v3 |
| 🚧 LinkedIn | Planned | Marketing API |
| 🚧 Pinterest | Planned | API v5 |

## Quick Start (Facebook)

1. Copy `.env.example` to `.env` and fill in your credentials
2. Run `./scripts/setup-facebook.sh` for guided setup
3. Post via MCP server or directly with `curl`

## Structure

```
social-media-automation/
├── SKILL.md                    # OpenClaw skill definition
├── .env.example                # Template for credentials
├── .gitignore
├── README.md
├── scripts/                    # Setup scripts per platform
│   ├── setup-facebook.sh
│   ├── setup-bluesky.sh
│   ├── setup-threads.sh
│   └── setup-mastodon.sh
├── mcp-servers/                # MCP server implementations
│   └── facebook/               # Facebook MCP (Graph API)
├── references/                 # Platform-specific docs
│   └── facebook-setup.md
```

## Usage with OpenClaw

This project includes an OpenClaw-compatible `SKILL.md`. To install:

```bash
# Symlink to workspace skills
ln -s /path/to/social-media-automation ~/.openclaw/workspace/skills/social-media
```

Or copy the `SKILL.md` into your OpenClaw skills directory.

## MCP Servers

MCP servers enable tool-based interaction with social media platforms. They can be used with:
- OpenClaw
- Claude Desktop
- Any MCP-compatible client

### Facebook MCP Server

Based on [facebook-mcp-server](https://github.com/tiroshanm/facebook-mcp-server).

```bash
cd mcp-servers/facebook
cp .env.example .env  # Fill in your tokens
uv sync
uv run facebook-mcp-server
```

## License

MIT
