# Shop Management (Superadmin)

> Requires `role: "admin"` on the user object.

## List All Shops
```graphql
query AllShops {
  shops {
    id name logo active productsCount createdAt
    ownerId
    owner { id tgUsername tgFirstname tgLastname name phone }
    businessCatories { id name }
    preliminaryLocation
    latlong { lat lon }
    operationalMode
    shippingModel
    pluginAccess
    modules { shopping stocking quoting codPayment posCodEnabled cartMode cardStyle }
    activationStatus { shopLocation paymentConnection telegramBot }
    members { id userId role { id title } user { id tgUsername tgFirstname } }
    roles { id title actions isDefault }
    businessHours { day from { hour minute } to { hour minute } }
  }
}
```
Returns **all shops** on the platform with full details.

## Activate / Deactivate Shop
```graphql
mutation ShopActivation($shopId: String!, $active: Boolean!) {
  shopActivate(shopId: $shopId, active: $active)
}
```
> ⚠️ **CONFIRMATION REQUIRED** — Show shop name and current status. When deactivating, warn that the shop's storefront will go offline. Wait for explicit "Yes".

- `active: true` → shop is live, storefront accessible
- `active: false` → shop is frozen, storefront returns unavailable

## Set Plugin Access
```graphql
mutation ShopSetPluginAccess($shopId: String!, $enabled: Boolean!) {
  shopSetPluginAccess(shopId: $shopId, enabled: $enabled)
}
```
Grants or revokes a shop's ability to install plugins from the marketplace.

---

## Agent Notes
- **Shop search**: The `shops` query returns all shops. Filter client-side by name, owner, category, or active status.
- **Activation flow**: New shops start as `active: false`. Superadmin reviews and activates them.
- **Activation status**: `activationStatus` shows setup progress — `shopLocation` (GPS set), `paymentConnection` (payment connected), `telegramBot` (bot linked).
