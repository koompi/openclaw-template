# Customer Service Agent (Telegram Bot)

> Build an AI-powered customer service bot for your Riverbase shop using OpenClaw multi-agent routing. The bot answers product questions, recommends items, and redirects to the mini app for purchases — all **without any admin token**.

---

## Architecture Overview

```
Telegram Bot (@YourShopBot)
├── Agent: "main" (shop owner only)
│   ├── Full tool access (exec, read, write, admin APIs)
│   ├── Manages products, orders, settings
│   └── allowFrom: [owner_telegram_id]
│
└── Agent: "shop-cs" (customers)
    ├── System prompt: shop assistant persona
    ├── Tools: message, web_fetch only
    ├── No tokens, no exec, no file access
    ├── Queries products via PUBLIC Riverbase API
    └── Redirects to mini app for purchases
```

### Security Model

| Layer | What it protects |
|---|---|
| **OpenClaw tool restriction** | CS agent has no `exec`, `read`, `write`, `edit`, `gateway`, `cron`, `config` — cannot run commands or modify files |
| **No admin token** | CS agent never receives any API token — public API only |
| **Public API only** | Riverbase's storefront GraphQL queries (`getSection`, `getCategoriesByShop`, `shopId`) are read-only by design |
| **Riverbase server-side** | Even if someone obtained a customer JWT, they can only do user-level operations |
| **Separate workspace** | CS agent has its own workspace — no access to owner's files, memories, or config |

---

## Public Riverbase API (No Auth Required)

All queries below work with `Authorization: null` header. They are the same queries the storefront frontend uses.

### GraphQL Endpoint
```
POST https://api.riverbase.org/graphql
Authorization: null
Content-Type: application/json
```

### Get Shop Info
```graphql
query ShopInfo($shopId: String!) {
  shopId(shopId: $shopId) {
    id name logo
  }
}
```

### Get All Categories
```graphql
query Categories($shopId: String!) {
  getCategoriesByShop(shopId: $shopId) {
    id name description
  }
}
```

### Get All Brands
```graphql
query Brands($shopId: String!) {
  getBrandsByShop(shopId: $shopId) {
    id name
  }
}
```

### Get All Page Sections (Home, Products, etc.)
```graphql
query PageSections($shopId: String!, $page: String!) {
  getPageSections(shopId: $shopId, page: $page) {
    id name page dataType layout showTitle
  }
}
```
- `$page` values: `"home"`, `"products"`, etc.

### Get Products by Section
```graphql
query SectionProducts($sectionId: String!, $skip: Int) {
  getSection(sectionId: $sectionId) {
    id name page dataType showTitle
    products(skip: $skip) {
      totalDocuments
      data {
        id name description price images
        stockBalance onSale archived
        options { id name values { id name extraAmount image } }
        variants { id sku price images active stockBalance variantAttributes { attributeName value } }
        category { id name }
        tags
      }
    }
  }
}
```

### Search Products (Public)
```graphql
query ProductSearch($shopId: String!, $keyword: String) {
  productSearch(shopId: $shopId, keyword: $keyword) {
    id name description price images onSale stockBalance
  }
}
```

### Get Theme
```graphql
query Theme($shopId: String!) {
  themeByShop(shopId: $shopId) {
    # Theme fields vary — introspect as needed
  }
}
```

### Get Subcategories
```graphql
query Subcategories($shopId: String!) {
  getSubcategoriesByShop(shopId: $shopId) {
    id name categoryId
  }
}
```

---

## How to Find Your Section IDs

Your storefront sections are configured in the Riverbase dashboard. To find them programmatically:

1. Call `getPageSections` with your `shopId` and `page: "home"`
2. Each section has a unique `id`, `name`, `dataType`, and `layout`
3. Use the section `id` in `getSection` to fetch its products

**Example section types:**
- `dataType: "DYNAMIC"` → contains products, categories, or events
- `dataType: "STATIC"` → contains banner images, promo designs
- Only `DYNAMIC` sections with product data are useful for the CS bot

---

## OpenClaw Multi-Agent Config

Add to your `openclaw.json` (or use `openclaw agents add shop-cs`):

```json5
{
  agents: {
    list: [
      // Existing main agent (unchanged)
      {
        id: "main",
        default: true,
        workspace: "/data/workspace"
      },
      // Customer service agent
      {
        id: "shop-cs",
        name: "Cosmeijiao",
        workspace: "/data/workspace-shop-cs",
        // Restrict tools — only reply + fetch public data
        tools: {
          allow: ["message", "web_fetch"],
          deny: ["exec", "read", "write", "edit", "browser",
                 "cron", "gateway", "nodes", "canvas",
                 "memory_store", "memory_forget", "memory_update",
                 "sessions_spawn", "sessions_send", "subagents",
                 "web_search", "tts"]
        }
      }
    ]
  },

  // Route messages by sender ID
  bindings: [
    // Owner → main agent (full access)
    { agentId: "main", match: { channel: "telegram", peer: { kind: "direct", id: "OWNER_TELEGRAM_ID" } } },
    // Everyone else → customer service agent
    { agentId: "shop-cs", match: { channel: "telegram" } }
  ],

  channels: {
    telegram: {
      dmPolicy: "open"  // Allow anyone to DM the bot
      // Or use allowlist for specific customer IDs:
      // dmPolicy: "allowlist",
      // allowFrom: ["OWNER_ID", "CUSTOMER_ID_1", "CUSTOMER_ID_2"]
    }
  }
}
```

