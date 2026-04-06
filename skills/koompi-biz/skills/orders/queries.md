# Order Queries

## List Shop Orders (paginated, filterable)
The primary query for viewing orders. All filter params are required.
```graphql
query ShopOrders(
  $shopId: String!
  $orderStatus: OrderStatus!
  $paymentStatus: PaymentStatus!
  $deliveryStatus: DeliverySatus!
  $dueType: DueType
  $fulfillmentType: FulfillmentMethod
  $limit: Int!
  $page: Int!
  $from: String          # ISO date "2026-01-01"
  $to: String            # ISO date "2026-01-31"
  $keyword: String       # search by order ID or customer name
) {
  shopOrders(
    shopId: $shopId orderStatus: $orderStatus paymentStatus: $paymentStatus
    deliveryStatus: $deliveryStatus dueType: $dueType fulfillmentType: $fulfillmentType
    limit: $limit page: $page from: $from to: $to keyword: $keyword
  ) {
    data {
      id amount orderStatus paymentStatus dueType fulfillmentType createdAt remark couponCode
      contact { phone telegram }
      user { id tgFirstname tgLastname tgUsername }
      items { productId quantity product { name price images } }
      deliveryInfo { distant afterRuleFee location { displayName } contact { phone telegram } }
      deliveryStatus deliveryDate
    }
    totalDocuments totalPages limit skip
  }
}
```

### Common filter presets
| Scenario | orderStatus | paymentStatus | deliveryStatus |
|---|---|---|---|
| Pending orders | `PENDING` | `ALL` | `ALL` |
| Unpaid orders | `ALL` | `UNPAID` | `ALL` |
| Ready to ship | `CONFIRMED` | `PAID` | `PENDING` |
| All orders | `ALL` | `ALL` | `ALL` |

## Get Single Order
```graphql
query GetOrder($orderId: String!) {
  orderId(orderId: $orderId) {
    id amount orderStatus paymentStatus dueType fulfillmentType createdAt remark
    items { productId quantity options note product { id name price images } }
    contact { phone telegram }
    user { id tgFirstname tgLastname tgUsername tgAvatar }
    deliveryInfo { distant initialFee deliveryDiscount afterRuleFee location { displayName lat lon } contact { phone telegram } }
    deliveryStatus deliveryDate confirmedAt paidAt
    appliedDiscounts { discountName discountType amount percentage }
    codMethod platform quotationId
  }
}
```

## Order Statistics (counts by status)
```graphql
query ShopOrderStats(
  $shopId: String!
  $paymentStatus: PaymentStatus!
  $orderStatus: OrderStatus!
  $deliveryStatus: DeliverySatus!
  $from: String
  $to: String
) {
  shopOrdersStatistic(
    shopId: $shopId paymentStatus: $paymentStatus orderStatus: $orderStatus
    deliveryStatus: $deliveryStatus from: $from to: $to
  ) {
    cancelled completed pendingConfirmation pendingDelivery pendingPayment
  }
}
```
Tip: Pass `ALL` for all status filters to get a complete overview.

## Order Dashboard (revenue & summary)
```graphql
query Dashboard($shopId: String!, $from: String, $to: String, $dueType: DueType) {
  shopOrderDashboard(shopId: $shopId, from: $from, to: $to, dueType: $dueType) {
    totalOrders totalOrdersChange
    totalRevenue totalRevenueChangePct
    completedOrders completionRate completionRateChangePct
    cancelledOrders
    pendingConfirmation pendingDelivery pendingPayment pendingOrdersCount
    potentialRevenue
    codOrdersCount codRevenue codRevenueChangePct
    nowOrdersCount nowRevenue nowRevenueChangePct
  }
}
```

## Try Order (preview without creating)
Useful for quoting or calculating totals before committing.
```graphql
query TryOrder(
  $shopId: String! $items: [CartItemInput!]! $location: LocationInput!
  $contact: ContactInput $fulfillmentType: FulfillmentMethod
  $deliveryOption: String $couponCode: String $sourceLocationId: String
) {
  tryOrder(
    shopId: $shopId items: $items location: $location contact: $contact
    fulfillmentType: $fulfillmentType deliveryOption: $deliveryOption
    couponCode: $couponCode sourceLocationId: $sourceLocationId
  ) {
    amount items { product { name price } quantity } deliveryInfo { afterRuleFee }
    appliedDiscounts { discountName amount }
  }
}
```

---

## Agent Notes
- **Default pagination**: `limit: 20, page: 1`.
- **Date range**: Use `from` / `to` in ISO format for time-based filtering (e.g., today's orders).
- **Summarize for user**: "You have 5 pending orders, 3 awaiting payment, totalling $450.00."
