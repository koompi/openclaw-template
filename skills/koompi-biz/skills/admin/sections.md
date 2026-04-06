# Sections & Designs (Storefront Layout)

Sections define the layout of shop pages (homepage, etc). Each section displays products, posts, events, categories, or static images/designs.

## List Sections for a Page
```graphql
query PageSections($shopId: String!, $page: String!) {
  getPageSections(shopId: $shopId, page: $page) {
    id shopId name page displayOrder
    dataSource dataType layout
    showTitle titleAlignment padding gap
    filterCondition {
      priceRange { from to }
      sortBy filterBy categories items limit subCategories brands
    }
    staticFilter { designId images staticType }
  }
}
```
`page`: `"home"`, `"shop"`, etc.

## Get Single Section (with nested data)
```graphql
query SectionById($sectionId: String!, $skip: Int, $locationId: String) {
  getSection(sectionId: $sectionId) {
    id shopId name page dataSource displayOrder dataType
    showTitle titleAlignment padding gap layout
    filterCondition {
      priceRange { from to }
      sortBy filterBy categories items limit subCategories brands
    }
    staticFilter { designId images staticType }
    products(skip: $skip) {
      data { id name price images stockBalance: stockBalance(locationId: $locationId) }
      totalDocuments totalPages limit skip
    }
    events(skip: $skip) {
      data { id name date venue price images }
      totalDocuments totalPages
    }
    posts(skip: $skip) {
      data { id title images }
      totalDocuments totalPages
    }
    productCategories { data { id name } totalDocuments }
    eventCategories { data { id name } totalDocuments }
    postCategories { data { id name } totalDocuments }
  }
}
```

## Create Section
```graphql
mutation CreateSection(
  $shopId: String!
  $name: String!
  $page: String!
  $dataSource: DataSource!
  $layout: SectionLayout!
  $displayOrder: Int!
  $showTitle: Boolean!
  $dataType: DataType!
  $padding: SectionSpacing!
  $gap: SectionSpacing!
  $titleAlignment: TitleAlignment
  $filterCondition: FilterStateInput
  $staticFilter: StaticFilterInput
) {
  createSection(
    shopId: $shopId name: $name page: $page
    dataSource: $dataSource layout: $layout displayOrder: $displayOrder
    showTitle: $showTitle dataType: $dataType
    padding: $padding gap: $gap
    titleAlignment: $titleAlignment
    filterCondition: $filterCondition
    staticFilter: $staticFilter
  )
}
```

### Minimal examples

**Dynamic product grid (show all products):**
```json
{
  "shopId": "xxx",
  "name": "All Products",
  "page": "home",
  "dataSource": "PRODUCTS",
  "dataType": "DYNAMIC",
  "layout": "GRID2",
  "displayOrder": 0,
  "showTitle": true,
  "titleAlignment": "LEFT",
  "padding": "SM",
  "gap": "SM",
  "filterCondition": {
    "priceRange": { "from": 0, "to": 0 },
    "sortBy": "DATE_DESC",
    "filterBy": "NONE",
    "categories": [],
    "subCategories": [],
    "brands": [],
    "items": [],
    "limit": 20
  }
}
```

**Static image banner:**
```json
{
  "shopId": "xxx",
  "name": "Hero Banner",
  "page": "home",
  "dataSource": "PRODUCTS",
  "dataType": "STATIC",
  "layout": "GRID1",
  "displayOrder": 0,
  "showTitle": false,
  "padding": "NONE",
  "gap": "NONE",
  "staticFilter": {
    "staticType": "IMAGE",
    "images": ["https://cdn.riverbase.org/your-uploaded-image.webp"]
  }
}
```

**Static design (canvas design):**
```json
{
  "shopId": "xxx",
  "name": "Promo Design",
  "page": "home",
  "dataSource": "PRODUCTS",
  "dataType": "STATIC",
  "layout": "GRID1",
  "displayOrder": 1,
  "showTitle": false,
  "padding": "NONE",
  "gap": "NONE",
  "staticFilter": {
    "staticType": "DESIGN",
    "designId": "<design_id>"
  }
}
```

