# Shop Appearance & Branding

Customize shop theme colors, border radius, and fonts via the GraphQL API.

---

## Endpoints

| Endpoint | Purpose |
|---|---|
| `POST https://api.riverbase.org/graphql` | All GraphQL operations |
| `POST https://api.riverbase.org/uploads/font` | Upload custom font files (`.woff2`, `.woff`, `.ttf`, `.otf`, max 2 MB per file, field name `file`, returns CDN URL) |

---

## Get Current Theme

```graphql
query ThemeByShop($shopId: String!) {
  themeByShop(shopId: $shopId) {
    shopId
    radius
    color {
      background
      foreground
      card
      cardForeground
      popover
      popoverForeground
      primary
      primaryForeground
      secondary
      secondaryForeground
      muted
      mutedForeground
      accent
      accentForeground
      destructive
      destructiveForeground
      border
      input
      ring
      chart1
      chart2
      chart3
      chart4
      chart5
    }
    font {
      source
      google {
        family
        weights
      }
      custom {
        familyName
        weights {
          weight
          fileUrl
        }
      }
    }
  }
}
```

---

## Update Theme

> **Important:** The `theme` argument is `JSON!` — send the full theme object as a JSON value (not a typed input).

```graphql
mutation UpdateTheme($shopId: String!, $theme: JSON!) {
  updateTheme(shopId: $shopId, theme: $theme) {
    shopId
    radius
    color {
      background
      foreground
      primary
      primaryForeground
      secondary
      secondaryForeground
      accent
      accentForeground
      card
      cardForeground
      muted
      mutedForeground
      popover
      popoverForeground
      destructive
      destructiveForeground
      border
      input
      ring
      chart1
      chart2
      chart3
      chart4
      chart5
    }
    font {
      source
      google {
        family
        weights
      }
      custom {
        familyName
        weights {
          weight
          fileUrl
        }
      }
    }
  }
}
```

### Theme JSON Structure

The `$theme` variable must be a JSON object matching this exact shape (all fields required):

```json
{
  "shop_id": "<SHOP_ID>",
  "radius": "0.5rem",
  "color": {
    "background": "hsl(0 0% 100%)",
    "foreground": "hsl(0 0% 3.9%)",
    "card": "hsl(0 0% 100%)",
    "cardForeground": "hsl(0 0% 3.9%)",
    "popover": "hsl(0 0% 100%)",
    "popoverForeground": "hsl(0 0% 3.9%)",
    "primary": "hsl(152 62% 39%)",
    "primaryForeground": "hsl(0 0% 98%)",
    "secondary": "hsl(0 0% 96.1%)",
    "secondaryForeground": "hsl(0 0% 9%)",
    "muted": "hsl(0 0% 96.1%)",
    "mutedForeground": "hsl(0 0% 45.1%)",
    "accent": "hsl(0 0% 96.1%)",
    "accentForeground": "hsl(0 0% 9%)",
    "destructive": "hsl(0 84.2% 60.2%)",
    "destructiveForeground": "hsl(0 0% 98%)",
    "border": "hsl(0 0% 89.8%)",
    "input": "hsl(0 0% 89.8%)",
    "ring": "hsl(0 0% 3.9%)",
    "chart1": "hsl(12 76% 61%)",
    "chart2": "hsl(173 58% 39%)",
    "chart3": "hsl(197 37% 24%)",
    "chart4": "hsl(43 74% 66%)",
    "chart5": "hsl(27 87% 67%)"
  },
  "font": {
    "source": "Google",
    "google": {
      "family": "Inter",
      "weights": [400, 600, 700]
    },
    "custom": null
  }
}
```

> **Critical:** The JSON uses `shop_id` (snake_case) inside the theme body, while the mutation argument is `shopId` (camelCase). Color fields like `cardForeground` are camelCase. The `font.source` value must be capitalized: `"Google"` or `"Custom"`.

---

## Reset Theme to Default

```graphql
mutation ResetTheme($shopId: String!) {
  resetTheme(shopId: $shopId)
}
```

Returns `true` on success. Resets to:
- `radius`: `"1rem"`
- `font`: Google / Inter / weights `[400, 600, 700]`
- `color`: Platform default (white background, green primary)

> ⚠️ **CONFIRMATION REQUIRED** — Warn the user that this will discard all custom colors, fonts, and radius settings. Wait for explicit "Yes".

---

## Color Reference

All 24 color tokens and their purpose:

| Token | Purpose |
|---|---|
| `background` | Page background |
| `foreground` | Default text color |
| `card` | Card background |
| `cardForeground` | Card text color |
| `popover` | Popover/dropdown background |
| `popoverForeground` | Popover/dropdown text |
| `primary` | Primary buttons, links, accents |
| `primaryForeground` | Text on primary-colored elements |
| `secondary` | Secondary buttons, tags |
| `secondaryForeground` | Text on secondary elements |
| `muted` | Muted backgrounds (disabled states) |
| `mutedForeground` | Muted/placeholder text |
| `accent` | Hover highlights, subtle accents |
| `accentForeground` | Text on accent elements |
| `destructive` | Delete/error buttons |
| `destructiveForeground` | Text on destructive elements |
| `border` | Default border color |
| `input` | Input field border |
| `ring` | Focus ring color |
| `chart1`–`chart5` | Dashboard chart palette |

