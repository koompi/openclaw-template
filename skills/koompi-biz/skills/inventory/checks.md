# Stock Checks & Availability

## Overview (summary counts)
```graphql
query StockOverview($shopId: String!, $locationId: String) {
  getInventoryOverview(shopId: $shopId, locationId: $locationId) {
    totalProducts inStock lowStock outOfStock totalValue
  }
}
```
Great for a quick "How's my inventory?" response.

## Check Product Stock by Location
```graphql
query BalancesByLocation($shopId: String!, $productId: String!, $variantId: String) {
  getInventoryBalancesByLocation(shopId: $shopId, productId: $productId, variantId: $variantId) {
    productId locationId variantId total
  }
}
```
Returns balance per location. If `variantId` is null, returns product-level balance.

## Bulk Stock Check (multiple products)
Avoids N+1 queries for listing pages.
```graphql
query BulkBalances($shopId: String!, $productIds: [String!]!, $locationId: String) {
  getBulkInventoryBalances(shopId: $shopId, productIds: $productIds, locationId: $locationId) {
    productId locationId variantId total
  }
}
```

## Check Cart Availability (before placing order)
```graphql
query CheckCart($shopId: String!, $items: [CartItemAvailabilityInput!]!) {
  checkCartAvailability(shopId: $shopId, items: $items) {
    productId variantId availableQuantity requestedQuantity productName variantName
  }
}
```
Returns only items with **insufficient** stock. Empty array = all items available.

### CartItemAvailabilityInput
```json
{ "productId": "abc", "variantId": "v1", "quantity": 5 }
```

## Check Stock at Specific Location
```graphql
query CheckStockLocation($shopId: String!, $locationId: String!, $items: [CartItemAvailabilityInput!]!) {
  checkStockAvailability(shopId: $shopId, locationId: $locationId, items: $items) {
    available
    insufficientItems {
      productId variantId availableQuantity requestedQuantity productName variantName
    }
  }
}
```
Returns `available: Boolean` plus detailed list of insufficient items.

## Inline Stock on Product Query
Every product query can include `stockBalance` as a field:
```graphql
query ProductWithStock($productId: String!, $locationId: String) {
  productId(productId: $productId) {
    id name price
    stockBalance(locationId: $locationId)
    variants {
      id sku
      stockBalance(locationId: $locationId)
    }
  }
}
```
If `locationId` is omitted, returns total across all locations.

---

## Agent Notes
- **Low stock alert**: Use `getInventoryOverview` to quickly detect `lowStock > 0` and alert the shop owner.
- **Variant-level tracking**: Always check variant stock, not just product stock, for products with variants.
- **Pre-order check**: Before suggesting restocking, check if the product has `isPreorder: true` — pre-order products may intentionally have zero stock.
