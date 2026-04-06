# Inventory Locations

Stock is tracked per-location. Every shop needs at least one location. Most shops have one default.

## List Locations
```graphql
query GetLocations($shopId: String!) {
  getInventoryLocationsByShop(shopId: $shopId) {
    id name description locationType isDefault fulfillmentTypes createdAt
  }
}
```

## Get Default Location
```graphql
query GetDefaultLocation($shopId: String!) {
  getDefaultLocation(shopId: $shopId) {
    id name description locationType isDefault fulfillmentTypes
  }
}
```

## Create Location
```graphql
mutation CreateLocation($shopId: String!, $locationType: InventoryLocationType!, $name: String!, $description: String) {
  createInventoryLocation(shopId: $shopId, locationType: $locationType, name: $name, description: $description) {
    id name locationType isDefault
  }
}
```
`InventoryLocationType`: `WAREHOUSE | STORE | DISPLAY`

## Update Location
```graphql
mutation UpdateLocation($shopId: String!, $locationId: String!, $name: String, $description: String, $locationType: InventoryLocationType) {
  updateInventoryLocation(shopId: $shopId, locationId: $locationId, name: $name, description: $description, locationType: $locationType) {
    id name
  }
}
```

## Delete Location
> ⚠️ **CONFIRMATION REQUIRED** — Show location name and warn this is permanent. Only empty locations can be deleted.
```graphql
mutation DeleteLocation($shopId: String!, $locationId: String!) {
  deleteInventoryLocation(shopId: $shopId, locationId: $locationId)
}
```

## Set Default Location
```graphql
mutation SetDefault($shopId: String!, $locationId: String!) {
  setDefaultInventoryLocation(shopId: $shopId, locationId: $locationId) {
    id name isDefault
  }
}
```

## Set Fulfillment Types for Location
Controls which order types debit from this location.
```graphql
mutation SetFulfillmentTypes($shopId: String!, $locationId: String!, $fulfillmentTypes: [FulfillmentAssignment!]!) {
  setLocationFulfillmentTypes(shopId: $shopId, locationId: $locationId, fulfillmentTypes: $fulfillmentTypes) {
    id fulfillmentTypes
  }
}
```

---

## Agent Notes
- **First-time setup**: If user enables `stocking` module but has no locations, auto-create one: `name: "Main Store", locationType: STORE`.
- Most single-location shops just need the default. Only suggest multi-location for businesses with warehouses.
