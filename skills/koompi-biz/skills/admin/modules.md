# Shop Modules & Settings

## Update Modules (feature toggles)
```graphql
mutation UpdateModules(
  $shopId: String!
  $blogging: Boolean!
  $shopping: Boolean!
  $ticketing: Boolean!
  $stocking: Boolean!
  $reselling: Boolean!
  $quoting: Boolean!
  $cartMode: String       # "DETAILS_ONLY" or "FULL_CHECKOUT"
  $codPayment: Boolean    # enable cash on delivery
  $posCodEnabled: Boolean # enable POS COD mode
  $cardStyle: String      # "MINIMAL" or "DETAILED"
  $showProductFilter: Boolean
) {
  shopUpdateModules(
    shopId: $shopId blogging: $blogging shopping: $shopping
    ticketing: $ticketing stocking: $stocking reselling: $reselling
    quoting: $quoting cartMode: $cartMode codPayment: $codPayment
    posCodEnabled: $posCodEnabled cardStyle: $cardStyle
    showProductFilter: $showProductFilter
  ) {
    id modules { shopping stocking quoting codPayment posCodEnabled cartMode cardStyle }
  }
}
```

### Module descriptions
| Module | Purpose |
|---|---|
| `shopping` | Core e-commerce (products, cart, checkout) |
| `stocking` | Inventory tracking (enables stock balances, locations) |
| `quoting` | Contract quotation system |
| `blogging` | Blog/post publishing |
| `ticketing` | Event ticket management |
| `reselling` | Multi-tier reseller program |
| `codPayment` | Accept Cash on Delivery orders |
| `posCodEnabled` | Accept POS COD (in-store cash register) |

### Workflow: Enable POS mode
1. Set `codPayment: true` and `posCodEnabled: true`
2. Set `cartMode: "FULL_CHECKOUT"` for complete POS flow

## Set Business Hours
```graphql
mutation SetBusinessHours($shopId: String!, $businessHours: [BusinessHourInput!]!) {
  setBusinessHour(shopId: $shopId, businessHours: $businessHours)
}
```

### BusinessHourInput
`day` is 0–6 (Sunday=0, Monday=1, …, Saturday=6). `hour` is 0–23, `minute` is 0–59.
```json
[
  { "day": 1, "from": { "hour": 8, "minute": 0 }, "to": { "hour": 17, "minute": 30 } },
  { "day": 2, "from": { "hour": 8, "minute": 0 }, "to": { "hour": 17, "minute": 30 } }
]
```
Include all open days. Days not in the array are treated as closed.

## Set Announcement
```graphql
mutation SetAnnouncement($shopId: String!, $announcement: String) {
  updateShopAnnouncement(shopId: $shopId, announcement: $announcement) {
    id modules { announcement }
  }
}
```
Pass `null` to clear the announcement.

## Configure Stock Debit Rules
Controls when inventory is automatically debited: at order creation or at order completion.
```graphql
mutation SetStockDebit($shopId: String!, $config: StockDebitConfigInput) {
  setStockDebitConfig(shopId: $shopId, config: $config)
}
```

### StockDebitConfigInput
```json
{
  "codDeliveryAutoDebit": false,
  "codPickupAutoDebit": false,
  "codOnsiteAutoDebit": true,
  "codPosAutoDebit": true,
  "onlineDeliveryAutoDebit": true,
  "onlinePickupAutoDebit": true,
  "onlineOnsiteAutoDebit": true,
  "onlinePosAutoDebit": true
}
```
`true` = debit at order creation. `false` = debit at order completion.

## Configure Unpaid Order TTL
Auto-cancel unpaid orders after X minutes.
```graphql
mutation SetTtl($shopId: String!, $config: UnpaidOrderTtlConfigInput) {
  setUnpaidOrderTtlConfig(shopId: $shopId, config: $config)
}
```

### UnpaidOrderTtlConfigInput
```json
{ "guestMins": 30, "registeredMins": 60 }
```

---

## Agent Notes
- **Toggling stocking**: When enabling `stocking`, also check if the shop has at least one inventory location. If not, offer to create one.
- **COD + POS**: These are separate flags. `codPayment` enables COD for online orders. `posCodEnabled` enables the POS terminal mode for in-store transactions.
