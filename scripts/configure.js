#!/usr/bin/env node
// Reads environment variables and writes/patches openclaw.json.
// Supports a user-provided JSON config file (OPENCLAW_CUSTOM_CONFIG) as a base,
// with env vars overriding on top.
// No npm dependencies — uses only Node built-ins.

const fs = require("fs");
const path = require("path");

// ── Import Utilities ─────────────────────────────────────────────────────────
const {
  ENV_VAR,
  EXIT_CODE,
  coerceType,
  parseArrayValue,
  parseAllowedOrigins,
} = require('./utils');

const STATE_DIR = (process.env.OPENCLAW_STATE_DIR || "/data/.openclaw").replace(/\/+$/, "");
const WORKSPACE_DIR = (process.env.OPENCLAW_WORKSPACE_DIR || "/data/workspace").replace(/\/+$/, "");
const CONFIG_FILE = process.env.OPENCLAW_CONFIG_PATH || path.join(STATE_DIR, "openclaw.json");
const CUSTOM_CONFIG = process.env.OPENCLAW_CUSTOM_CONFIG || "/app/config/openclaw.json";

console.log("[configure] state dir:", STATE_DIR);
console.log("[configure] workspace dir:", WORKSPACE_DIR);
console.log("[configure] config file:", CONFIG_FILE);

// Ensure directories exist
fs.mkdirSync(STATE_DIR, { recursive: true });
fs.mkdirSync(WORKSPACE_DIR, { recursive: true });

// Deep merge: source into target. Arrays are replaced, not concatenated.
const UNSAFE_KEYS = new Set(['__proto__', 'constructor', 'prototype']);
function deepMerge(target, source) {
  for (const key of Object.keys(source)) {
    if (UNSAFE_KEYS.has(key)) continue;
    if (
      source[key] && typeof source[key] === "object" && !Array.isArray(source[key]) &&
      target[key] && typeof target[key] === "object" && !Array.isArray(target[key])
    ) {
      deepMerge(target[key], source[key]);
    } else {
      target[key] = source[key];
    }
  }
  return target;
}

// Load config: custom JSON (base) → existing persisted config → env vars (on top)
let config = {};

// 1. Load user-provided custom config as base (if mounted)
let hasCustomConfig = false;
try {
  const customRaw = fs.readFileSync(CUSTOM_CONFIG, "utf8");
  config = JSON.parse(customRaw);
  hasCustomConfig = true;
  console.log("[configure] loaded custom config from", CUSTOM_CONFIG);
} catch {
  // No custom config file — that's fine
}

// 2. Merge persisted config on top (preserves runtime state from previous runs)
try {
  const persisted = JSON.parse(fs.readFileSync(CONFIG_FILE, "utf8"));
  deepMerge(config, persisted);
  console.log("[configure] merged persisted config from", CONFIG_FILE);
} catch {
  console.log("[configure] no persisted config found");
}

// 3. Env vars override on top (applied below)

// Helper: ensure nested path exists
function ensure(obj, ...keys) {
  let cur = obj;
  for (const k of keys) {
    cur[k] = cur[k] || {};
    cur = cur[k];
  }
  return cur;
}

// ── Gateway ─────────────────────────────────────────────────────────────────
// Env vars override; custom JSON values are preserved when env is not set.

ensure(config, "gateway");
if (process.env.OPENCLAW_GATEWAY_PORT) {
  config.gateway.port = parseInt(process.env.OPENCLAW_GATEWAY_PORT, 10);
} else if (!config.gateway.port) {
  config.gateway.port = 18789;
}
if (!config.gateway.mode) {
  config.gateway.mode = "local";
}

// Gateway token: required via OPENCLAW_GATEWAY_TOKEN env var (enforced by entrypoint.sh)
const token = (process.env.OPENCLAW_GATEWAY_TOKEN || "").trim();
if (token) {
  ensure(config, "gateway", "auth");
  config.gateway.auth.mode = "token";
  config.gateway.auth.token = token;
}

// Allow control UI without device pairing (only set defaults, don't overwrite)
ensure(config, "gateway", "controlUi");
if (config.gateway.controlUi.allowInsecureAuth === undefined) {
  config.gateway.controlUi.allowInsecureAuth = true;
}
if (config.gateway.controlUi.enabled === undefined) {
  config.gateway.controlUi.enabled = true;
}

// Disable device identity checks for containerised deployments.
// In a single-container setup (nginx + gateway + tools in one image) all
// connections originate from 127.0.0.1.  With trustedProxies including
// "127.0.0.1", the gateway expects X-Forwarded-For from loopback — but
// internal tools (cron, memory, etc.) connect via WebSocket directly and
// never set that header, causing ip=unknown-ip.  Without a recognisable
// local IP the gateway cannot auto-approve scope upgrades (operator.approvals
// → operator.admin), which breaks cron and other control-plane tools.
// Since all auth already goes through the auto-generated gateway token,
// device identity adds no additional security in this deployment model.
if (config.gateway.controlUi.dangerouslyDisableDeviceAuth === undefined) {
  config.gateway.controlUi.dangerouslyDisableDeviceAuth = true;
}

// Bind address (all gateway config comes from openclaw.json; "gateway run" reads it)
if (config.gateway.bind === undefined) {
  config.gateway.bind = process.env.OPENCLAW_GATEWAY_BIND || "loopback";
}

// Trusted proxies: always trust loopback so nginx (running on the same container)
// can forward X-Forwarded-For headers without triggering the proxy-header warning.
// Without this, openclaw rejects WebSocket connects with "nonce must NOT have fewer
// than 1 characters" because it can't derive local client status from the headers.
if (!config.gateway.trustedProxies || config.gateway.trustedProxies.length === 0) {
  config.gateway.trustedProxies = ["127.0.0.1", "::1"];
}

// ── Agents defaults ─────────────────────────────────────────────────────────

ensure(config, "agents", "defaults");
if (!config.agents.defaults.workspace) {
  config.agents.defaults.workspace = WORKSPACE_DIR;
}
ensure(config, "agents", "defaults", "model");

// ── Providers ───────────────────────────────────────────────────────────────
//
// Built-in providers: openclaw already knows their baseUrl, models, and API
// type. We only need to pass the env var — do NOT write models.providers entries
// for these, or openclaw will reject them for missing baseUrl/models fields.
//
// Custom/proxy providers: not in the built-in catalog, so we must supply the
// full config (api, baseUrl, models[]).

// Helper: log + clean up a removed provider (only when no custom JSON is loaded)
function removeProvider(name, label, envHint) {
  if (!hasCustomConfig && config.models?.providers?.[name]) {
    console.log(`[configure] removing ${label} provider (${envHint} not set)`);
    delete config.models.providers[name];
  }
}

