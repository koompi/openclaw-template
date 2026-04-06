# Shop Management

## Get Shop Details
```graphql
query ShopMetadata($shopId: String!) {
  shopId(shopId: $shopId) {
    id name logo ownerId active productsCount preliminaryLocation
    businessCatories { name }
    modules { shopping stocking quoting cartMode cardStyle codPayment posCodEnabled announcement showProductFilter }
    owner { id name phone tgUsername tgFirstname tgLastname }
    activationStatus { shopLocation paymentConnection telegramBot }
    latlong { lat lon }
    operationalMode operationalDistant shippingModel pluginAccess
    businessHours { day from { hour minute } to { hour minute } }
    stockDebitConfig { codDeliveryAutoDebit codPickupAutoDebit codOnsiteAutoDebit codPosAutoDebit onlineDeliveryAutoDebit onlinePickupAutoDebit onlineOnsiteAutoDebit onlinePosAutoDebit }
    unpaidOrderTtlConfig { guestMins registeredMins }
  }
}
```

## Create Shop
```graphql
mutation CreateShop($name: String!, $businessCategoryId: String, $ownerFullname: String, $ownerPhone: String, $location: String) {
  shopCreate(name: $name, businessCategoryId: $businessCategoryId, ownerFullname: $ownerFullname, ownerPhone: $ownerPhone, location: $location) {
    id name
  }
}
```

## Update Shop Name
```graphql
mutation UpdateName($shopId: String!, $name: String!) {
  shopUpdateName(shopId: $shopId, name: $name) { id name }
}
```

## Update Logo
Upload image first via `POST /uploads/s3` (see SKILL.md for details), then:
```graphql
mutation UpdateLogo($shopId: String!, $logo: String!) {
  shopUpdateLogo(shopId: $shopId, logo: $logo) { id logo }
}
```

## Activate / Deactivate Shop
```graphql
mutation Activate($shopId: String!, $active: Boolean!) {
  shopActivate(shopId: $shopId, active: $active)
}
```

## Set Shop Location (GPS)
```graphql
mutation SetLatLon($shopId: String!, $lat: Float!, $lon: Float!, $useAsDefault: Boolean!) {
  shopUpdateLatlong(shopId: $shopId, lat: $lat, lon: $lon, useAsDefaultStockLocation: $useAsDefault) {
    id latlong { lat lon }
  }
}
```

## Set Operational Mode
```graphql
mutation SetMode($shopId: String!, $operationalMode: OperationalMode!) {
  shopSetOperationalMode(shopId: $shopId, operationalMode: $operationalMode)
}
```
`OperationalMode`: `OPEN | CLOSED | BUSY`

## Set Operational Distance
Max delivery radius in meters.
```graphql
mutation SetDistance($shopId: String!, $operationalDistant: Int!) {
  shopSetOperationalDistant(shopId: $shopId, operationalDistant: $operationalDistant)
}
```

## Set Shipping Model
```graphql
mutation SetShipping($shopId: String!, $shippingModel: ShippingModel!) {
  shopSetShippingModel(shopId: $shopId, shippingModel: $shippingModel)
}
```
`ShippingModel`: `DISTANCE_BASED | ZONE_BASED | FLAT_RATE | THIRD_PARTY_ONLY`

## Transfer Ownership
```graphql
mutation Transfer($shopId: String!, $newOwnerId: String!, $roleId: String) {
  shopTransfer(shopId: $shopId, newOwnerId: $newOwnerId, roleId: $roleId)
}
```
**Dangerous**: Confirm with user multiple times.

## Connect Telegram Bot
```graphql
mutation ConnectBot($shopId: String!, $botToken: String!) {
  botCreate(shopId: $shopId, botToken: $botToken)
}
```

## Toggle Plugin Access
```graphql
mutation SetPluginAccess($shopId: String!, $enabled: Boolean!) {
  shopSetPluginAccess(shopId: $shopId, enabled: $enabled)
}
```

## List Customers
```graphql
query Customers($shopId: String!) {
  customers(shopId: $shopId) {
    id userId shopId createdAt
    user { id tgFirstname tgLastname tgUsername tgAvatar }
  }
}
```

## Get Notifications
```graphql
query Notifications($shopId: String!) {
  getNotifications(shopId: $shopId) {
    id title description read type source sourceId createdAt
  }
}
```

## Current User (Me)
```graphql
query Me {
  me { id tgAvatar tgUsername tgFirstname tgLastname role createdAt active }
}
```

## Look Up User by ID
```graphql
query UserById($userId: String!) {
  getUserById(userId: $userId) { id tgUsername tgFirstname tgLastname tgAvatar }
}
```
