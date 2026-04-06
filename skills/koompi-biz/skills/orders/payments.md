# Payments

## Process Online Payment (redirect user to payment page)
```graphql
mutation ProcessPayment($orderId: String!, $customSuccessUrl: String) {
  processPayment(orderId: $orderId, customSuccessUrl: $customSuccessUrl)
}
```
Returns a payment URL string. Share this link with the customer.

## Process Guest Payment
```graphql
mutation ProcessGuestPayment($orderId: String!, $customSuccessUrl: String) {
  processGuestPayment(orderId: $orderId, customSuccessUrl: $customSuccessUrl)
}
```

## Process Direct Payment
```graphql
mutation ProcessDirectPayment($orderId: String!, $customSuccessUrl: String) {
  processDirectPayment(orderId: $orderId, customSuccessUrl: $customSuccessUrl)
}
```

## Set Payment Status (manual override)
Use for COD orders or manual bank transfers.
```graphql
mutation SetPaymentStatus($shopId: String!, $orderId: String!, $status: PaymentStatus!) {
  setPaymentStatus(shopId: $shopId, orderId: $orderId, status: $status) { id }
}
```
`PaymentStatus`: `PAID | UNPAID`

## Check Payment Connection
```graphql
query IsPaymentConnected($shopId: String!) {
  isPaymentConnected(shopId: $shopId)
}
```
Returns `Boolean`. If `false`, the shop cannot accept online payments — suggest connecting via `connectPayment`.

## Connect Payment
```graphql
mutation ConnectPayment($email: String!, $password: String!, $shopId: String!) {
  connectPayment(email: $email, password: $password, shopId: $shopId)
}
```

## Check ABA Connection  
```graphql
query IsAbaConnected($shopId: String!) {
  isAbaConnected(shopId: $shopId)
}
```

## Enable ABA
```graphql
mutation EnableAba($shopId: String!) {
  enableAba(shopId: $shopId)
}
```

---

## Agent Notes
- **COD flow**: For COD orders, the shop owner manually marks as PAID after receiving cash. Use `setPaymentStatus(status: PAID)`.
- **Online flow**: Call `processPayment` → get URL → share with customer → backend auto-updates `paymentStatus` to `PAID` on success.
- **Never expose credentials**: If user asks to connect payment, collect email/password securely and do not log them.