// ── Built-in providers (env var only, no models.providers entry) ────────────
// These are auto-detected by openclaw when the env var is set.
const opencodeKey = process.env.OPENCODE_API_KEY || process.env.OPENCODE_ZEN_API_KEY;

// [envVar, label, providerKey in models.providers]
const builtinProviders = [
  ["ANTHROPIC_API_KEY",    "Anthropic",          "anthropic"],
  ["OPENAI_API_KEY",       "OpenAI",             "openai"],
  ["OPENROUTER_API_KEY",   "OpenRouter",         "openrouter"],
  ["GEMINI_API_KEY",       "Google Gemini",      "google"],
  ["XAI_API_KEY",          "xAI",                "xai"],
  ["GROQ_API_KEY",         "Groq",               "groq"],
  ["MISTRAL_API_KEY",      "Mistral",            "mistral"],
  ["CEREBRAS_API_KEY",     "Cerebras",           "cerebras"],
  ["ZAI_API_KEY",          "ZAI",                "zai"],
  ["AI_GATEWAY_API_KEY",   "Vercel AI Gateway",  "vercel-ai-gateway"],
  ["COPILOT_GITHUB_TOKEN", "GitHub Copilot",     "github-copilot"],
];

for (const [envKey, label, providerKey] of builtinProviders) {
  if (process.env[envKey]) {
    console.log(`[configure] ${label} provider enabled (${envKey} set)`);
  }
  // Clean up stale models.providers entries from previous env-var runs —
  // built-in providers must NOT have models.providers entries.
  // But don't touch entries from custom JSON.
  if (!hasCustomConfig && config.models?.providers?.[providerKey]) {
    console.log(`[configure] removing stale models.providers.${providerKey} (built-in, not needed)`);
    delete config.models.providers[providerKey];
  }
}
if (opencodeKey) {
  console.log("[configure] OpenCode provider enabled (OPENCODE_API_KEY set)");
}
if (!hasCustomConfig && config.models?.providers?.opencode) {
  console.log("[configure] removing stale models.providers.opencode (built-in, not needed)");
  delete config.models.providers.opencode;
}

// ── Custom/proxy providers (need full models.providers config) ──────────────

// Venice AI (OpenAI-compatible)
if (process.env.VENICE_API_KEY) {
  console.log("[configure] configuring Venice AI provider");
  ensure(config, "models", "providers");
  config.models.providers.venice = {
    api: "openai-completions",
    apiKey: process.env.VENICE_API_KEY,
    baseUrl: "https://api.venice.ai/api/v1",
    models: [
      { id: "llama-3.3-70b", name: "Llama 3.3 70B", contextWindow: 128000 },
    ],
  };
} else {
  removeProvider("venice", "Venice AI", "VENICE_API_KEY");
}

// MiniMax (Anthropic-compatible)
if (process.env.MINIMAX_API_KEY) {
  console.log("[configure] configuring MiniMax provider");
  ensure(config, "models", "providers");
  config.models.providers.minimax = {
    api: "anthropic-messages",
    apiKey: process.env.MINIMAX_API_KEY,
    baseUrl: "https://api.minimax.io/anthropic",
    models: [
      { id: "MiniMax-M2.1", name: "MiniMax M2.1", contextWindow: 200000 },
    ],
  };
} else {
  removeProvider("minimax", "MiniMax", "MINIMAX_API_KEY");
}

// Moonshot / Kimi (OpenAI-compatible)
if (process.env.MOONSHOT_API_KEY) {
  console.log("[configure] configuring Moonshot provider");
  ensure(config, "models", "providers");
  config.models.providers.moonshot = {
    api: "openai-completions",
    apiKey: process.env.MOONSHOT_API_KEY,
    baseUrl: (process.env.MOONSHOT_BASE_URL || "https://api.moonshot.ai/v1").replace(/\/+$/, ""),
    models: [
      { id: "kimi-k2.5", name: "Kimi K2.5", contextWindow: 128000 },
    ],
  };
} else {
  removeProvider("moonshot", "Moonshot", "MOONSHOT_API_KEY");
}

// Kimi Coding (Anthropic-compatible)
if (process.env.KIMI_API_KEY) {
  console.log("[configure] configuring Kimi Coding provider");
  ensure(config, "models", "providers");
  config.models.providers["kimi-coding"] = {
    api: "anthropic-messages",
    apiKey: process.env.KIMI_API_KEY,
    baseUrl: (process.env.KIMI_BASE_URL || "https://api.moonshot.ai/anthropic").replace(/\/+$/, ""),
    models: [
      { id: "k2p5", name: "Kimi K2P5", contextWindow: 128000 },
    ],
  };
} else {
  removeProvider("kimi-coding", "Kimi Coding", "KIMI_API_KEY");
}

// Synthetic (Anthropic-compatible)
if (process.env.SYNTHETIC_API_KEY) {
  console.log("[configure] configuring Synthetic provider");
  ensure(config, "models", "providers");
  config.models.providers.synthetic = {
    api: "anthropic-messages",
    apiKey: process.env.SYNTHETIC_API_KEY,
    baseUrl: "https://api.synthetic.new/anthropic",
    models: [
      { id: "hf:MiniMaxAI/MiniMax-M2.1", name: "MiniMax M2.1", contextWindow: 192000 },
    ],
  };
} else {
  removeProvider("synthetic", "Synthetic", "SYNTHETIC_API_KEY");
}

// Xiaomi MiMo (Anthropic-compatible)
if (process.env.XIAOMI_API_KEY) {
  console.log("[configure] configuring Xiaomi MiMo provider");
  ensure(config, "models", "providers");
  config.models.providers.xiaomi = {
    api: "anthropic-messages",
    apiKey: process.env.XIAOMI_API_KEY,
    baseUrl: "https://api.xiaomimimo.com/anthropic",
    models: [
      { id: "mimo-v2-flash", name: "MiMo v2 Flash", contextWindow: 262144 },
    ],
  };
} else {
  removeProvider("xiaomi", "Xiaomi", "XIAOMI_API_KEY");
}

// Amazon Bedrock (uses AWS credential chain)
if (process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY) {
  console.log("[configure] configuring Amazon Bedrock provider");
  ensure(config, "models", "providers");
  const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || "us-east-1";
  config.models.providers["amazon-bedrock"] = {
    api: "bedrock-converse-stream",
    baseUrl: `https://bedrock-runtime.${region}.amazonaws.com`,
    models: [
      { id: "anthropic.claude-opus-4-5-20251101-v1:0", name: "Claude Opus 4.5 (Bedrock)", contextWindow: 200000 },
      { id: "anthropic.claude-sonnet-4-5-20250929-v1:0", name: "Claude Sonnet 4.5 (Bedrock)", contextWindow: 200000 },
    ],
  };
  ensure(config, "models");
  // providerFilter must be an array; env var may be JSON array, CSV, or plain string
  let providerFilter = ["anthropic"];
  if (process.env.BEDROCK_PROVIDER_FILTER) {
    try {
      const parsed = JSON.parse(process.env.BEDROCK_PROVIDER_FILTER);
      providerFilter = Array.isArray(parsed) ? parsed : [parsed];
    } catch {
      providerFilter = process.env.BEDROCK_PROVIDER_FILTER.split(",").map(s => s.trim());
    }
  }
  config.models.bedrockDiscovery = {
    enabled: true,
    region,
    providerFilter,
    refreshInterval: 3600,
  };
} else if (!hasCustomConfig && config.models?.providers?.["amazon-bedrock"]) {
  console.log("[configure] removing Amazon Bedrock provider (AWS credentials not set)");
  delete config.models.providers["amazon-bedrock"];
  delete config.models.bedrockDiscovery;
}

