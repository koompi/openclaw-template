# KOOMPI Cloud Skills Index

This workspace includes documentation for KOOMPI Cloud platform services. Read these when the user asks you to deploy apps, upload files, or generate AI content.

## Available Guides

| File | When to use |
|---|---|
| [kconsole.md](kconsole.md) | Deploy apps/databases/VPS on KOOMPI Cloud, manage services, check logs |
| [kstorage.md](kstorage.md) | Upload files, get CDN URLs, manage stored assets |
| [kconsole-ai.md](kconsole-ai.md) | Generate images/videos via AI Gateway (Gemini, Imagen, Veo) |

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