**Important:** Replace `OWNER_TELEGRAM_ID` with your actual Telegram numeric user ID.

---

## CS Agent Workspace Setup

Create `/data/workspace-shop-cs/` (or whatever path you set) with:

### SOUL.md
```markdown
# Customer Service Agent

You are the customer service assistant for Cosmeijiao, a beauty and skincare shop.

## Personality
- Friendly, helpful, knowledgeable about skincare
- Speak the customer's language (English, Khmer, Chinese)
- Recommend products based on their needs
- Never make up product information — only use data from the API

## What you CAN do
- Browse products and answer questions about them
- Recommend products based on skin type or needs
- Check stock availability
- Provide prices and product details
- Share product images and links

## What you CANNOT do
- Place orders (redirect to mini app)
- Process payments
- Modify shop settings
- Access customer data or accounts

## Purchase Redirect
When a customer wants to buy, always redirect to the mini app:
"Tap here to purchase 👇\n🔗 https://yourshop.koompi.cloud/en"

## Shop Info
- Shop Name: Cosmeijiao
- Shop URL: https://yourshop.koompi.cloud
- Shop ID: YOUR_SHOP_ID
- GraphQL: https://api.riverbase.org/graphql (public, no auth needed)
```

### AGENTS.md
```markdown
# CS Agent Instructions

## How to Query Products

Use `web_fetch` to call the public Riverbase GraphQL API:
- URL: `https://api.riverbase.org/graphql`
- Method: POST
- Headers: `Authorization: null`, `Content-Type: application/json`

### Key Queries:
1. **List all products**: Use `getSection` with your main product section ID
2. **Search products**: Use `productSearch` with a keyword
3. **Get categories**: Use `getCategoriesByShop`
4. **Get shop info**: Use `shopId`

## Section IDs (replace with yours)
- Main products: YOUR_SECTION_ID
- New arrivals: YOUR_NEW_ARRIVALS_ID
- Best sellers: YOUR_BEST_SELLERS_ID

## Response Guidelines
- Always include price and stock status
- Include product images when possible
- Group products by category when listing multiple
- Use the customer's language
- Keep responses concise and helpful
```

---

## Customer Authentication (Optional)

If you want the bot to act on behalf of a customer (view orders, manage cart), you can use the `register` mutation to get a customer-scoped JWT:

```graphql
mutation Register($telegramInitData: String!, $shopId: String!) {
  register(telegramInitData: $telegramInitData, shopId: $shopId)
}
```

**Flow:**
1. Customer taps "Connect Account" button
2. Opens a Telegram WebApp / mini app page
3. Page captures `window.Telegram.WebApp.initData`
4. Sends to Riverbase → receives customer JWT
5. Bot stores JWT mapped to Telegram user ID
6. Future requests use the customer JWT for user-level operations

**Customer JWT permissions:**
- ✅ Browse products, categories
- ✅ View own orders
- ✅ Add to cart / checkout
- ✅ Manage saved locations
- ❌ Admin operations (blocked server-side by Riverbase)

**Note:** This requires the customer to open a mini app once. For most CS use cases, the public API (no auth) is sufficient for product browsing and recommendations.

---

## Mini App Deep Links

To link directly to a product in the mini app:
```
https://yourshop.koompi.cloud/en/products/{productId}
```

To link to the full shop:
```
https://yourshop.koompi.cloud/en
```

These links open the Riverbase mini app directly in Telegram.

---

## Troubleshooting

| Issue | Solution |
|---|---|
| `getSection` returns `null` | Section ID might be wrong — use `getPageSections` to list all sections |
| Products not loading | Check `dataType: "DYNAMIC"` — static sections don't have products |
| `Unauthorized` error | Don't use the `products(shopId: ...)` query — that requires auth. Use `getSection` instead |
| Wrong shop data | Verify your `shopId` matches the correct shop |
| Customer gets main agent | Check `bindings` order — peer matches must come BEFORE channel-wide matches |
| DM policy blocking customers | Set `dmPolicy: "open"` or add customer IDs to `allowFrom` |

---

## Agent Notes

- The public API returns the same data as the storefront — always up to date
- No cron job needed for catalog sync — data is real-time
- Product images are served from `gateway.lite.riverbase.org` — can be sent directly in Telegram
- Stock balance is live — no caching issues
- The `productSearch` query is the most useful for natural language CS interactions
