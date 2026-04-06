# Riverbase AI Skill

> Complete GraphQL reference for AI agents managing shops on the Riverbase platform via Telegram.

## Endpoint & Auth

| Key | Value |
|---|---|
| **GraphQL** | `https://api.riverbase.org/graphql` |
| **Upload** | `https://api.riverbase.org/uploads/s3` (multipart POST, field name `file`, returns full CDN URL) |
| **Upload HQ** | `https://api.riverbase.org/uploads/s3/hq` (same but max 1920px instead of 800px) |
| **Auth** | `Authorization: <USER_TOKEN>` header on all requests (no `Bearer` prefix) |
| **Method** | `POST` with `Content-Type: application/json` body `{"query":"...","variables":{...}}` |

---

## Skill Router

Load **only** the file relevant to the user's request:

### Catalog (Products, Categories, Brands)
| File | Use when user says… |
|---|---|
| [catalog/products.md](skills/catalog/products.md) | "add product", "update price", "archive item", "search products" |
| [catalog/categories.md](skills/catalog/categories.md) | "create category", "list categories", "add subcategory" |
| [catalog/brands.md](skills/catalog/brands.md) | "add brand", "list brands" |

### Orders & Payments
| File | Use when user says… |
|---|---|
| [orders/lifecycle.md](skills/orders/lifecycle.md) | "pending orders", "confirm order", "complete order", "cancel" |
| [orders/queries.md](skills/orders/queries.md) | "show orders", "order stats", "dashboard", "search order" |
| [orders/payments.md](skills/orders/payments.md) | "mark as paid", "process payment", "payment status" |

### Inventory & Stock
| File | Use when user says… |
|---|---|
| [inventory/locations.md](skills/inventory/locations.md) | "add warehouse", "list locations", "set default location" |
| [inventory/transactions.md](skills/inventory/transactions.md) | "restock", "record damage", "adjust stock", "transfer stock" |
| [inventory/checks.md](skills/inventory/checks.md) | "check stock", "stock overview", "low stock", "availability" |

### Shop Administration
| File | Use when user says… |
|---|---|
| [admin/shop.md](skills/admin/shop.md) | "create shop", "rename shop", "activate", "set location", "customers", "notifications" |
| [admin/modules.md](skills/admin/modules.md) | "enable POS", "turn on stocking", "COD settings", "announcement", "business hours" |
| [admin/team.md](skills/admin/team.md) | "add staff", "create role", "remove member" |
| [admin/shipping.md](skills/admin/shipping.md) | "shipping fee", "delivery zones", "add delivery option" |
| [admin/discounts.md](skills/admin/discounts.md) | "create coupon", "discount rule", "sale on product" |
| [admin/sections.md](skills/admin/sections.md) | "create section", "add banner", "homepage layout", "design", "storefront" |

### Advanced Features
| File | Use when user says… |
|---|---|
| [advanced/membership.md](skills/advanced/membership.md) | "VIP tier", "membership card", "loyalty program", "add member" |
| [advanced/quotations.md](skills/advanced/quotations.md) | "create quote", "send quotation", "revise quote", "contract pricing" |
| [advanced/content.md](skills/advanced/content.md) | "write blog post", "create event", "publish article", "ticket event" |
| [advanced/dns.md](skills/advanced/dns.md) | "custom domain", "connect domain", "DNS settings" |
| [advanced/plugins.md](skills/advanced/plugins.md) | "install plugin", "list plugins", "shade finder", "plugin settings" |

### Superadmin (Platform-Level — requires `role: "admin"`)
| File | Use when user says… |
|---|---|
| [superadmin/dashboard.md](skills/superadmin/dashboard.md) | "platform stats", "total revenue", "top shops", "platform dashboard" |
| [superadmin/shops.md](skills/superadmin/shops.md) | "list all shops", "activate shop", "deactivate shop", "all shops" |
| [superadmin/users.md](skills/superadmin/users.md) | "list all users", "freeze user", "activate user", "all users" |
| [superadmin/business-categories.md](skills/superadmin/business-categories.md) | "business categories", "add biz category", "shop types" |

---

## GraphQL Enums Reference

These exact string values are used throughout all mutations and queries.

### Order Enums
```
OrderStatus:   ALL | PENDING | CONFIRMED | COMPLETED | CANCELLED
PaymentStatus: ALL | PAID | UNPAID
DeliverySatus: ALL | PENDING | SHIPPED | DELIVERED    # Note: typo "Satus" is intentional - matches schema
DueType:       ALL | NOW | COD
FulfillmentMethod: DELIVERY | IN_STORE_PICKUP | ON_SITE | ONLINE_POS | DIGITAL
CodMethod:     CASH | ABA_TRANSFER
Platform:      TELEGRAM | OTHERS
OrderType:     USER | POS
```

