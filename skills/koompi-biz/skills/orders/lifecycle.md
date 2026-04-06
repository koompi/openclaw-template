# Order Lifecycle (Mutations)

## The State Machine
```
PENDING  ──processOrder──▶  CONFIRMED  ──completeOrder──▶  COMPLETED
   │                            │
   └──── setOrderStatus(CANCELLED) ◀──────┘
```

## Confirm (Process) Order
Moves from PENDING → CONFIRMED. Triggers Telegram notification to customer.
```graphql
mutation ProcessOrder($shopId: String!, $orderId: String!) {
  processOrder(shopId: $shopId, orderId: $orderId) {
    id orderStatus paymentStatus
  }
}
```

## Complete Order
Moves from CONFIRMED → COMPLETED. Optionally records delivery date. Debits stock if not already debited.
```graphql
mutation CompleteOrder($shopId: String!, $orderId: String!, $deliveryDate: String) {
  completeOrder(shopId: $shopId, orderId: $orderId, deliveryDate: $deliveryDate) {
    id orderStatus
  }
}
```

## Mark as Received (customer-side)
```graphql
mutation ReceiveOrder($orderId: String!) {
  receiveOrder(orderId: $orderId) { id orderStatus }
}
```

## Force Receive (shop-side override)
```graphql
mutation ForceReceive($orderId: String!, $shopId: String!) {
  forceReceiveOrder(orderId: $orderId, shopId: $shopId) { id orderStatus }
}
```

## Set Order Status (direct override)
Use when you need to manually change status (e.g., cancel).
```graphql
mutation SetOrderStatus($shopId: String!, $orderId: String!, $status: OrderStatus!) {
  setOrderStatus(shopId: $shopId, orderId: $orderId, status: $status) { id }
}
```
`OrderStatus`: `PENDING | CONFIRMED | COMPLETED | CANCELLED`

## Set Delivery Status
```graphql
mutation SetDeliveryStatus($shopId: String!, $orderId: String!, $status: DeliverySatus!) {
  setDeliveryStatus(shopId: $shopId, orderId: $orderId, status: $status) { id }
}
```
`DeliverySatus`: `PENDING | SHIPPED | DELIVERED` (note: typo "Satus" is in the actual schema)

---

## Create Order (POS / on behalf of customer)
```graphql
mutation PosCreateOrder(
  $shopId: String!
  $items: [CartItemInput!]!
  $location: LocationInput!
  $contact: ContactInput
  $remark: String
  $fulfillmentType: FulfillmentMethod
  $deliveryOption: String
  $couponCode: String
  $dueType: DueType
  $platform: Platform
  $sourceLocationId: String
  $codMethod: CodMethod
) {
  posCreateOrder(
    shopId: $shopId items: $items location: $location contact: $contact
    remark: $remark fulfillmentType: $fulfillmentType deliveryOption: $deliveryOption
    couponCode: $couponCode dueType: $dueType platform: $platform
    sourceLocationId: $sourceLocationId codMethod: $codMethod
  ) {
    ticketId status message
  }
}
```

### CartItemInput
```json
{ "product_id": "abc123", "quantity": 2, "options": { "option_id": "value_id" }, "note": "No onions" }
```

### LocationInput (minimal for POS / in-store)
```json
{ "label": "In Store", "lat": 0, "lon": 0 }
```

### Recommended POS defaults
- `dueType: COD`, `fulfillmentType: ON_SITE`, `platform: TELEGRAM`

---

## Agent Notes
- ⚠️ **CONFIRMATION REQUIRED for cancellation**: Always show order ID, items, and total before calling `setOrderStatus(CANCELLED)`. Wait for explicit "Yes".
- **Stock implications**: `completeOrder` debits stock. `setOrderStatus(CANCELLED)` after confirmation may need stock reversal — the backend handles this automatically.
- **Async creation**: `posCreateOrder` and `orderCreate` return a `ticketId` (queued). The actual order is created asynchronously. Inform user: "Order submitted, processing…"
