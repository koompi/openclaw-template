# Team Management (Roles & Members)

## Roles

### Create Role
```graphql
mutation CreateRole($shopId: String!, $title: String!, $actions: [String!]!) {
  shopRoleAdd(shopId: $shopId, title: $title, actions: $actions)
}
```

### Update Role
```graphql
mutation UpdateRole($roleId: String!, $shopId: String!, $title: String!, $actions: [String!]!) {
  shopRoleUpdate(roleId: $roleId, shopId: $shopId, title: $title, actions: $actions)
}
```

### Delete Role
> ⚠️ **CONFIRMATION REQUIRED** — Show role title and confirm before deleting.
```graphql
mutation DeleteRole($roleId: String!, $shopId: String!) {
  shopRoleDelete(roleId: $roleId, shopId: $shopId)
}
```

### Available role actions
Roles are a list of permission strings. Common actions:
```
manage_products, manage_orders, manage_inventory, manage_settings,
manage_members, manage_discounts, manage_shipping, view_reports,
manage_posts, manage_events, manage_quotations
```

---

## Members

### Add Member
```graphql
mutation AddMember($shopId: String!, $userId: String!, $roleId: String!) {
  shopMemberAdd(shopId: $shopId, roleId: $roleId, userId: $userId) { id }
}
```
`userId` is the Telegram user's Riverbase ID. The user must have an account first.

### Update Member Role
```graphql
mutation UpdateMember($shopId: String!, $memberId: String!, $roleId: String!) {
  shopMemberUpdate(shopId: $shopId, roleId: $roleId, memberId: $memberId) { id }
}
```

### Remove Member
> ⚠️ **CONFIRMATION REQUIRED** — Show member name/username and role before removing. Wait for explicit "Yes".
```graphql
mutation RemoveMember($shopId: String!, $memberId: String!) {
  shopMemberRemove(memberId: $memberId, shopId: $shopId)
}
```

---

## View Current Team
The shop query includes members:
```graphql
query ShopTeam($shopId: String!) {
  shopId(shopId: $shopId) {
    members {
      id userId
      role { id title actions }
      user { id tgUsername tgFirstname tgLastname }
    }
    roles { id title actions isDefault }
  }
}
```

---

## Agent Notes
- **Owner cannot be removed**. The owner is identified by `ownerId` on the shop object.
- **Default role**: Each shop has one default role (`isDefault: true`). New members without a specific role assignment get this one.
- **Finding userId**: If the user says "add @username as staff", you'll need to look up their userId. This may require the user to interact with the bot first.