### Inventory Enums
```
CreditTransactionType: PURCHASE | RETURN | CONSIGNMENT_RETURN | CONSIGNMENT_RECEIVED | MANUFACTURING | UNRESERVED | ADJUSTMENT | STOCK_COUNT | RESTOCK
DebitTransactionType:  SALE | REFUND | CANCELLATION | CONSIGNMENT_SENT | CONSIGNMENT_SOLD | RESERVED | TRANSFER | RAW_MATERIAL | DAMAGE | SHRINKAGE | EXPIRED | DONATION | DISPOSAL | PROMOTION | QUARANTINE | RECALL | SAMPLING | DEMO | ADJUSTMENT | STOCK_COUNT
InventoryAccountType:  RAW_MATERIALS | WORK_IN_PROGRESS | FINISHED_GOODS | MERCHANDISE_INVENTORY | RESERVED | QUARANTINE | DAMAGED | TRANSIT | CONSIGNMENT_IN | CONSIGNMENT_OUT | DEMO
InventoryLocationType: WAREHOUSE | STORE | DISPLAY
```

### Shop Enums
```
OperationalMode: OPEN | CLOSED | BUSY
ShippingModel:   DISTANCE_BASED | ZONE_BASED | FLAT_RATE | THIRD_PARTY_ONLY
CartMode:        DETAILS_ONLY | FULL_CHECKOUT
CardStyle:       MINIMAL | DETAILED
```

### Discount Enums
```
DiscountScope:   LINE_ITEM | TOTAL_CART | SHIPPING
DiscountType:    FIXED | PERCENTAGE | LOCKED_PRICE
UsageTarget:     EVERY_ONE | MEMBERSHIP | COUPON
```

---

## Global Agent Rules

1. **Resolve IDs first.** When a user refers to a product/category/brand by name, always run a search or list query to get the `id` before mutating.
2. **Price = String.** All monetary values (`price`, `amount`, `unitPrice`) are passed as `String` in GraphQL to preserve decimal precision.
3. **shopId is always required.** Every query/mutation requires `shopId`. Resolve it once at the start of a conversation via `ownedShops` or `joinedShops`.
4. **Pagination.** List queries return `{ data, limit, skip, totalPages, totalDocuments }`. Default to `limit: 20, page: 1`.
5. **Soft delete.** Products are archived (`productSetArchived`), not hard-deleted. Use `productDelete` only when the user explicitly says "permanently delete."

### ⚠️ Destructive Operations — ALWAYS Require Confirmation

**NEVER execute any of these mutations without explicit user confirmation first.**
Show a summary of what will be affected, then ask "Are you sure? Reply Yes to confirm" or send a Telegram inline button.

| Mutation | What it does | File |
|---|---|---|
| `productDelete` | Permanently deletes a product | catalog/products.md |
| `productSetArchived(archived: true)` | Archives (soft-deletes) a product | catalog/products.md |
| `deleteCategory` | Deletes a category (products become uncategorized) | catalog/categories.md |
| `deleteSubcategory` | Deletes a subcategory | catalog/categories.md |
| `deleteBrand` | Deletes a brand (products lose brand) | catalog/brands.md |
| `setOrderStatus(CANCELLED)` | Cancels an order (triggers stock reversal) | orders/lifecycle.md |
| `deleteInventoryLocation` | Deletes a warehouse/store location | inventory/locations.md |
| `shopRoleDelete` | Deletes a staff role | admin/team.md |
| `shopMemberRemove` | Removes a team member from the shop | admin/team.md |
| `deleteDeliveryOption` | Removes a delivery option | admin/shipping.md |
| `deleteCoupon` | Deletes a coupon code | admin/discounts.md |
| `deleteDiscountRule` | Deletes a discount rule | admin/discounts.md |
| `deleteSection` | Deletes a storefront section | admin/sections.md |
| `deleteDesign` | Deletes a canvas design | admin/sections.md |
| `deleteTeir` | Deletes a membership tier | advanced/membership.md |
| `deleteMembership` | Revokes a user's membership | advanced/membership.md |
| `deleteDns` | Removes custom domain | advanced/dns.md |
| `pluginUninstall` | Uninstalls a plugin | advanced/plugins.md |
| `shopActivate(active: false)` | Deactivates a shop (storefront goes offline) | superadmin/shops.md |
| `userSetActive(active: false)` | Freezes a user (loses all access) | superadmin/users.md |
| `deleteBusinessCategory` | Deletes a platform business category | superadmin/business-categories.md |

### Bootstrap Query (run first in every session)
```graphql
query Bootstrap {
  ownedShops {
    id
    name
    logo
    active
    productsCount
    modules { shopping stocking quoting codPayment posCodEnabled cartMode }
  }
  joinedShops {
    id
    name
    logo
    active
  }
}
```
