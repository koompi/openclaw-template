# Custom Domain & DNS

Connect a custom domain to the shop's storefront.

## Get DNS Config
```graphql
query DnsByShop($shopId: String!) {
  getDnsByShop(shopId: $shopId) {
    id shopId hostname botName dnsOk nginxOk createdAt updatedAt
  }
}
```

## Add Custom Domain
```graphql
mutation AddDns($hostname: String!, $shopId: String!) {
  addDns(hostname: $hostname, shopId: $shopId) {
    id hostname dnsOk nginxOk
  }
}
```
`hostname` is the full domain — e.g. `"shop.mybrand.com"`.

## Update Domain
```graphql
mutation UpdateDns($hostname: String!, $shopId: String!) {
  updateDns(hostname: $hostname, shopId: $shopId) {
    id hostname dnsOk nginxOk
  }
}
```

## Delete Domain
> ⚠️ **CONFIRMATION REQUIRED** — Show the hostname and warn that the shop's custom domain will stop working immediately.
```graphql
mutation DeleteDns($shopId: String!) {
  deleteDns(shopId: $shopId)
}
```

## Activate DNS (trigger SSL provisioning)
```graphql
mutation ActivateDns($shopId: String!) {
  activateDns(shopId: $shopId)
}
```

---

## Agent Notes
- **Setup flow**: 1) User adds a CNAME record pointing to Riverbase servers. 2) Call `addDns`. 3) Call `activateDns` to trigger SSL cert provisioning.
- `dnsOk` = CNAME resolves correctly. `nginxOk` = reverse proxy configured. Both must be `true` for the domain to work.