// Ollama (local, no API key needed)
const ollamaUrl = (process.env.OLLAMA_BASE_URL || "").replace(/\/+$/, "");
if (ollamaUrl) {
  console.log("[configure] configuring Ollama provider");
  ensure(config, "models", "providers");
  const base = ollamaUrl.endsWith("/v1") ? ollamaUrl : `${ollamaUrl}/v1`;
  config.models.providers.ollama = {
    api: "openai-completions",
    baseUrl: base,
    models: [
      { id: "llama3.3", name: "Llama 3.3", contextWindow: 128000 },
    ],
  };
} else {
  removeProvider("ollama", "Ollama", "OLLAMA_BASE_URL");
}

// KOOMPI AI Gateway (OpenAI-compatible custom provider)
// AI_GATEWAY_API_KEY + AI_GATEWAY_BASE_URL are injected by entrypoint.sh from KCONSOLE_AI_KEY.
// We register it as the "kconsole" custom provider so models are fully qualified as
// kconsole/glm-5-turbo, kconsole/gemini-3-flash-preview, etc.
const kconsoleApiKey = (process.env.AI_GATEWAY_API_KEY || "").trim();
const kconsoleBaseUrl = (process.env.AI_GATEWAY_BASE_URL || "https://ai.koompi.cloud/v1").replace(/\/+$/, "");
if (kconsoleApiKey) {
  console.log("[configure] configuring KOOMPI AI Gateway custom provider at", kconsoleBaseUrl);
  ensure(config, "models", "providers");
  config.models.providers.kconsole = {
    api: "openai-completions",
    baseUrl: kconsoleBaseUrl,
    apiKey: kconsoleApiKey,
    models: [
      { id: "koompiclaw",                 name: "KOOMPI Claw (recommended)",  contextWindow: 128000,  maxTokens: 16384, reasoning: false, input: ["text", "image"], cost: { input: 0.07,  output: 0.07,  cacheRead: 0, cacheWrite: 0 } },
      { id: "glm-5-turbo",                 name: "GLM-5 Turbo (fast, cheap)",   contextWindow: 128000,  maxTokens: 16384, reasoning: false, input: ["text"], cost: { input: 0.07,  output: 0.07,  cacheRead: 0, cacheWrite: 0 } },
      { id: "glm-5",                       name: "GLM-5",                        contextWindow: 128000,  maxTokens: 16384, reasoning: false, input: ["text"], cost: { input: 0.14,  output: 0.14,  cacheRead: 0, cacheWrite: 0 } },
      { id: "gemini-3.1-pro-preview",      name: "Gemini 3.1 Pro",               contextWindow: 1000000, maxTokens: 8192,  reasoning: true,  input: ["text"], cost: { input: 2.00,  output: 12.00, cacheRead: 0, cacheWrite: 0 } },
      { id: "gemini-3-flash-preview",      name: "Gemini 3 Flash",               contextWindow: 1000000, maxTokens: 8192,  reasoning: false, input: ["text"], cost: { input: 0.50,  output: 3.00,  cacheRead: 0, cacheWrite: 0 } },
      { id: "gemini-3.1-flash-lite-preview", name: "Gemini 3.1 Flash Lite",      contextWindow: 1000000, maxTokens: 8192,  reasoning: false, input: ["text"], cost: { input: 0.20,  output: 1.00,  cacheRead: 0, cacheWrite: 0 } },
      { id: "gemini-2.5-flash",            name: "Gemini 2.5 Flash",             contextWindow: 1000000, maxTokens: 8192,  reasoning: false, input: ["text"], cost: { input: 0.30,  output: 2.50,  cacheRead: 0, cacheWrite: 0 } },
    ],
  };
  // Allowlist all models so openclaw will route to them
  ensure(config, "agents", "defaults", "models");
  const kconsoleAllowlist = {
    "kconsole/koompiclaw":                  { alias: "koompiclaw" },
    "kconsole/glm-5-turbo":                 { alias: "glm-5-turbo" },
    "kconsole/glm-5":                       { alias: "glm-5" },
    "kconsole/gemini-3.1-pro-preview":      { alias: "gemini-3.1-pro" },
    "kconsole/gemini-3-flash-preview":      { alias: "gemini-3-flash" },
    "kconsole/gemini-3.1-flash-lite-preview": { alias: "gemini-3.1-flash-lite" },
    "kconsole/gemini-2.5-flash":            { alias: "gemini-2.5-flash" },
  };
  for (const [k, v] of Object.entries(kconsoleAllowlist)) {
    // Don't overwrite if already set (e.g. from custom JSON)
    if (!config.agents.defaults.models[k]) {
      config.agents.defaults.models[k] = v;
    }
  }
} else {
  removeProvider("kconsole", "KOOMPI AI Gateway", "AI_GATEWAY_API_KEY");
}

