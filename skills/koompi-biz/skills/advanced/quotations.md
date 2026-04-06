# Quotations (Contract Quotes)

Requires shop module `quoting: true`.

## List Quotations
```graphql
query QuotationsByShop($shopId: String!) {
  getQuotesByShop(shopId: $shopId) {
    id threadId version shopId status createdAt validUntil
    subtotal discountAmount taxAmount total
    items { productId qty unitPrice totalPrice lineDescription productSnapshot { id name price images } }
    freeItems { productId qty productSnapshot { name } }
    customerContact { phone telegram }
    deliveryEstimate convertedOrderId convertedAt
    notes termsAndConditions
  }
}
```

## Get Quotation by ID
```graphql
query QuotationById($id: String!) {
  getQuoteById(id: $id) {
    id threadId version shopId status validUntil
    subtotal discountType discountAmount taxRate taxAmount total
    items { productId qty unitPrice totalPrice lineDescription discountAmount taxAmount productSnapshot { id name description price images } }
    freeItems { productId qty unitPrice totalPrice lineDescription productSnapshot { id name price images } }
    customerContact { phone telegram }
    termsAndConditions notes deliveryEstimate convertedOrderId convertedAt
  }
}
```

## Get Quotations by Customer
```graphql
query QuotationsByCustomer($shopId: String!, $userId: String!) {
  getQuotesByCustomer(shopId: $shopId, userId: $userId) {
    id threadId version status total createdAt validUntil
  }
}
```

## Create Quotation
```graphql
mutation CreateQuote(
  $shopId: String!
  $threadId: String!          # conversation thread ID
  $createdBy: String!         # staff user ID
  $requestedBy: String!       # customer user ID
  $items: [QuotationItemInput!]!
  $status: QuotationStatus!
  $validUntil: ScalarDateTimeUtc
  $discountAmount: ScalarDecimal128
  $discountType: QuotationDiscountType
  $taxRate: ScalarDecimal128
  $freeItems: [QuotationItemInput!]
  $deliveryLocation: LocationInput!
  $deliveryFee: String
) {
  createQuote(
    shopId: $shopId threadId: $threadId createdBy: $createdBy requestedBy: $requestedBy
    items: $items status: $status validUntil: $validUntil
    discountAmount: $discountAmount discountType: $discountType taxRate: $taxRate
    freeItems: $freeItems deliveryLocation: $deliveryLocation deliveryFee: $deliveryFee
  ) { id threadId version total status }
}
```

### QuotationItemInput
```json
{ "productId": "abc", "qty": 10, "unitPrice": "5.00", "lineDescription": "Custom engraving" }
```

### QuotationStatus
```
DRAFT | SENT | ACCEPTED | REJECTED | EXPIRED | CONVERTED
```

## Revise Quotation (new version)
Same fields as Create, plus `$originalQouteId: String!` — creates a new version in the same thread.

---

## Agent Notes
- **Thread system**: Quotations are versioned under a `threadId`. `reviseQuote` creates version N+1 under the same thread.
- **Convert to Order**: When a quote is accepted, backend converts it to an actual order. The `convertedOrderId` field tracks this.
- Decimal fields (`discountAmount`, `taxRate`) use `ScalarDecimal128` — pass as String.
