# Products

## List All Products (paginated)
```graphql
query PaginatedProducts($shopId: String!, $limit: Int!, $page: Int!, $locationId: String) {
  paginatedProducts(shopId: $shopId, limit: $limit, page: $page) {
    data {
      id
      name
      price
      images
      onSale
      archived
      categoryId
      brandId
      stockBalance(locationId: $locationId)
      variants { id sku price active stockBalance(locationId: $locationId) variantAttributes { attributeName value } }
    }
    totalDocuments
    totalPages
  }
}
```

## Search Products
```graphql
query ProductSearch($shopId: String!, $keyword: String, $filter: FilterStateInput, $locationId: String) {
  productSearch(shopId: $shopId, keyword: $keyword, filter: $filter) {
    id
    name
    price
    description
    images
    onSale
    archived
    categoryId
    brandId
    tags
    stockBalance(locationId: $locationId)
    variants { id sku price active stockBalance(locationId: $locationId) variantAttributes { attributeName value } }
  }
}
```
`FilterStateInput` is optional. Fields: `{ filterBy: FilterType, categories: [String], subCategories: [String], brands: [String], sortBy: SortOption, limit: Int, items: [String] }`.

## Get Single Product
```graphql
query ProductById($productId: String!, $locationId: String) {
  productId(productId: $productId) {
    id name description price images shopId tags onSale archived isPreorder preorderDeposit
    categoryId category { id name } brandId subCategories detail
    lowStockThreshold maxQuantityPerOrder
    options { id name values { id name extraAmount image } }
    variants { id sku price images active lowStockThreshold stockBalance(locationId: $locationId) variantAttributes { attributeName value displayOrder } }
    stockBalance(locationId: $locationId)
  }
}
```

## Create Product
All prices are **String** type (e.g. `"12.50"`).
```graphql
mutation CreateProduct(
  $shopId: String!
  $name: String!
  $price: String!
  $description: String
  $images: [String!]
  $options: [ProductOptionsInput!]!  # pass [] if none
  $tags: [String!]
  $category: String       # categoryId
  $isPreorder: Boolean!   # false for normal products
  $preorderDeposit: String
  $brandId: String
  $subCategories: [String!]
  $detail: String
) {
  productCreate(
    shopId: $shopId name: $name price: $price description: $description
    images: $images options: $options tags: $tags category: $category
    isPreorder: $isPreorder preorderDeposit: $preorderDeposit
    brandId: $brandId subCategories: $subCategories detail: $detail
  ) {
    id name price
  }
}
```

### ProductOptionsInput (non-stock options like "Sugar Level")
```json
{ "name": "Ice Level", "values": [{ "name": "No Ice" }, { "name": "Less Ice" }, { "name": "Normal Ice" }] }
```
Each value can optionally have `extraAmount: "0.50"` and `image: "/path"`.

## Update Product
Same fields as Create, plus `$productId: String!`:
```graphql
mutation ProductUpdate(
  $shopId: String! $productId: String!
  $name: String! $price: String! $description: String $images: [String!]
  $options: [ProductOptionsUpdateInput!]!
  $tags: [String!] $category: String $isPreorder: Boolean!
  $preorderDeposit: String $brandId: String $subCategories: [String!] $detail: String
) {
  productUpdate(
    shopId: $shopId productId: $productId name: $name price: $price
    description: $description images: $images options: $options tags: $tags
    category: $category isPreorder: $isPreorder preorderDeposit: $preorderDeposit
    brandId: $brandId subCategories: $subCategories detail: $detail
  ) { id name price }
}
```
**ProductOptionsUpdateInput** includes `_id` for existing options: `{ "_id": "abc", "name": "Size", "values": [{ "_id": "v1", "name": "S" }] }`.

## Toggle On Sale
```graphql
mutation SetOnSale($shopId: String!, $productId: String!, $onSale: Boolean!) {
  productSetOnSale(shopId: $shopId, productId: $productId, onSale: $onSale)
}
```

## Archive / Unarchive
> ⚠️ **CONFIRMATION REQUIRED** — When archiving, summarize the product name and ask user to confirm.
```graphql
mutation SetArchived($shopId: String!, $productId: String!, $archived: Boolean!) {
  productSetArchived(shopId: $shopId, productId: $productId, archived: $archived)
}
```

## Permanently Delete
> ⚠️ **CONFIRMATION REQUIRED** — Show product name/price and warn this is irreversible. Wait for explicit "Yes".
```graphql
mutation DeleteProduct($productId: String!, $shopId: String!) {
  productDelete(productId: $productId, shopId: $shopId)
}
```

## Set Max Order Quantity
```graphql
mutation SetMaxQty($shopId: String!, $productId: String!, $maxQuantity: Int) {
  setMaxOrderQuantity(shopId: $shopId, productId: $productId, maxQuantity: $maxQuantity) { id }
}
```
Pass `null` to remove the limit.

## Get Archived Products
```graphql
query ArchivedProducts($shopId: String!) {
  getArchivedProducts(shopId: $shopId) { id name price images stockBalance }
}
```

---

## Agent Notes
- **Images**: Upload files via `POST https://api.riverbase.org/uploads/s3` (multipart, field name `file`, header `authorization: <token>`). Returns a full CDN URL like `https://cdn.riverbase.org/uuid.webp` — pass that URL in the `images` array. Images are auto-converted to WebP (800px max width).
- **Variants vs Options**: `variants` are stock-tracked (Size L = separate SKU). `options` are non-stock (Sugar Level = no inventory impact). Use variants when the shop needs per-attribute stock tracking.
- **Filtering tip**: Use `keyword` for text search. Use `filter.categories` to narrow by category ID array.