// ── Primary model selection (first available provider wins) ─────────────────
const primaryCandidates = [
  [process.env.ANTHROPIC_API_KEY,      "anthropic/claude-opus-4-5-20251101"],
  [process.env.OPENAI_API_KEY,         "openai/gpt-5.2"],
  [process.env.OPENROUTER_API_KEY,     "openrouter/anthropic/claude-opus-4-5"],
  [process.env.GEMINI_API_KEY,         "google/gemini-3-pro"],
  [opencodeKey,                        "opencode/claude-opus-4-5"],
  [process.env.COPILOT_GITHUB_TOKEN,   "github-copilot/claude-opus-4-5"],
  [process.env.XAI_API_KEY,            "xai/grok-3"],
  [process.env.GROQ_API_KEY,           "groq/llama-3.3-70b-versatile"],
  [process.env.MISTRAL_API_KEY,        "mistral/mistral-large-latest"],
  [process.env.CEREBRAS_API_KEY,       "cerebras/llama-3.3-70b"],
  [process.env.VENICE_API_KEY,         "venice/llama-3.3-70b"],
  [process.env.MOONSHOT_API_KEY,       "moonshot/kimi-k2.5"],
  [process.env.KIMI_API_KEY,           "kimi-coding/k2p5"],
  [process.env.MINIMAX_API_KEY,        "minimax/MiniMax-M2.1"],
  [process.env.SYNTHETIC_API_KEY,      "synthetic/hf:MiniMaxAI/MiniMax-M2.1"],
  [process.env.ZAI_API_KEY,            "zai/glm-4.7"],
  [kconsoleApiKey,                     "kconsole/koompiclaw"],
  [process.env.XIAOMI_API_KEY,         "xiaomi/mimo-v2-flash"],
  [process.env.AWS_ACCESS_KEY_ID,      "amazon-bedrock/anthropic.claude-opus-4-5-20251101-v1:0"],
  [ollamaUrl,                          "ollama/llama3.3"],
];
if (process.env.OPENCLAW_PRIMARY_MODEL) {
  // Explicit env var override
  config.agents.defaults.model.primary = process.env.OPENCLAW_PRIMARY_MODEL;
  console.log(`[configure] primary model (override): ${process.env.OPENCLAW_PRIMARY_MODEL}`);
} else if (config.agents.defaults.model.primary) {
  // Already set (from custom JSON or persisted config) — keep it
  console.log(`[configure] primary model (from config): ${config.agents.defaults.model.primary}`);
} else {
  // Auto-select from first available provider
  for (const [key, model] of primaryCandidates) {
    if (key) {
      config.agents.defaults.model.primary = model;
      console.log(`[configure] primary model (auto): ${model}`);
      break;
    }
  }
}

// ── Deepgram (audio transcription) ──────────────────────────────────────────
if (process.env.DEEPGRAM_API_KEY) {
  console.log("[configure] configuring Deepgram transcription (from env)");
  ensure(config, "tools", "media", "audio");
  config.tools.media.audio.enabled = true;
  config.tools.media.audio.models = [{ provider: "deepgram", model: "nova-3" }];
} else if (config.tools?.media?.audio) {
  console.log("[configure] Deepgram transcription configured (from custom JSON)");
}

// ── Channels ────────────────────────────────────────────────────────────────
// Env vars override custom JSON values. If neither env var nor custom JSON
// provides a channel, it stays unconfigured. We never remove channels that
// came from the custom JSON.

// ── Memory search / memory-lancedb-pro plugin ────────────────────────────────
// Uses memory-lancedb-pro (not the built-in memory-lancedb or memorySearch).
// memory-lancedb-pro supports provider: "openai-compatible" so any model name
// works with any baseURL — no hardcoded model allowlist.
// Features: hybrid retrieval (vector + BM25), cross-encoder reranking, smart
// extraction, Weibull decay, noise filtering, multi-scope isolation.
// Set OPENCLAW_MEMORY_SEARCH=false to disable even when the key is present.
if (kconsoleApiKey && process.env.OPENCLAW_MEMORY_SEARCH !== "false") {
  // Ensure plugin load path is registered (npm install at /app/plugins/)
  ensure(config, "plugins", "load");
  config.plugins.load.paths = config.plugins.load.paths || [];
  const proPluginPath = "/app/plugins/node_modules/memory-lancedb-pro";
  if (!config.plugins.load.paths.includes(proPluginPath)) {
    config.plugins.load.paths.push(proPluginPath);
  }

  ensure(config, "plugins", "entries");
  // Remove old built-in memory-lancedb config if present (migration)
  if (config.plugins.entries["memory-lancedb"]) {
    delete config.plugins.entries["memory-lancedb"];
    console.log("[configure] migrating from memory-lancedb → memory-lancedb-pro");
  }

  const pro = config.plugins.entries["memory-lancedb-pro"] =
    config.plugins.entries["memory-lancedb-pro"] || {};
  pro.enabled = true;
  pro.config = pro.config || {};

  // Embedding: use KOOMPI AI Gateway with OpenAI-compatible protocol.
  // text-embedding-3-small → our gateway maps to gemini-embedding-001 @ 1536d.
  pro.config.embedding = {
    provider: "openai-compatible",
    apiKey: kconsoleApiKey,
    baseURL: kconsoleBaseUrl,
    model: "text-embedding-3-small",
    dimensions: 1536,
  };

  // Smart extraction LLM: use cheapest model on our gateway
  pro.config.llm = pro.config.llm || {};
  if (!pro.config.llm.apiKey) pro.config.llm.apiKey = kconsoleApiKey;
  if (!pro.config.llm.baseURL) pro.config.llm.baseURL = kconsoleBaseUrl;
  if (!pro.config.llm.model)   pro.config.llm.model = "koompiclaw";

  // Sensible defaults (don't overwrite user customizations)
  if (pro.config.autoCapture       === undefined) pro.config.autoCapture = true;
  if (pro.config.autoRecall        === undefined) pro.config.autoRecall = true;
  if (pro.config.smartExtraction   === undefined) pro.config.smartExtraction = true;
  if (pro.config.extractMinMessages === undefined) pro.config.extractMinMessages = 2;
  if (pro.config.extractMaxChars   === undefined) pro.config.extractMaxChars = 8000;
  if (pro.config.sessionMemory     === undefined) pro.config.sessionMemory = { enabled: false };

  ensure(config, "plugins", "slots");
  config.plugins.slots.memory = "memory-lancedb-pro";

  // Enable memorySearch so the agent proactively searches memories via
  // memory_recall tool.  memory-lancedb-pro intercepts memory_recall and
  // routes it through its own LanceDB backend (1536d embeddings via our
  // gateway), so there is no conflict with the built-in 384d local search.
  // Without this, the plugin stores memories but the agent never searches them.
  ensure(config, "agents", "defaults", "memorySearch");
  config.agents.defaults.memorySearch.enabled = true;

  console.log("[configure] memory search enabled → memory-lancedb-pro via KOOMPI AI Gateway");
  console.log("[configure]   embedding: text-embedding-3-small @ 1536d (→ gemini-embedding-001)");
  console.log("[configure]   smart extraction LLM: koompiclaw");
  console.log("[configure]   autoCapture: true, autoRecall: true, smartExtraction: true");
} else {
  ensure(config, "agents", "defaults", "memorySearch");
  config.agents.defaults.memorySearch.enabled = false;
  const reason = !kconsoleApiKey ? "no AI_GATEWAY_API_KEY" : "OPENCLAW_MEMORY_SEARCH=false";
  console.log(`[configure] memory search disabled (${reason})`);
}

