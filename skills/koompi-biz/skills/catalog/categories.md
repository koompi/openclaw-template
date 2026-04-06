# Categories & Subcategories

## List Categories
```graphql
query GetCategories($shopId: String!) {
  getCategoriesByShop(shopId: $shopId) {
    id name shopId group logo createdAt
    products { id }  # just IDs for count
  }
}
```

## Get Single Category (with products)
```graphql
query GetCategory($categoryId: String!) {
  getCategory(categoryId: $categoryId) {
    id name shopId group logo createdAt
    products { id name price images onSale archived }
  }
}
```

## Create Category
```graphql
mutation CreateCategory($name: String!, $shopId: String!, $group: String!, $logo: String) {
  createCategory(name: $name, shopId: $shopId, group: $group, logo: $logo) {
    id name
  }
}
```
`group` must be one of: `"Product"`, `"Event"`, `"Post"`. For shop products, always use `"Product"`.

## Update Category
```graphql
mutation UpdateCategory($categoryId: String!, $name: String!, $shopId: String!, $logo: String) {
  updateCategory(categoryId: $categoryId, name: $name, shopId: $shopId, logo: $logo) {
    id name
  }
}
```

## Delete Category
> ⚠️ **CONFIRMATION REQUIRED** — Show category name and warn that products will become uncategorized. Wait for explicit "Yes".
```graphql
mutation DeleteCategory($categoryId: String!, $shopId: String!) {
  deleteCategory(categoryId: $categoryId, shopId: $shopId)
}
```

---

## Subcategories

### List Subcategories
```graphql
query GetSubcategories($shopId: String!, $categoryId: String!) {
  getSubcategoriesByShop(shopId: $shopId, categoryId: $categoryId) {
    id name shopId categoryId logo createdAt
  }
}
```

### Create Subcategory
```graphql
mutation CreateSubcategory($name: String!, $shopId: String!, $categoryId: String!, $logo: String) {
  createSubcategory(name: $name, shopId: $shopId, categoryId: $categoryId, logo: $logo) {
    id name
  }
}
```

### Update Subcategory
```graphql
mutation UpdateSubcategory($subcategoryId: String!, $shopId: String!, $name: String!, $logo: String!) {
  updateSubcategory(subcategoryId: $subcategoryId, shopId: $shopId, name: $name, logo: $logo) {
    id name
  }
}
```

### Delete Subcategory
> ⚠️ **CONFIRMATION REQUIRED** — Show subcategory name and confirm before executing.
```graphql
mutation DeleteSubcategory($shopId: String!, $subcategoryId: String!) {
  deleteSubcategory(shopId: $shopId, subcategoryId: $subcategoryId)
}
```
