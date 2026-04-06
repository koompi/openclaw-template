# Coupons & Discount Rules

## Coupons

### List Coupons
```graphql
query ListCoupons($shopId: String!) {
  listCoupons(shopId: $shopId) {
    id code description isActive shopId createdAt
  }
}
```

### Get Coupon by Code
```graphql
query CouponByCode($couponCode: String!, $shopId: String!) {
  getCouponByCode(couponCode: $couponCode, shopId: $shopId) {
    id code description isActive
  }
}
```

### Create Coupon
```graphql
mutation CreateCoupon($shopId: String!, $code: String!, $description: String) {
  createCoupon(shopId: $shopId, code: $code, description: $description) {
    id code isActive
  }
}
```

### Update Coupon
```graphql
mutation UpdateCoupon($couponId: String!, $code: String!, $description: String, $isActive: Boolean!) {
  updateCoupon(couponId: $couponId, code: $code, description: $description, isActive: $isActive) {
    id code isActive
  }
}
```

### Delete Coupon
> ⚠️ **CONFIRMATION REQUIRED** — Show coupon code and confirm before deleting.
```graphql
mutation DeleteCoupon($couponId: String!) {
  deleteCoupon(couponId: $couponId)
}
```

---

## Discount Rules

Discounts are powerful rules that automatically apply to orders. They work on three scopes: `LINE_ITEM` (per product), `TOTAL_CART`, or `SHIPPING`.

### List Rules
```graphql
query ListDiscounts($shopId: String!) {
  listDiscountRules(shopId: $shopId) {
    id name priority isActive startDate endDate usageCount maxUsage
    targetUsage targetMembershipId targetCouponId discountOn
    lineItems { productId discountType discountAmount moq }
    cartDiscount { discountType discountAmount }
    shippingDiscount { discountType discountAmount minCartTotal }
  }
}
```

### Create Discount Rule
```graphql
mutation CreateDiscount(
  $shopId: String!
  $name: String!
  $priority: Int!
  $startDate: ScalarDateTimeUtc
  $endDate: ScalarDateTimeUtc
  $isActive: Boolean!
  $usageCount: Int!        # starts at 0
  $maxUsage: Int           # null = unlimited
  $targetUsage: UsageTarget!
  $targetMembershipId: String
  $targetCouponId: String
  $discountOn: DiscountScope!
  $lineItems: [LineItemDiscountInput!]
  $shippingDiscount: ShippingDiscountInput
  $cartDiscount: CartDiscountInput
) {
  createDiscountRule(
    shopId: $shopId name: $name priority: $priority
    startDate: $startDate endDate: $endDate isActive: $isActive
    usageCount: $usageCount maxUsage: $maxUsage
    targetUsage: $targetUsage targetMembershipId: $targetMembershipId
    targetCouponId: $targetCouponId discountOn: $discountOn
    lineItems: $lineItems shippingDiscount: $shippingDiscount
    cartDiscount: $cartDiscount
  ) {
    id name
  }
}
```

### Update Discount Rule
Same fields as Create, plus `$discountId: String!`:
```graphql
mutation UpdateDiscount($discountId: String!, $shopId: String!, ...) {
  updateDiscountRule(discountId: $discountId, shopId: $shopId, ...) { id name }
}
```

### Delete Discount Rule
> ⚠️ **CONFIRMATION REQUIRED** — Show discount name/scope and confirm before deleting.
```graphql
mutation DeleteDiscount($discountId: String!) {
  deleteDiscountRule(discountId: $discountId)
}
```

---

## Common Discount Recipes

### 10% off a specific product
```json
{
  "name": "Summer Sale - T-Shirt",
  "priority": 1,
  "isActive": true,
  "usageCount": 0,
  "targetUsage": "EVERY_ONE",
  "discountOn": "LINE_ITEM",
  "lineItems": [{ "productId": "PRODUCT_ID_HERE", "discountType": "PERCENTAGE", "discountAmount": 10, "moq": 1 }]
}
```

### $5 off entire cart
```json
{
  "name": "Welcome Discount",
  "priority": 1,
  "isActive": true,
  "usageCount": 0,
  "maxUsage": 100,
  "targetUsage": "EVERY_ONE",
  "discountOn": "TOTAL_CART",
  "cartDiscount": { "discountType": "FIXED", "discountAmount": 5.0 }
}
```

### Free shipping on orders over $30
```json
{
  "name": "Free Shipping Over $30",
  "priority": 1,
  "isActive": true,
  "usageCount": 0,
  "targetUsage": "EVERY_ONE",
  "discountOn": "SHIPPING",
  "shippingDiscount": { "discountType": "FREE", "discountAmount": 0, "minCartTotal": 30.0 }
}
```

### Coupon-based 15% off
First create the coupon, then create a discount targeting it:
```json
{
  "name": "VIP15 Coupon",
  "priority": 1,
  "isActive": true,
  "usageCount": 0,
  "maxUsage": 50,
  "targetUsage": "COUPON",
  "targetCouponId": "COUPON_ID_HERE",
  "discountOn": "TOTAL_CART",
  "cartDiscount": { "discountType": "PERCENTAGE", "discountAmount": 15 }
}
```

---

## Agent Notes
- **Coupons are containers**: A coupon itself is just a code. The actual discount logic lives in a Discount Rule with `targetUsage: COUPON` and `targetCouponId` pointing to the coupon.
- **Priority**: Lower number = higher priority. If two rules could apply, the lower-priority-number wins.
- **moq**: Minimum order quantity. The line item discount only applies if the customer orders >= moq of that product.
- **Dates**: `startDate` and `endDate` are optional. If omitted, the discount is always active (when `isActive: true`).