if (process.env.TELEGRAM_BOT_TOKEN) {
  console.log("[configure] configuring Telegram channel (from env)");
  ensure(config, "channels");
  const tg = config.channels.telegram = config.channels.telegram || {};
  tg.botToken = process.env.TELEGRAM_BOT_TOKEN;
  tg.enabled = true;

  // strings
  if (process.env.TELEGRAM_DM_POLICY)              tg.dmPolicy = process.env.TELEGRAM_DM_POLICY;
  if (process.env.TELEGRAM_GROUP_POLICY)            tg.groupPolicy = process.env.TELEGRAM_GROUP_POLICY;
  if (process.env.TELEGRAM_REPLY_TO_MODE)           tg.replyToMode = process.env.TELEGRAM_REPLY_TO_MODE;
  if (process.env.TELEGRAM_CHUNK_MODE)              tg.chunkMode = process.env.TELEGRAM_CHUNK_MODE;
  if (process.env.TELEGRAM_STREAM_MODE)             tg.streamMode = process.env.TELEGRAM_STREAM_MODE;
  if (process.env.TELEGRAM_REACTION_NOTIFICATIONS)  tg.reactionNotifications = process.env.TELEGRAM_REACTION_NOTIFICATIONS;
  if (process.env.TELEGRAM_REACTION_LEVEL)          tg.reactionLevel = process.env.TELEGRAM_REACTION_LEVEL;
  if (process.env.TELEGRAM_PROXY)                   tg.proxy = process.env.TELEGRAM_PROXY;
  if (process.env.TELEGRAM_WEBHOOK_URL)             tg.webhookUrl = process.env.TELEGRAM_WEBHOOK_URL;
  if (process.env.TELEGRAM_WEBHOOK_SECRET)          tg.webhookSecret = process.env.TELEGRAM_WEBHOOK_SECRET;
  if (process.env.TELEGRAM_WEBHOOK_PATH)            tg.webhookPath = process.env.TELEGRAM_WEBHOOK_PATH;
  if (process.env.TELEGRAM_MESSAGE_PREFIX)          tg.messagePrefix = process.env.TELEGRAM_MESSAGE_PREFIX;

  // booleans
  if (process.env.TELEGRAM_LINK_PREVIEW)            tg.linkPreview = process.env.TELEGRAM_LINK_PREVIEW !== "false";
  if (process.env.TELEGRAM_ACTIONS_REACTIONS)  {
    ensure(tg, "actions");
    tg.actions.reactions = process.env.TELEGRAM_ACTIONS_REACTIONS !== "false";
  }
  if (process.env.TELEGRAM_ACTIONS_STICKER)    {
    ensure(tg, "actions");
    tg.actions.sticker = process.env.TELEGRAM_ACTIONS_STICKER === "true";
  }

  // numbers
  if (process.env.TELEGRAM_TEXT_CHUNK_LIMIT)        tg.textChunkLimit = parseInt(process.env.TELEGRAM_TEXT_CHUNK_LIMIT, 10);
  if (process.env.TELEGRAM_MEDIA_MAX_MB)            tg.mediaMaxMb = parseInt(process.env.TELEGRAM_MEDIA_MAX_MB, 10);

  // csv → array (user IDs as integers, usernames as strings)
  // Merge: env var TELEGRAM_ALLOW_FROM + persistent file /data/config/telegram-allow.txt
  // The file survives container restarts; the agent can edit it and run oc-reload.
  {
    const parts = [];
    if (process.env.TELEGRAM_ALLOW_FROM) {
      parts.push(...process.env.TELEGRAM_ALLOW_FROM.split(","));
    }
    try {
      const filePath = "/data/config/telegram-allow.txt";
      const fileContent = require("fs").readFileSync(filePath, "utf8");
      const fileIds = fileContent.split(/[\n,]/).map(s => s.trim()).filter(Boolean).filter(s => !s.startsWith("#"));
      if (fileIds.length > 0) {
        parts.push(...fileIds);
        console.log(`[configure] merged ${fileIds.length} Telegram user(s) from ${filePath}`);
      }
    } catch { /* file doesn't exist yet — that's fine */ }
    if (parts.length > 0) {
      const unique = [...new Set(parts.map(s => s.trim()).filter(Boolean))];
      tg.allowFrom = unique.map(s => {
        const num = Number(s);
        return Number.isInteger(num) ? num : s;
      });
    }
  }
  if (process.env.TELEGRAM_GROUP_ALLOW_FROM) {
    tg.groupAllowFrom = process.env.TELEGRAM_GROUP_ALLOW_FROM.split(",").map(s => {
      const trimmed = s.trim();
      const num = Number(trimmed);
      return Number.isInteger(num) ? num : trimmed;
    });
  }

  // nested: capabilities
  if (process.env.TELEGRAM_INLINE_BUTTONS) {
    ensure(tg, "capabilities");
    tg.capabilities.inlineButtons = process.env.TELEGRAM_INLINE_BUTTONS;
  }
} else if (config.channels?.telegram) {
  console.log("[configure] Telegram channel configured (from custom JSON)");
}

