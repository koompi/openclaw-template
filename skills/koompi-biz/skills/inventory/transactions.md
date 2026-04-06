# Inventory Transactions

Record stock movements. Every transaction is either a **Credit** (stock goes up) or **Debit** (stock goes down).

## Record Credit (stock IN)
Use for: restocking, customer returns, receiving consignment goods, manual adjustments upward.
```graphql
mutation RecordCredit(
  $shopId: String!
  $productId: String!
  $locationId: String
  $transactionType: CreditTransactionType!
  $qty: Int!
  $unitPrice: Float!
  $unitCost: Float
  $accountType: InventoryAccountType!
  $batchNumber: String
  $referenceId: String
  $referenceType: String
  $userId: String
  $notes: String
) {
  recordCreditTransaction(
    shopId: $shopId productId: $productId locationId: $locationId
    transactionType: $transactionType qty: $qty unitPrice: $unitPrice
    unitCost: $unitCost accountType: $accountType batchNumber: $batchNumber
    referenceId: $referenceId referenceType: $referenceType
    userId: $userId notes: $notes
  ) {
    id qty balanceBefore balanceAfter transactionType status
  }
}
```

### Common Credit scenarios
| Scenario | transactionType | accountType |
|---|---|---|
| Restock from supplier | `PURCHASE` | `MERCHANDISE_INVENTORY` |
| Customer return | `RETURN` | `MERCHANDISE_INVENTORY` |
| Stock count found extra | `STOCK_COUNT` | `MERCHANDISE_INVENTORY` |
| Manual correction up | `ADJUSTMENT` | `MERCHANDISE_INVENTORY` |
| Restock display | `RESTOCK` | `MERCHANDISE_INVENTORY` |

## Record Debit (stock OUT)
Use for: damage, shrinkage, promotional giveaways, manual adjustments downward.
```graphql
mutation RecordDebit(
  $shopId: String!
  $productId: String!
  $locationId: String
  $transactionType: DebitTransactionType!
  $qty: Int!
  $unitPrice: Float!
  $unitCost: Float
  $accountType: InventoryAccountType!
  $batchNumber: String
  $referenceId: String
  $referenceType: String
  $userId: String
  $notes: String
) {
  recordDebitTransaction(
    shopId: $shopId productId: $productId locationId: $locationId
    transactionType: $transactionType qty: $qty unitPrice: $unitPrice
    unitCost: $unitCost accountType: $accountType batchNumber: $batchNumber
    referenceId: $referenceId referenceType: $referenceType
    userId: $userId notes: $notes
  ) {
    id qty balanceBefore balanceAfter transactionType status
  }
}
```

### Common Debit scenarios
| Scenario | transactionType | accountType |
|---|---|---|
| Damaged goods | `DAMAGE` | `DAMAGED` |
| Theft/loss | `SHRINKAGE` | `MERCHANDISE_INVENTORY` |
| Stock count found less | `STOCK_COUNT` | `MERCHANDISE_INVENTORY` |
| Manual correction down | `ADJUSTMENT` | `MERCHANDISE_INVENTORY` |
| Expired items | `EXPIRED` | `MERCHANDISE_INVENTORY` |
| Promo giveaway | `PROMOTION` | `MERCHANDISE_INVENTORY` |

## Transfer Between Locations
```graphql
mutation Transfer(
  $shopId: String! $productId: String!
  $fromLocationId: String! $toLocationId: String!
  $qty: Int! $transferId: String!
  $userId: String $notes: String $variantId: String
) {
  transferInventory(
    shopId: $shopId productId: $productId
    fromLocationId: $fromLocationId toLocationId: $toLocationId
    qty: $qty transferId: $transferId
    userId: $userId notes: $notes variantId: $variantId
  ) {
    id qty balanceBefore balanceAfter
  }
}
```
`transferId` is a unique ID you generate (use UUID) to group the debit+credit pair.

## View Transaction History
```graphql
query TransactionHistory($shopId: String!, $locationId: String) {
  getInventoryTransactionsByShop(shopId: $shopId, locationId: $locationId) {
    id transactionType transactionTypeDebit transactionTypeCredit
    productId qty unitPrice totalValue
    balanceBefore balanceAfter
    notes status createdAt
    product { name images }
    location { name }
    user { tgFirstname tgLastname }
  }
}
```

## Reassign Orphaned Stock
Fix stock entries that lost their location association.
```graphql
mutation Reassign($shopId: String!, $productId: String!, $toLocationId: String!, $qty: Int!, $userId: String, $notes: String) {
  reassignOrphanedStock(shopId: $shopId, productId: $productId, toLocationId: $toLocationId, qty: $qty, userId: $userId, notes: $notes) {
    id balanceAfter
  }
}
```

---

## Agent Notes
- **qty is always positive**. The transaction type (credit/debit) determines direction.
- **unitPrice**: The selling price per unit. Required even for non-sale transactions (use `0.0` if truly unknown).
- **Variant stock**: For products with variants, pass the `variantId` in the `referenceId` field or use the variant-specific product ID lookup.
- **Auto-debits from orders**: Sales debits happen automatically when orders are completed. You do NOT need to manually debit for regular sales.
