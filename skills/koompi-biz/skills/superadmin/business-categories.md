# Business Categories (Superadmin)

> Requires `role: "admin"` on the user object.

Platform-wide categories that shops select during onboarding (e.g. "Food & Beverage", "Fashion", "Electronics").

## List All Business Categories
```graphql
query BusinessCategories {
  businessCategories {
    id name createdAt
  }
}
```

## Get Single Business Category
```graphql
query BusinessCategory($categoryId: String!) {
  businessCategory(categoryId: $categoryId) {
    id name createdAt
  }
}
```

## Create Business Category
```graphql
mutation CreateBusinessCategory($name: String!) {
  createBusinessCategory(name: $name) {
    id name
  }
}
```

## Update Business Category
```graphql
mutation UpdateBusinessCategory($categoryId: String!, $name: String!) {
  updateBusinessCategory(categoryId: $categoryId, name: $name) {
    id name
  }
}
```

## Delete Business Category
> ⚠️ **CONFIRMATION REQUIRED** — Show category name and warn this affects all shops tagged with it. Wait for explicit "Yes".
```graphql
mutation DeleteBusinessCategory($categoryId: String!) {
  deleteBusinessCategory(categoryId: $categoryId)
}
```

---

## Agent Notes
- These are **platform-level** categories, not shop product categories. They classify what type of business a shop is.
- Each shop has a `businessCatories` field (note: typo "Catories" is intentional — matches schema) linking to one of these.
- The platform dashboard's `categoryBreakdown` metric groups shops by these categories.
