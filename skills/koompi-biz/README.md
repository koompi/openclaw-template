# Riverbase Skill

Machine-readable skill files that let **any AI agent** manage a Riverbase shop entirely through the GraphQL API — no frontend or Mini App needed.

## What is this?

Riverbase is a Telegram-native commerce platform. Shop owners normally manage products, orders, inventory, and settings through a web dashboard or the Telegram Mini App.

This repo replaces that UI layer with a structured set of **executable GraphQL references** so an AI agent (ChatGPT, Claude, Gemini, your own bot, etc.) can do everything the dashboard can — directly from a conversation.

Give the agent a JWT token and a shop ID, and it can:

- Create and update products, categories, and brands
- Process orders through PENDING → CONFIRMED → COMPLETED
- Handle payments (COD, ABA Transfer, direct)
- Manage inventory across multiple warehouse locations
- Configure shipping fees, delivery zones, and options
- Create coupons and discount rules
- Manage staff roles and permissions
- Set business hours, announcements, and shop modules
- Run a loyalty/membership program
- Send contract quotations
- Publish blog posts and events
- Connect custom domains
- Install and configure plugins

## For Humans

Browse the skill files to understand the full Riverbase API surface:

```
SKILL.md                          ← Start here: auth, enums, routing table
skills/
  catalog/
    products.md                   ← Product CRUD, search, variants, archive
    categories.md                 ← Categories & subcategories
    brands.md                     ← Brand CRUD
  orders/
    lifecycle.md                  ← Order state machine, POS creation
    queries.md                    ← List, filter, stats, dashboard
    payments.md                   ← Payment processing, COD, ABA
  inventory/
    locations.md                  ← Warehouse/store locations
    transactions.md               ← Stock in/out, transfers, adjustments
    checks.md                     ← Stock balance, availability checks
  admin/
    shop.md                       ← Shop settings, GPS, bot, customers
    modules.md                    ← Feature toggles, business hours
    team.md                       ← Roles & members
    shipping.md                   ← Shipping rules & delivery options
    discounts.md                  ← Coupons & discount rules (with recipes)
    sections.md                   ← Storefront sections & canvas designs
  advanced/
    membership.md                 ← VIP tiers & membership cards
    quotations.md                 ← Contract quotations & revisions
    content.md                    ← Blog posts & events
    dns.md                        ← Custom domain management
    plugins.md                    ← Plugin marketplace
  superadmin/
    dashboard.md                  ← Platform-wide metrics & revenue
    shops.md                      ← All shops, activate/deactivate
    users.md                      ← All users, freeze/activate
    business-categories.md        ← Platform business category CRUD
```

Each file contains **copy-paste-ready GraphQL** queries and mutations with exact field names, enum values, and variable types — extracted from the production frontend.

## For AI Agents

### Quick Start

1. **Load [`SKILL.md`](SKILL.md)** — it contains auth setup, the enum reference, and a keyword-based router table.
2. **Run the Bootstrap Query** (in SKILL.md) to resolve the user's `shopId`.
3. **Load only the sub-file you need** based on what the user is asking. Don't load everything at once.
4. **Execute the GraphQL** against `https://api.riverbase.org/graphql` with the user's token (raw token in `Authorization` header, no `Bearer` prefix).

### System Prompt Example

```
You are an AI shop assistant for Riverbase.
You have access to the Riverbase Skill files.

The user's auth token: <JWT>
The user's shop ID: <SHOP_ID>

When the user asks you to manage their shop, read SKILL.md to find the 
right sub-skill file, then execute the GraphQL operations described in it.

Always resolve names to IDs before mutating. Confirm before destructive actions.
All prices are String type. Pagination defaults: limit 20, page 1.
```

### Key Rules

- **IDs first** — always search/list to resolve names to IDs before mutations
- **Price = String** — all monetary values are `String`, not `Float`
- **One file at a time** — the router table in SKILL.md tells you which file to load
- **`shopId` everywhere** — every operation needs it; resolve once at session start
- **⚠️ Delete/Remove = ALWAYS confirm** — there are 16 destructive mutations across the skill files (listed in SKILL.md). The agent must **never** execute any of them without showing a summary and getting an explicit "Yes" or a Telegram confirmation button tap first

## API Reference

| | |
|---|---|
| **GraphQL Endpoint** | `https://api.riverbase.org/graphql` |
| **Upload Endpoint** | `https://api.riverbase.org/uploads/s3` |
| **Auth** | `Authorization: <token>` (no `Bearer` prefix) |
| **Method** | `POST` with JSON body `{"query": "...", "variables": {...}}` |

## License

Copyright © Riverbase. All rights reserved.