## Update Section
```graphql
mutation UpdateSection(
  $sectionId: String!
  $shopId: String!
  $name: String!
  $page: String!
  $dataSource: DataSource!
  $layout: SectionLayout!
  $displayOrder: Int!
  $showTitle: Boolean
  $dataType: DataType
  $padding: SectionSpacing
  $gap: SectionSpacing
  $titleAlignment: TitleAlignment
  $filterCondition: FilterStateInput
  $staticFilter: StaticFilterInput
) {
  updateSection(
    sectionId: $sectionId shopId: $shopId name: $name page: $page
    dataSource: $dataSource layout: $layout displayOrder: $displayOrder
    showTitle: $showTitle dataType: $dataType
    padding: $padding gap: $gap
    titleAlignment: $titleAlignment
    filterCondition: $filterCondition
    staticFilter: $staticFilter
  )
}
```

## Delete Section
> ⚠️ **CONFIRMATION REQUIRED** — Show section name and page before deleting. Wait for explicit "Yes".
```graphql
mutation DeleteSection($sectionId: String!, $shopId: String!) {
  deleteSection(sectionId: $sectionId, shopId: $shopId)
}
```

---

## Section Enums

```
DataSource:      PRODUCTS | EVENTS | POSTS | PRODUCT_CATEGORIES | EVENT_CATEGORIES | POST_CATEGORIES
DataType:        STATIC | DYNAMIC
SectionLayout:   GRID1 | GRID2 | GRID3 | SLIDER | HORIZONTAL_SCROLL
SectionSpacing:  NONE | SM | MD | LG
TitleAlignment:  LEFT | CENTER | RIGHT
StaticType:      DESIGN | IMAGE
SortOption:      NAME_ASC | NAME_DESC | PRICE_ASC | PRICE_DESC | DATE_ASC | DATE_DESC
FilterType:      PRICE_RANGE | CATEGORIES | SUB_CATEGORIES | BRANDS | ITEMS | PROMOTIONS | NONE | MULTI
```

---

# Designs (Canvas Editor)

Designs are visual layouts created in the canvas editor. They can be referenced by sections via `staticFilter.designId`.

## List Designs
```graphql
query DesignsByShop($shopId: String!) {
  getDesignsByShop(shopId: $shopId) {
    id shopId name output layers
    canvasSize { width height }
    createdAt
  }
}
```

## Get Design
```graphql
query DesignById($designId: String!) {
  getDesign(designId: $designId) {
    id shopId name output layers
    canvasSize { width height }
    createdAt
  }
}
```

## Create Design
```graphql
mutation CreateDesign($shopId: String!, $payload: NewDesignInput!) {
  createDesign(shopId: $shopId, payload: $payload) {
    id name output
  }
}
```

### NewDesignInput
```json
{
  "name": "Promo Banner",
  "layers": {},
  "output": "https://cdn.riverbase.org/rendered-design.webp",
  "canvasSize": { "width": 360, "height": 450 }
}
```
- `layers`: JSON object representing canvas editor layer data
- `output`: Pre-rendered image URL of the design (upload via `/uploads/s3`)
- `canvasSize`: Canvas dimensions in pixels (default 360x450)

## Update Design
```graphql
mutation UpdateDesign($shopId: String!, $designId: String!, $payload: NewDesignInput!) {
  updateDesign(shopId: $shopId, designId: $designId, payload: $payload) {
    id name output
  }
}
```

## Delete Design
> ⚠️ **CONFIRMATION REQUIRED** — Show design name and warn that sections referencing it will break. Wait for explicit "Yes".
```graphql
mutation DeleteDesign($designId: String!, $shopId: String!) {
  deleteDesign(shopId: $shopId, designId: $designId)
}
```

---

## Agent Notes
- **Typical flow for AI**: For a simple product section, create a `DYNAMIC` section with `dataSource: PRODUCTS` and `layout: GRID2`. For a banner image, upload an image via `/uploads/s3` then create a `STATIC` section with `staticFilter.images`.
- **Display order**: Sections are rendered in `displayOrder` order (0 = first). When adding a new section, query existing sections first and set `displayOrder` to max + 1.
- **Design vs Image**: `STATIC` sections can show either a pre-made `DESIGN` (from the canvas editor) or raw `IMAGE` URLs. AI agents should use `IMAGE` type with uploaded CDN URLs.
- **Page values**: Usually `"home"` for the shop homepage. Other page names may exist depending on shop configuration.