if (process.env.DISCORD_BOT_TOKEN) {
  console.log("[configure] configuring Discord channel (from env)");
  ensure(config, "channels");
  const dc = config.channels.discord = config.channels.discord || {};
  dc.token = process.env.DISCORD_BOT_TOKEN;
  dc.enabled = true;

  // strings
  if (process.env.DISCORD_DM_POLICY)              { ensure(dc, "dm"); dc.dm.policy = process.env.DISCORD_DM_POLICY; }
  if (process.env.DISCORD_GROUP_POLICY)            dc.groupPolicy = process.env.DISCORD_GROUP_POLICY;
  if (process.env.DISCORD_REPLY_TO_MODE)           dc.replyToMode = process.env.DISCORD_REPLY_TO_MODE;
  if (process.env.DISCORD_CHUNK_MODE)              dc.chunkMode = process.env.DISCORD_CHUNK_MODE;
  if (process.env.DISCORD_REACTION_NOTIFICATIONS)  dc.reactionNotifications = process.env.DISCORD_REACTION_NOTIFICATIONS;
  if (process.env.DISCORD_MESSAGE_PREFIX)           dc.messagePrefix = process.env.DISCORD_MESSAGE_PREFIX;

  // booleans (default-true → !== "false", default-false → === "true")
  if (process.env.DISCORD_ALLOW_BOTS)              dc.allowBots = process.env.DISCORD_ALLOW_BOTS === "true";
  if (process.env.DISCORD_ACTIONS_REACTIONS)        { ensure(dc, "actions"); dc.actions.reactions = process.env.DISCORD_ACTIONS_REACTIONS !== "false"; }
  if (process.env.DISCORD_ACTIONS_STICKERS)         { ensure(dc, "actions"); dc.actions.stickers = process.env.DISCORD_ACTIONS_STICKERS !== "false"; }
  if (process.env.DISCORD_ACTIONS_EMOJI_UPLOADS)    { ensure(dc, "actions"); dc.actions.emojiUploads = process.env.DISCORD_ACTIONS_EMOJI_UPLOADS !== "false"; }
  if (process.env.DISCORD_ACTIONS_STICKER_UPLOADS)  { ensure(dc, "actions"); dc.actions.stickerUploads = process.env.DISCORD_ACTIONS_STICKER_UPLOADS !== "false"; }
  if (process.env.DISCORD_ACTIONS_POLLS)            { ensure(dc, "actions"); dc.actions.polls = process.env.DISCORD_ACTIONS_POLLS !== "false"; }
  if (process.env.DISCORD_ACTIONS_PERMISSIONS)      { ensure(dc, "actions"); dc.actions.permissions = process.env.DISCORD_ACTIONS_PERMISSIONS !== "false"; }
  if (process.env.DISCORD_ACTIONS_MESSAGES)         { ensure(dc, "actions"); dc.actions.messages = process.env.DISCORD_ACTIONS_MESSAGES !== "false"; }
  if (process.env.DISCORD_ACTIONS_THREADS)          { ensure(dc, "actions"); dc.actions.threads = process.env.DISCORD_ACTIONS_THREADS !== "false"; }
  if (process.env.DISCORD_ACTIONS_PINS)             { ensure(dc, "actions"); dc.actions.pins = process.env.DISCORD_ACTIONS_PINS !== "false"; }
  if (process.env.DISCORD_ACTIONS_SEARCH)           { ensure(dc, "actions"); dc.actions.search = process.env.DISCORD_ACTIONS_SEARCH !== "false"; }
  if (process.env.DISCORD_ACTIONS_MEMBER_INFO)      { ensure(dc, "actions"); dc.actions.memberInfo = process.env.DISCORD_ACTIONS_MEMBER_INFO !== "false"; }
  if (process.env.DISCORD_ACTIONS_ROLE_INFO)        { ensure(dc, "actions"); dc.actions.roleInfo = process.env.DISCORD_ACTIONS_ROLE_INFO !== "false"; }
  if (process.env.DISCORD_ACTIONS_CHANNEL_INFO)     { ensure(dc, "actions"); dc.actions.channelInfo = process.env.DISCORD_ACTIONS_CHANNEL_INFO !== "false"; }
  if (process.env.DISCORD_ACTIONS_CHANNELS)         { ensure(dc, "actions"); dc.actions.channels = process.env.DISCORD_ACTIONS_CHANNELS !== "false"; }
  if (process.env.DISCORD_ACTIONS_VOICE_STATUS)     { ensure(dc, "actions"); dc.actions.voiceStatus = process.env.DISCORD_ACTIONS_VOICE_STATUS !== "false"; }
  if (process.env.DISCORD_ACTIONS_EVENTS)           { ensure(dc, "actions"); dc.actions.events = process.env.DISCORD_ACTIONS_EVENTS !== "false"; }
  if (process.env.DISCORD_ACTIONS_ROLES)            { ensure(dc, "actions"); dc.actions.roles = process.env.DISCORD_ACTIONS_ROLES === "true"; }
  if (process.env.DISCORD_ACTIONS_MODERATION)       { ensure(dc, "actions"); dc.actions.moderation = process.env.DISCORD_ACTIONS_MODERATION === "true"; }

  // numbers
  if (process.env.DISCORD_TEXT_CHUNK_LIMIT)         dc.textChunkLimit = parseInt(process.env.DISCORD_TEXT_CHUNK_LIMIT, 10);
  if (process.env.DISCORD_MAX_LINES_PER_MESSAGE)    dc.maxLinesPerMessage = parseInt(process.env.DISCORD_MAX_LINES_PER_MESSAGE, 10);
  if (process.env.DISCORD_MEDIA_MAX_MB)             dc.mediaMaxMb = parseInt(process.env.DISCORD_MEDIA_MAX_MB, 10);
  if (process.env.DISCORD_HISTORY_LIMIT)            dc.historyLimit = parseInt(process.env.DISCORD_HISTORY_LIMIT, 10);
  if (process.env.DISCORD_DM_HISTORY_LIMIT)         dc.dmHistoryLimit = parseInt(process.env.DISCORD_DM_HISTORY_LIMIT, 10);

  // csv → array (always strings)
  if (process.env.DISCORD_DM_ALLOW_FROM) {
    ensure(dc, "dm");
    dc.dm.allowFrom = process.env.DISCORD_DM_ALLOW_FROM.split(",").map(s => s.trim());
  }
} else if (config.channels?.discord) {
  console.log("[configure] Discord channel configured (from custom JSON)");
}

if (process.env.SLACK_BOT_TOKEN && process.env.SLACK_APP_TOKEN) {
  console.log("[configure] configuring Slack channel (from env)");
  ensure(config, "channels");
  const sl = config.channels.slack = config.channels.slack || {};
  sl.botToken = process.env.SLACK_BOT_TOKEN;
  sl.appToken = process.env.SLACK_APP_TOKEN;
  sl.enabled = true;

  // strings
  if (process.env.SLACK_USER_TOKEN)              sl.userToken = process.env.SLACK_USER_TOKEN;
  if (process.env.SLACK_SIGNING_SECRET)          sl.signingSecret = process.env.SLACK_SIGNING_SECRET;
  if (process.env.SLACK_MODE)                    sl.mode = process.env.SLACK_MODE;
  if (process.env.SLACK_WEBHOOK_PATH)            sl.webhookPath = process.env.SLACK_WEBHOOK_PATH;
  if (process.env.SLACK_DM_POLICY)               { ensure(sl, "dm"); sl.dm.policy = process.env.SLACK_DM_POLICY; }
  if (process.env.SLACK_GROUP_POLICY)            sl.groupPolicy = process.env.SLACK_GROUP_POLICY;
  if (process.env.SLACK_REPLY_TO_MODE)           sl.replyToMode = process.env.SLACK_REPLY_TO_MODE;
  if (process.env.SLACK_REACTION_NOTIFICATIONS)  sl.reactionNotifications = process.env.SLACK_REACTION_NOTIFICATIONS;
  if (process.env.SLACK_CHUNK_MODE)              sl.chunkMode = process.env.SLACK_CHUNK_MODE;
  if (process.env.SLACK_MESSAGE_PREFIX)          sl.messagePrefix = process.env.SLACK_MESSAGE_PREFIX;

  // booleans (default-true → !== "false", default-false → === "true")
  if (process.env.SLACK_ALLOW_BOTS)              sl.allowBots = process.env.SLACK_ALLOW_BOTS === "true";
  if (process.env.SLACK_ACTIONS_REACTIONS)        { ensure(sl, "actions"); sl.actions.reactions = process.env.SLACK_ACTIONS_REACTIONS !== "false"; }
  if (process.env.SLACK_ACTIONS_MESSAGES)         { ensure(sl, "actions"); sl.actions.messages = process.env.SLACK_ACTIONS_MESSAGES !== "false"; }
  if (process.env.SLACK_ACTIONS_PINS)             { ensure(sl, "actions"); sl.actions.pins = process.env.SLACK_ACTIONS_PINS !== "false"; }
  if (process.env.SLACK_ACTIONS_MEMBER_INFO)      { ensure(sl, "actions"); sl.actions.memberInfo = process.env.SLACK_ACTIONS_MEMBER_INFO !== "false"; }
  if (process.env.SLACK_ACTIONS_EMOJI_LIST)       { ensure(sl, "actions"); sl.actions.emojiList = process.env.SLACK_ACTIONS_EMOJI_LIST !== "false"; }

  // numbers
  if (process.env.SLACK_HISTORY_LIMIT)           sl.historyLimit = parseInt(process.env.SLACK_HISTORY_LIMIT, 10);
  if (process.env.SLACK_TEXT_CHUNK_LIMIT)        sl.textChunkLimit = parseInt(process.env.SLACK_TEXT_CHUNK_LIMIT, 10);
  if (process.env.SLACK_MEDIA_MAX_MB)            sl.mediaMaxMb = parseInt(process.env.SLACK_MEDIA_MAX_MB, 10);

  // csv → array (always strings)
  if (process.env.SLACK_DM_ALLOW_FROM) {
    ensure(sl, "dm");
    sl.dm.allowFrom = process.env.SLACK_DM_ALLOW_FROM.split(",").map(s => s.trim());
  }
} else if (config.channels?.slack) {
  console.log("[configure] Slack channel configured (from custom JSON)");
}

