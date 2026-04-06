# Customer Authentication

Authenticate Telegram users to get a customer-scoped JWT for making API requests on their behalf.

---

## Register / Login via Telegram initData

> **This is the primary auth method for bots and mini apps.** No admin token required — this is a public mutation.

```graphql
mutation Register($telegramInitData: String!, $shopId: String!) {
  register(telegramInitData: $telegramInitData, shopId: $shopId)
}
```

**Arguments:**

| Arg | Type | Description |
|---|---|---|
| `telegramInitData` | `String!` | Raw `initData` string from Telegram WebApp (URL-encoded key-value pairs including `hash`) |
| `shopId` | `String!` | The shop ID the user is logging into |

**Returns:** `String!` — a JWT token (valid for 365 days).

**What it does internally:**
1. Looks up the shop's bot token via RPC
2. Verifies the `initData` HMAC-SHA256 signature against the bot token
3. Decodes the Telegram user info (`id`, `first_name`, `last_name`, `username`)
4. Finds existing user by `tg_id` — or creates a new one with `role: User`
5. Signs and returns a JWT containing `{ id, iat, exp }`

### Example

```json
{
  "query": "mutation Register($telegramInitData: String!, $shopId: String!) { register(telegramInitData: $telegramInitData, shopId: $shopId) }",
  "variables": {
    "telegramInitData": "query_id=AAHdF6IQ...&user=%7B%22id%22%3A123456789%2C%22first_name%22%3A%22John%22%7D&auth_date=1234567890&hash=abc123...",
    "shopId": "6976183a6f36334a83e304ad"
  }
}
```

Response:
```json
{
  "data": {
    "register": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

---

## Login by User ID

> ⚠️ **No authentication check** — this returns a JWT for any user ID. Should only be used in trusted server-to-server contexts.

```graphql
mutation Login($userId: String!) {
  login(userId: $userId)
}
```

Returns: `String!` — JWT token.

---

## Telegram Login Widget (REST)

For web-based login buttons (not mini app), Riverbase has a REST callback endpoint:

```
GET https://api.riverbase.org/telegram/main
```

**Query Parameters:**

| Param | Type | Required | Description |
|---|---|---|---|
| `id` | String | Yes | Telegram user ID |
| `first_name` | String | Yes | User's first name |
| `last_name` | String | No | User's last name |
| `username` | String | No | Telegram @username |
| `photo_url` | String | Yes | User's avatar URL |
| `auth_date` | Integer | Yes | Unix timestamp of auth |
| `hash` | String | Yes | HMAC verification hash from Telegram |
| `redirect` | String | Yes | URL to redirect after login (must include domain) |
| `shop_id` | String | No | Shop ID for bot token lookup |

**Flow:**
1. Telegram redirects user to this URL with signed params
2. Riverbase verifies the hash against the shop's bot token
3. Checks `auth_date` is within 24 hours
4. Creates/finds user → signs JWT
5. Redirects to: `{redirect}?token={JWT}`

---

## Using the Customer JWT

Once you have the JWT, use it like any other Riverbase token:

```
POST https://api.riverbase.org/graphql
Authorization: <JWT_TOKEN>
Content-Type: application/json
```

**No `Bearer` prefix** — just the raw token.

### What customers CAN do with their JWT:
- Browse products and categories
- View their own orders
- Add items to cart / checkout
- Manage their saved locations
- Update personal info (name, phone, photo)

### What customers CANNOT do:
- Access admin/shop-owner operations
- Modify shop settings, products, or inventory
- View other users' data
- Any operation requiring `Action::*` permissions

---

## Update Personal Info (authenticated)

```graphql
mutation UpdatePersonalInfo($name: String, $phone: String, $photo: String) {
  userUpdatePersonalInfo(name: $name, phone: $phone, photo: $photo)
}
```

Requires: Customer JWT in `Authorization` header. Returns `Boolean`.

---

## Customer Locations

### List My Locations
```graphql
query MyLocations {
  myLocations {
    id
    userId
    default
    location {
      name
      address
      lat
      lon
    }
  }
}
```

### Add Location
```graphql
mutation AddLocation($default: Boolean!, $location: LocationInput!) {
  addLocation(default: $default, location: $location)
}
```

---

## JWT Token Details

| Field | Value |
|---|---|
| **Algorithm** | HS256 |
| **Expiry** | 365 days from issuance |
| **Payload** | `{ id: "<user_mongo_id>", iat: <unix_ts>, exp: <unix_ts> }` |
| **No refresh endpoint** | Issue a new token via `register` if expired |

---

## Bot Integration Flow

For a Telegram bot that acts on behalf of customers:

```
1. Customer opens mini app via bot
   → Telegram provides initData automatically

2. Bot backend calls:
   register(telegramInitData, shopId) → JWT

3. Bot stores JWT mapped to Telegram chat_id

4. Future messages from that customer:
   → Bot retrieves stored JWT
   → Makes GraphQL requests with customer's token
   → Customer-level permissions enforced server-side

5. Token expires after 365 days:
   → Re-trigger mini app flow to get fresh initData
   → Call register again → new JWT
```
