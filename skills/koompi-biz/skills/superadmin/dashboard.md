# Platform Dashboard (Superadmin)

> Requires `role: "admin"` on the user object.

## Platform Dashboard
```graphql
query AdminPlatformDashboard($startDate: String, $endDate: String) {
  adminPlatformDashboard(startDate: $startDate, endDate: $endDate) {
    platformTotals {
      totalUsers
      totalShops
      adminUsers
      activeUsers
      activeShops
    }
    orderMetrics {
      totalOrders
      pendingOrders
      completionRate
      completedOrders
      changeVsPreviousPeriod
      cancelledOrders
    }
    revenueMetrics {
      totalRevenue
      revenueChangePercentage
      potentialRevenue
      onlineRevenue
      codRevenue
    }
    shopHealth {
      shopsWithProducts
      shopsWithOrders
      averageProductsPerShop
      averageOrdersPerShop
    }
    dailyTimeSeries {
      date
      totalRevenue codRevenue onlineRevenue
      orderCount completedCount pendingCount cancelledCount
    }
    topShops {
      shopId shopName ownerName
      revenue orderCount completionRate
    }
    categoryBreakdown {
      categoryId categoryName
      shopCount totalOrders totalRevenue
    }
  }
}
```

### Date Filtering
- Pass `startDate` / `endDate` as ISO 8601 date strings (e.g. `"2026-01-01"`, `"2026-03-31"`)
- Omit both for all-time stats
- `changeVsPreviousPeriod` on `orderMetrics` compares the selected range against the prior equivalent range

### Key Metrics Explained
| Metric | Description |
|---|---|
| `platformTotals.activeShops` | Shops with `active: true` |
| `revenueMetrics.potentialRevenue` | Revenue from pending (unpaid) orders |
| `revenueMetrics.onlineRevenue` | Online payment revenue |
| `revenueMetrics.codRevenue` | Cash-on-delivery revenue |
| `shopHealth.averageOrdersPerShop` | Total orders / shops with orders |
| `topShops` | Ranked by revenue descending |

---

## Agent Notes
- This query is **platform-wide** — not scoped to any `shopId`.
- Only users with `role: "admin"` can access this. Regular shop owners will get an auth error.
- Use the date filter to generate periodic reports (weekly, monthly, quarterly).