// WhatsApp (no bot token — uses QR/pairing code auth at runtime)
if (process.env.WHATSAPP_ENABLED === "true" || process.env.WHATSAPP_ENABLED === "1") {
  console.log("[configure] configuring WhatsApp channel (from env)");
  ensure(config, "channels");
  const wa = config.channels.whatsapp = {}; // full overwrite — env vars are authoritative

  // strings
  if (process.env.WHATSAPP_DM_POLICY)        wa.dmPolicy = process.env.WHATSAPP_DM_POLICY;
  if (process.env.WHATSAPP_GROUP_POLICY)      wa.groupPolicy = process.env.WHATSAPP_GROUP_POLICY;
  if (process.env.WHATSAPP_MESSAGE_PREFIX)    wa.messagePrefix = process.env.WHATSAPP_MESSAGE_PREFIX;

  // booleans
  if (process.env.WHATSAPP_SELF_CHAT_MODE)    wa.selfChatMode = process.env.WHATSAPP_SELF_CHAT_MODE === "true";
  if (process.env.WHATSAPP_SEND_READ_RECEIPTS) wa.sendReadReceipts = process.env.WHATSAPP_SEND_READ_RECEIPTS !== "false";
  if (process.env.WHATSAPP_ACTIONS_REACTIONS) {
    ensure(wa, "actions");
    wa.actions.reactions = process.env.WHATSAPP_ACTIONS_REACTIONS !== "false";
  }

  // numbers
  if (process.env.WHATSAPP_MEDIA_MAX_MB)      wa.mediaMaxMb = parseInt(process.env.WHATSAPP_MEDIA_MAX_MB, 10);
  if (process.env.WHATSAPP_HISTORY_LIMIT)     wa.historyLimit = parseInt(process.env.WHATSAPP_HISTORY_LIMIT, 10);
  if (process.env.WHATSAPP_DM_HISTORY_LIMIT)  wa.dmHistoryLimit = parseInt(process.env.WHATSAPP_DM_HISTORY_LIMIT, 10);

  // csv → array (E.164 phone numbers, always strings)
  if (process.env.WHATSAPP_ALLOW_FROM)        wa.allowFrom = process.env.WHATSAPP_ALLOW_FROM.split(",").map(s => s.trim());
  if (process.env.WHATSAPP_GROUP_ALLOW_FROM)  wa.groupAllowFrom = process.env.WHATSAPP_GROUP_ALLOW_FROM.split(",").map(s => s.trim());

  // ack reaction (nested object)
  if (process.env.WHATSAPP_ACK_REACTION_EMOJI || process.env.WHATSAPP_ACK_REACTION_DIRECT || process.env.WHATSAPP_ACK_REACTION_GROUP) {
    wa.ackReaction = wa.ackReaction || {};
    if (process.env.WHATSAPP_ACK_REACTION_EMOJI)  wa.ackReaction.emoji = process.env.WHATSAPP_ACK_REACTION_EMOJI;
    if (process.env.WHATSAPP_ACK_REACTION_DIRECT) wa.ackReaction.direct = process.env.WHATSAPP_ACK_REACTION_DIRECT !== "false";
    if (process.env.WHATSAPP_ACK_REACTION_GROUP)  wa.ackReaction.group = process.env.WHATSAPP_ACK_REACTION_GROUP;
  }
} else if (config.channels?.whatsapp) {
  console.log("[configure] WhatsApp channel configured (from custom JSON)");
}

// Clean up empty channels object (from previous config versions)
if (config.channels && Object.keys(config.channels).length === 0) {
  delete config.channels;
}

// ── Hooks (webhook automation) ───────────────────────────────────────────────
if (process.env.HOOKS_ENABLED === "true" || process.env.HOOKS_ENABLED === "1") {
  console.log("[configure] configuring hooks (from env)");
  ensure(config, "hooks");
  config.hooks.enabled = true;
  if (process.env.HOOKS_TOKEN) config.hooks.token = process.env.HOOKS_TOKEN;
  if (process.env.HOOKS_PATH)  config.hooks.path = process.env.HOOKS_PATH;
} else if (config.hooks) {
  console.log("[configure] hooks configured (from custom JSON)");
}

// ── Browser tool (remote CDP) ────────────────────────────────────────────────
if (process.env.BROWSER_CDP_URL) {
  console.log("[configure] configuring browser tool (remote CDP)");
  ensure(config, "browser");
  const br = config.browser;
  br.cdpUrl = process.env.BROWSER_CDP_URL;

  if (process.env.BROWSER_EVALUATE_ENABLED !== undefined)
    br.evaluateEnabled = process.env.BROWSER_EVALUATE_ENABLED === "true";
  if (process.env.BROWSER_SNAPSHOT_MODE) {
    ensure(br, "snapshotDefaults");
    br.snapshotDefaults.mode = process.env.BROWSER_SNAPSHOT_MODE;
  }
  if (process.env.BROWSER_REMOTE_TIMEOUT_MS)
    br.remoteCdpTimeoutMs = parseInt(process.env.BROWSER_REMOTE_TIMEOUT_MS, 10);
  if (process.env.BROWSER_REMOTE_HANDSHAKE_TIMEOUT_MS)
    br.remoteCdpHandshakeTimeoutMs = parseInt(process.env.BROWSER_REMOTE_HANDSHAKE_TIMEOUT_MS, 10);
  if (process.env.BROWSER_DEFAULT_PROFILE)
    br.defaultProfile = process.env.BROWSER_DEFAULT_PROFILE;
} else if (config.browser) {
  console.log("[configure] browser configured (from custom JSON)");
}

// ── Dynamic Configuration (dot-notation, allowed origins, JSON) ─────────────

