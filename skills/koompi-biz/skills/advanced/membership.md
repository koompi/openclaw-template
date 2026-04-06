# Memberships & VIP Tiers

Manage loyalty programs with tiered membership cards.

## Tiers

### List Tiers
```graphql
query MembershipTiers($shopId: String!) {
  getMembershipTeirsByShop(shopId: $shopId) {
    id shopId name target description cardImage cardImageMobile
  }
}
```

### Create Tier
```graphql
mutation CreateTier(
  $shopId: String! $name: String! $target: MembershipTarget!
  $description: String $cardImage: String $cardImageMobile: String
) {
  createTeir(shopId: $shopId, name: $name, target: $target, description: $description, cardImage: $cardImage, cardImageMobile: $cardImageMobile) {
    id name
  }
}
```
`MembershipTarget`: `CUSTOMER | RESELLER | AFFILIATE`

### Update Tier
```graphql
mutation UpdateTier($teirId: String!, $name: String!, $target: MembershipTarget!, $description: String, $cardImage: String, $cardImageMobile: String) {
  updateTeir(teirId: $teirId, name: $name, target: $target, description: $description, cardImage: $cardImage, cardImageMobile: $cardImageMobile) { id name }
}
```

### Delete Tier
> ⚠️ **CONFIRMATION REQUIRED** — Show tier name and warn that all memberships under this tier will be affected.
```graphql
mutation DeleteTier($teirId: String!) {
  deleteTeir(teirId: $teirId)
}
```

---

## Memberships (assigning users to tiers)

### List All Memberships
```graphql
query Memberships($shopId: String!) {
  getMemberships(shopId: $shopId) {
    id cardId shopId userId tierId isActive startsAt expiresAt isValid createdAt
    tier { id name target }
    user { id tgFirstname tgLastname tgUsername tgAvatar }
  }
}
```

### Get by Card ID (QR scan)
```graphql
query MembershipByCard($cardId: String!) {
  getMembershipByCardId(cardId: $cardId) {
    id userId tierId isActive isValid
    tier { name } user { tgFirstname tgLastname }
  }
}
```

### Create Membership
```graphql
mutation CreateMembership($shopId: String!, $userId: String!, $tierId: String!, $isActive: Boolean!, $startsAt: ScalarDateTimeUtc, $expiresAt: ScalarDateTimeUtc) {
  createMembership(shopId: $shopId, userId: $userId, tierId: $tierId, isActive: $isActive, startsAt: $startsAt, expiresAt: $expiresAt) {
    id cardId isActive
  }
}
```

### Update Membership
```graphql
mutation UpdateMembership($membershipId: String!, $tierId: String!, $isActive: Boolean!, $startsAt: ScalarDateTimeUtc, $expiresAt: ScalarDateTimeUtc, $cardId: String) {
  updateMembership(membershipId: $membershipId, tierId: $tierId, isActive: $isActive, startsAt: $startsAt, expiresAt: $expiresAt, cardId: $cardId) {
    id isActive
  }
}
```

### Delete Membership
> ⚠️ **CONFIRMATION REQUIRED** — Show member name and tier before revoking. Wait for explicit "Yes".
```graphql
mutation DeleteMembership($membershipId: String!) {
  deleteMembership(membershipId: $membershipId)
}
```

---

## Agent Notes
- **Membership discounts**: Memberships tie into the discount system. Create a discount rule with `targetUsage: MEMBERSHIP` and `targetMembershipId` pointing to a tier ID. See `admin/discounts.md`.
- **Card IDs**: Auto-generated unique card codes for physical/digital membership cards.
- Dates use `ScalarDateTimeUtc` — pass as ISO 8601 string.
