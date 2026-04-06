# Shipping & Delivery

## Get Shipping Rules
```graphql
query GetShippingRules($shopId: String!) {
  getShippingFeeRulesByShop(shopId: $shopId) {
    id shopId
    rules { minDistance maxDistance feeType baseFee feePerKm }
    zones { id name provinceIds fee isDefault isActive sortOrder }
    options { id name logo price includePhnomPenh }
  }
}
```

## Create/Update Distance-Based Rules
```graphql
mutation UpdateShippingFee($shopId: String!, $rules: [FeeRangeInput!]!) {
  updateShippingFee(shopId: $shopId, rules: $rules) {
    id rules { minDistance maxDistance baseFee feePerKm }
  }
}
```

### FeeRangeInput example
```json
[
  { "minDistance": 0, "maxDistance": 5, "feeType": "FLAT", "baseFee": 1.0, "feePerKm": 0 },
  { "minDistance": 5, "maxDistance": 15, "feeType": "PER_KM", "baseFee": 1.0, "feePerKm": 0.3 }
]
```

## Set Shipping Zones
```graphql
mutation SetZones($shopId: String!, $zones: [ShippingZoneInput!]!) {
  setShippingZones(shopId: $shopId, zones: $zones) {
    id zones { id name fee isActive }
  }
}
```

## Delivery Options (Third-party couriers)

### Add Option
```graphql
mutation AddDeliveryOption($shopId: String!, $name: String!, $price: String!, $logo: String, $includePhnomPenh: Boolean) {
  addDeliveryOption(shopId: $shopId, name: $name, price: $price, logo: $logo, includePhnomPenh: $includePhnomPenh) {
    id options { id name price logo }
  }
}
```

### Update Option
```graphql
mutation UpdateDeliveryOption($shopId: String!, $thirdPartyId: String!, $name: String!, $price: String!, $logo: String, $includePhnomPenh: Boolean) {
  updateDeliveryOption(shopId: $shopId, thirdPartyId: $thirdPartyId, name: $name, price: $price, logo: $logo, includePhnomPenh: $includePhnomPenh) {
    id options { id name price logo }
  }
}
```

### Delete Option
> ⚠️ **CONFIRMATION REQUIRED** — Show delivery option name and confirm before deleting.
```graphql
mutation DeleteDeliveryOption($shopId: String!, $thirdPartyId: String!) {
  deleteDeliveryOption(shopId: $shopId, thirdPartyId: $thirdPartyId) {
    id options { id name price }
  }
}
```

## Calculate Shipping Fee (preview)
```graphql
query CalcFee($shopId: String!, $lat: Float!, $lon: Float!) {
  getShippingFee(shopId: $shopId, lat: $lat, lon: $lon)
}
```
Returns a numeric fee based on the shop's rules and customer location.

---

## Agent Notes
- **Shipping models**: The shop's `shippingModel` (set in `shop.md`) determines which rules apply. `DISTANCE_BASED` uses `rules`, `ZONE_BASED` uses `zones`, `THIRD_PARTY_ONLY` uses only `options`.
- **Price is String**: Delivery option `price` is a String like `"2.50"`.
