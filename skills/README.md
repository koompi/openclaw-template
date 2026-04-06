# KOOMPI Cloud Skills Index

This workspace includes documentation for KOOMPI Cloud platform services and productivity tools. Read these when the user asks you to deploy apps, upload files, generate AI content, process documents, or manage social media.

## Available Guides

| File | When to use |
|---|---|
| [kconsole.md](kconsole.md) | Deploy apps/databases/VPS on KOOMPI Cloud, manage services, check logs |
| [kstorage.md](kstorage.md) | Upload files, get CDN URLs, manage stored assets |
| [kconsole-ai.md](kconsole-ai.md) | Generate images/videos via AI Gateway (Gemini, Imagen, Veo) |
| [koompi-office/SKILL.md](koompi-office/SKILL.md) | Read/create Excel, PDF, Word, PowerPoint, images, charts, QR codes, barcodes, OCR |
| [social-media-automation/SKILL.md](social-media-automation/SKILL.md) | Post, reply, and manage content on Facebook, Instagram, Threads, TikTok, X/Twitter, YouTube, LinkedIn, Pinterest, Bluesky, Mastodon |
| [koompi-biz/SKILL.md](koompi-biz/SKILL.md) | Manage Riverbase/KOOMPI BIZ shops — products, orders, inventory, shipping, discounts, memberships, storefront |
| [claude-code-kconsole/SKILL.md](claude-code-kconsole/SKILL.md) | Use Claude Code for vibe coding sessions |
| [codex-cli-kconsole/SKILL.md](codex-cli-kconsole/SKILL.md) | Use OpenAI Codex CLI for coding tasks |
| [sync.md](sync.md) | Universal context primer — load all memory, check infrastructure, report active state |


## Quick Auth Reference

| Service | Env Var | Header |
|---|---|---|
| KConsole API | `$KCONSOLE_API_TOKEN` | `Authorization: Bearer $KCONSOLE_API_TOKEN` |
| KStorage | `$KSTORAGE_API_KEY` | `x-api-key: $KSTORAGE_API_KEY` |
| AI Gateway | `$KCONSOLE_AI_KEY` (also `AI_GATEWAY_API_KEY`) | `Authorization: Bearer $KCONSOLE_AI_KEY` |

## API Base URLs

- **KConsole API:** `https://api-kconsole.koompi.cloud`
- **KStorage CDN:** `https://storage.koompi.cloud`
- **AI Gateway:** `https://ai.koompi.cloud/v1`
