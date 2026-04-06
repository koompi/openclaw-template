# Content: Blog Posts & Events

Requires shop modules `blogging: true` and/or `ticketing: true`.

## Blog Posts

### List Posts
```graphql
query Posts($shopId: String!) {
  getPosts(shopId: $shopId) {
    id title content images shopId createdAt
  }
}
```

### Get Post
```graphql
query Post($postId: String!) {
  getPost(postId: $postId) {
    id title content images shopId createdAt
  }
}
```

### Create Post
```graphql
mutation CreatePost($title: String!, $images: [String!]!, $hook: String!, $content: String!, $status: String!, $shopId: String!) {
  createPost(title: $title, images: $images, hook: $hook, content: $content, status: $status, shopId: $shopId)
}
```
`status`: `"published"` or `"draft"`. `hook` is a short excerpt/preview text.

### Update Post
```graphql
mutation UpdatePost($postId: String!, $shopId: String!, $title: String!, $images: [String!], $hook: String!, $content: String!, $status: String!) {
  updatePost(postId: $postId, shopId: $shopId, title: $title, images: $images, hook: $hook, content: $content, status: $status)
}
```

---

## Events

### List Active Events
```graphql
query Events($shopId: String!) {
  getActiveEvents(shopId: $shopId) {
    id name brief detail venue date price images capacity shopId createdAt
    options { id name values { id name extraAmount } }
  }
}
```

### Get Event
```graphql
query Event($eventId: String!) {
  getEvent(eventId: $eventId) {
    id name brief detail venue date price images capacity options { id name values { id name extraAmount } }
  }
}
```

### Create Event
```graphql
mutation CreateEvent(
  $shopId: String! $images: [String!]! $name: String! $brief: String! $detail: String!
  $venue: String $date: String! $price: String $options: [ProductOptionsInput!]! $capacity: Int
) {
  createEvent(shopId: $shopId, images: $images, name: $name, brief: $brief, detail: $detail, venue: $venue, date: $date, price: $price, options: $options, capacity: $capacity)
}
```
`price` is String (e.g. `"15.00"`). `date` is ISO 8601 datetime.

---

## Agent Notes
- **Posts vs Events**: Posts are blog articles. Events have a date, venue, and optional ticket price/capacity.
- **Images**: Upload first via `POST /uploads/s3`, then pass returned CDN URLs.
