# Plugins

Install and manage third-party plugins for the shop.

## List Available Plugins
```graphql
query Plugins {
  plugins {
    id name slug description icon version category active createdAt
  }
}
```

## List Installed Plugins (for a shop)
```graphql
query ShopPlugins($shopId: String!) {
  shopPlugins(shopId: $shopId) {
    id shopId pluginId config installedAt
  }
}
```

## Check if Plugin is Installed
```graphql
query HasPlugin($shopId: String!, $pluginSlug: String!) {
  shopHasPlugin(shopId: $shopId, pluginSlug: $pluginSlug)
}
```
Returns `Boolean`.

## Install Plugin
```graphql
mutation InstallPlugin($shopId: String!, $pluginId: String!, $config: String) {
  pluginInstall(shopId: $shopId, pluginId: $pluginId, config: $config) {
    id pluginId config installedAt
  }
}
```
`config` is an optional JSON string for plugin-specific settings.

## Uninstall Plugin
> ⚠️ **CONFIRMATION REQUIRED** — Show plugin name and warn that any plugin config will be lost.
```graphql
mutation UninstallPlugin($shopId: String!, $pluginId: String!) {
  pluginUninstall(shopId: $shopId, pluginId: $pluginId)
}
```

## Update Plugin Config
```graphql
mutation UpdatePluginConfig($shopId: String!, $pluginId: String!, $config: String) {
  pluginUpdateConfig(shopId: $shopId, pluginId: $pluginId, config: $config) {
    id config
  }
}
```

---

## Agent Notes
- **Plugin access gate**: The shop must have `pluginAccess: true` (set via `shopSetPluginAccess` in `admin/shop.md`) before installing any plugins.
- Known plugin slugs: `shade-finder` (AR makeup try-on).