Colors use HSL format: `"hsl(210 65% 9%)"` or `"hsl(0, 0%, 100%)"`.

---

## Font Settings

### Option A — Google Font

```json
{
  "source": "Google",
  "google": {
    "family": "Poppins",
    "weights": [400, 600, 700]
  },
  "custom": null
}
```

**Popular Google Fonts:** Inter, Roboto, Open Sans, Lato, Montserrat, Poppins, Comfortaa, Raleway, Nunito, Playfair Display, Merriweather, Oswald, Source Sans Pro, PT Sans, Ubuntu, Noto Sans, Work Sans, Fira Sans, Quicksand, Bebas Neue.

**Available weights:** 100 (Thin), 200 (Extra Light), 300 (Light), 400 (Regular), 500 (Medium), 600 (Semi Bold), 700 (Bold), 800 (Extra Bold), 900 (Black).

### Option B — Custom Font (uploaded)

1. Upload each font weight file via `POST /uploads/font` (multipart, field `file`, auth header required). The response is the CDN URL.
2. Set the font in the theme:

```json
{
  "source": "Custom",
  "google": null,
  "custom": {
    "familyName": "MyBrandFont",
    "weights": [
      { "weight": 400, "fileUrl": "https://cdn.riverbase.org/fonts/abc123.woff2" },
      { "weight": 700, "fileUrl": "https://cdn.riverbase.org/fonts/def456.woff2" }
    ]
  }
}
```

**Accepted formats:** `.woff2`, `.woff`, `.ttf`, `.otf` — max 2 MB per file.

---

## Radius

Controls the global border-radius for the shop's UI. Common values:

| Value | Style |
|---|---|
| `"0rem"` | Sharp / square corners |
| `"0.25rem"` | Slightly rounded |
| `"0.5rem"` | Standard rounded |
| `"0.75rem"` | More rounded |
| `"1rem"` | Default (well-rounded) |

---

## Predefined Theme Presets

The frontend ships 8 built-in themes. When a user asks for a "style" or "vibe", suggest one of these or create a custom theme:

| Preset | Vibe |
|---|---|
| `default` | Clean white + green primary |
| `koompi` | Tech / dark accent |
| `business` | Professional / corporate |
| `emerald` | Nature / eco-friendly |
| `coffee` | Warm / café aesthetic |
| `black` | Bold dark mode |
| `light` | Minimal / bright |
| `claude` | AI-inspired palette |

---

## Workflow: Full Theme Customization

1. **Read** — Fetch the current theme with `themeByShop`.
2. **Modify** — Build the full theme JSON object with desired changes (colors, radius, font).
3. **Write** — Send the complete theme JSON via `updateTheme`. All fields must be present.
4. **Verify** — Re-fetch with `themeByShop` to confirm.

### Example: Change primary color to blue and font to Poppins

```json
{
  "query": "mutation UpdateTheme($shopId: String!, $theme: JSON!) { updateTheme(shopId: $shopId, theme: $theme) { shopId radius color { primary primaryForeground } font { source google { family weights } } } }",
  "variables": {
    "shopId": "6976183a6f36334a83e304ad",
    "theme": {
      "shop_id": "6976183a6f36334a83e304ad",
      "radius": "0.5rem",
      "color": {
        "background": "hsl(0 0% 100%)",
        "foreground": "hsl(0 0% 3.9%)",
        "card": "hsl(0 0% 100%)",
        "cardForeground": "hsl(0 0% 3.9%)",
        "popover": "hsl(0 0% 100%)",
        "popoverForeground": "hsl(0 0% 3.9%)",
        "primary": "hsl(221 83% 53%)",
        "primaryForeground": "hsl(0 0% 98%)",
        "secondary": "hsl(0 0% 96.1%)",
        "secondaryForeground": "hsl(0 0% 9%)",
        "muted": "hsl(0 0% 96.1%)",
        "mutedForeground": "hsl(0 0% 45.1%)",
        "accent": "hsl(0 0% 96.1%)",
        "accentForeground": "hsl(0 0% 9%)",
        "destructive": "hsl(0 84.2% 60.2%)",
        "destructiveForeground": "hsl(0 0% 98%)",
        "border": "hsl(0 0% 89.8%)",
        "input": "hsl(0 0% 89.8%)",
        "ring": "hsl(221 83% 53%)",
        "chart1": "hsl(12 76% 61%)",
        "chart2": "hsl(173 58% 39%)",
        "chart3": "hsl(197 37% 24%)",
        "chart4": "hsl(43 74% 66%)",
        "chart5": "hsl(27 87% 67%)"
      },
      "font": {
        "source": "Google",
        "google": {
          "family": "Poppins",
          "weights": [400, 600, 700]
        },
        "custom": null
      }
    }
  }
}
```