/**
 * Applies dot-notation environment variables to the config object.
 * Format: OPENCLAW__path__to__key=value
 * Arrays: suffix with [] and use comma-separated values
 */
function applyDotNotationEnvVars() {
  for (const [key, value] of Object.entries(process.env)) {
    if (!key?.startsWith(ENV_VAR.DOT_NOTATION_PREFIX) || !value) {
      continue;
    }

    const isArray = key.endsWith(ENV_VAR.ARRAY_SUFFIX);
    const pathPart = isArray
      ? key.slice(ENV_VAR.DOT_NOTATION_PREFIX.length, -ENV_VAR.ARRAY_SUFFIX.length)
      : key.slice(ENV_VAR.DOT_NOTATION_PREFIX.length);

    const pathSegments = pathPart.split('__').filter(Boolean);
    if (pathSegments.length === 0) {
      continue;
    }

    // Guard against prototype pollution
    if (pathSegments.some(s => UNSAFE_KEYS.has(s))) {
      console.warn(`[configure] dot-notation: skipping unsafe key in ${key}`);
      continue;
    }

    // Navigate/create nested path
    let target = config;
    for (let i = 0; i < pathSegments.length - 1; i++) {
      const segment = pathSegments[i];
      if (!target[segment] || typeof target[segment] !== 'object' || Array.isArray(target[segment])) {
        target[segment] = {};
      }
      target = target[segment];
    }

    const finalKey = pathSegments[pathSegments.length - 1];
    target[finalKey] = isArray ? parseArrayValue(value) : coerceType(value);

    console.log(
      `[configure] dot-notation: ${key} → ${pathSegments.join('.')}${isArray ? ' (array)' : ''}`
    );
  }
}

/**
 * Applies allowed origins configuration from environment variable.
 */
function applyAllowedOrigins() {
  let origins = [];

  const rawValue = process.env.OPENCLAW_ALLOWED_ORIGINS;
  if (rawValue) {
    try {
      origins = parseAllowedOrigins(rawValue);
    } catch (error) {
      console.error('[configure] ERROR: OPENCLAW_ALLOWED_ORIGINS:', error.message);
      console.error('[configure]   Expected: comma-separated URLs or JSON array');
      console.error("[configure]   Example: 'http://localhost:5173,https://app.com'");
      console.error("[configure]   Example: '[\"http://localhost:5173\"]'");
      process.exit(EXIT_CODE.INVALID_CONFIG);
    }
  }

  // Automatically inject Coolify's FQDN if we are running in a Coolify environment
  const rawFqdn = process.env.COOLIFY_FQDN || process.env.COOLIFY_URL;
  if (rawFqdn) {
    const cleanFqdn = rawFqdn.replace(/\/+$/, "");
    if (cleanFqdn && !origins.includes(cleanFqdn)) {
      origins.push(cleanFqdn);
      console.log(`[configure] injected Coolify origin: ${cleanFqdn}`);
    }
  }

  if (origins.length > 0) {
    ensure(config, 'gateway', 'controlUi');
    config.gateway.controlUi.allowedOrigins = origins;
    console.log(`[configure] allowed origins: ${JSON.stringify(origins)}`);
  }
}

/**
 * Applies JSON configuration from environment variable.
 * Parsed AFTER dot-notation vars, so it can override them.
 */
function applyJsonConfig() {
  const rawValue = process.env.OPENCLAW_CONFIG_JSON;
  if (!rawValue) {
    return;
  }

  try {
    const jsonConfig = JSON.parse(rawValue);

    if (typeof jsonConfig !== 'object' || jsonConfig === null || Array.isArray(jsonConfig)) {
      throw new Error('must be a JSON object (not an array or primitive)');
    }

    deepMerge(config, jsonConfig);
    console.log('[configure] merged OPENCLAW_CONFIG_JSON');
  } catch (error) {
    console.error('[configure] ERROR: OPENCLAW_CONFIG_JSON:', error.message);
    process.exit(EXIT_CODE.INVALID_CONFIG);
  }
}

// ── Execute Configuration Parsers ───────────────────────────────────────────

applyDotNotationEnvVars();
applyAllowedOrigins();
applyJsonConfig();

// ── Validate: at least one provider API key env var must be set ──────────────
// All providers (built-in and custom) read API keys from env vars, not from JSON.
const hasProvider =
  builtinProviders.some(([envKey]) => process.env[envKey]) ||
  !!opencodeKey ||
  !!(process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY) ||
  !!ollamaUrl ||
  // Custom proxy providers also need env var keys
  !!process.env.VENICE_API_KEY || !!process.env.MINIMAX_API_KEY ||
  !!process.env.MOONSHOT_API_KEY || !!process.env.KIMI_API_KEY ||
  !!process.env.SYNTHETIC_API_KEY || !!process.env.XIAOMI_API_KEY;

if (!hasProvider) {
  console.error("[configure] ERROR: No AI provider API key set.");
  console.error("[configure] Providers require an env var — API keys are never read from the JSON config.");
  console.error("[configure] Set one of: ANTHROPIC_API_KEY, OPENAI_API_KEY, OPENROUTER_API_KEY, GEMINI_API_KEY,");
  console.error("[configure]   XAI_API_KEY, GROQ_API_KEY, MISTRAL_API_KEY, CEREBRAS_API_KEY, ZAI_API_KEY,");
  console.error("[configure]   AI_GATEWAY_API_KEY, OPENCODE_API_KEY, COPILOT_GITHUB_TOKEN, VENICE_API_KEY,");
  console.error("[configure]   MOONSHOT_API_KEY, KIMI_API_KEY, MINIMAX_API_KEY, SYNTHETIC_API_KEY, XIAOMI_API_KEY,");
  console.error("[configure]   AWS_ACCESS_KEY_ID+AWS_SECRET_ACCESS_KEY (Bedrock), or OLLAMA_BASE_URL (local)");
  process.exit(1);
}

// ── Disable container-hostile plugins ───────────────────────────────────────
// Bonjour: tries mDNS/Zeroconf advertising on the local network. Always fails
// in containers with "CIAO ANNOUNCEMENT CANCELLED" unhandled rejections.
// Useless in a cloud environment — disable unless explicitly opted in.
if (process.env.OPENCLAW_ENABLE_BONJOUR !== "true") {
  ensure(config, "plugins", "entries");
  config.plugins.entries["bonjour"] = config.plugins.entries["bonjour"] || {};
  config.plugins.entries["bonjour"].enabled = false;
  console.log("[configure] bonjour plugin disabled (set OPENCLAW_ENABLE_BONJOUR=true to re-enable)");
}

// ── Write config ────────────────────────────────────────────────────────────

fs.mkdirSync(path.dirname(CONFIG_FILE), { recursive: true });
fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
console.log("[configure] config written to", CONFIG_FILE);
