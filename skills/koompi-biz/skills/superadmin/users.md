# User Management (Superadmin)

> Requires `role: "admin"` on the user object.

## List All Users
```graphql
query AllUsers {
  users {
    id tgAvatar tgUsername tgFirstname tgLastname
    role active createdAt
  }
}
```
Returns every registered user on the platform.

**User fields:**
| Field | Type | Description |
|---|---|---|
| `id` | String | Unique user ID |
| `tgUsername` | String | Telegram @username |
| `tgFirstname` | String | Telegram first name |
| `tgLastname` | String | Telegram last name |
| `tgAvatar` | String | Telegram profile photo URL |
| `role` | String | `"user"` or `"admin"` |
| `active` | Boolean | Whether the account is active |
| `createdAt` | DateTime | Registration timestamp |

## Get User by ID
```graphql
query UserById($userId: String!) {
  getUserById(userId: $userId) {
    id tgAvatar tgUsername tgFirstname tgLastname
    role active createdAt
  }
}
```

## Activate / Freeze User
```graphql
mutation UserSetActive($userId: String!, $active: Boolean!) {
  userSetActive(userId: $userId, active: $active) {
    id tgUsername active
  }
}
```
> ⚠️ **CONFIRMATION REQUIRED** — Show username and current status. When freezing (`active: false`), warn that the user will lose access to all shops. Wait for explicit "Yes".

- `active: true` → user can access platform normally
- `active: false` → user is frozen, cannot log in or interact

---

## Agent Notes
- **Search**: The `users` query returns all users. Filter client-side by username, name, role, or active status.
- **Cannot freeze yourself**: Don't allow deactivating the currently authenticated admin user.
- **Role values**: `"user"` (regular) or `"admin"` (superadmin). Role changes are not available via GraphQL — they require backend intervention.
