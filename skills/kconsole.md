# KConsole — Deploy & Manage KOOMPI Cloud Services

Interact with KOOMPI Cloud KConsole to deploy apps, databases, and VPS instances.

## Authentication

All requests require:
```bash
Authorization: Bearer $KCONSOLE_API_TOKEN
```

**API Base URL:** `https://api-kconsole.koompi.cloud`

**Verify credentials & get Org ID:**
```bash
curl -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  https://api-kconsole.koompi.cloud/api/auth/me
```
Extract `organization._id` from the response — this is your `{orgId}`.

---

## Core Rules

1. **NEVER DELETE unless explicitly asked.** "Update the app", "Deploy new version" → use PUT or reupload, never DELETE.
2. **Self-learning:** When you get a 400/404 from KConsole, update this file with the new schema before retrying.
3. Always include all env vars when updating (PUT replaces the entire array).

---

## List & Get Services

```bash
# List services in org
curl -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  https://api-kconsole.koompi.cloud/api/orgs/{orgId}/services

# Get one service
curl -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  https://api-kconsole.koompi.cloud/api/services/{serviceId}
```

---

## Create Services

### Git Service
```bash
curl -s -X POST "https://api-kconsole.koompi.cloud/api/orgs/{orgId}/services/git" \
  -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-app",
    "source": {
      "repository": "https://github.com/user/my-app",
      "branch": "main",
      "buildType": "dockerfile"
    },
    "resourceSizeId": "small"
  }'
```

### Docker Image Service
```bash
curl -s -X POST "https://api-kconsole.koompi.cloud/api/orgs/{orgId}/services/image" \
  -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "nginx-app", "image": "nginx:latest", "resourceSizeId": "small"}'
```

### Zip Upload Service
1. Get upload token: `POST /api/orgs/{orgId}/storage/upload-token` → `{uploadUrl, r2Key}`
2. `PUT {uploadUrl}` with zip binary
3. Create service: `POST /api/orgs/{orgId}/services/upload` with `{name, r2Key, fileName, fileSize, buildType: "auto", resourceSizeId}`

### Database
```bash
curl -s -X POST "https://api-kconsole.koompi.cloud/api/orgs/{orgId}/services/database" \
  -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-postgres",
    "engine": "postgres",
    "version": "15",
    "databaseName": "appdb",
    "username": "admin",
    "password": "SecurePassword123!",
    "enableTunnel": true,
    "resourceSizeId": "small",
    "storage": 20
  }'
```
*Engines: `postgres`, `mongodb`, `mysql`, `mariadb`, `redis`*

### VPS
```bash
curl -s -X POST "https://api-kconsole.koompi.cloud/api/orgs/{orgId}/services/vps" \
  -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-vps",
    "os": "ubuntu",
    "version": "22.04",
    "authType": "password",
    "password": "SecurePassword123!",
    "enableTunnel": true,
    "resourceSizeId": "medium",
    "storage": 50
  }'
```

---

## Update Service

```bash
# Update env vars + resources (include ALL env vars — replaces entire array)
curl -s -X PUT "https://api-kconsole.koompi.cloud/api/services/{serviceId}" \
  -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "envVars": [{"key": "NODE_ENV", "value": "production"}],
    "resources": {"cpu": 1, "memory": 1024, "replicas": 1}
  }'
```

---

## Deploy & Rollback

```bash
# Redeploy current version
curl -s -X POST "https://api-kconsole.koompi.cloud/api/services/{serviceId}/redeploy" \
  -H "Authorization: Bearer $KCONSOLE_API_TOKEN"

# Upload new zip version (does NOT delete service)
curl -s -X POST "https://api-kconsole.koompi.cloud/api/services/{serviceId}/reupload" \
  -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"r2Key": "org_xxx/private/v2.zip", "fileName": "v2.zip", "fileSize": 5300000}'

# Rollback to version N
curl -s -X POST "https://api-kconsole.koompi.cloud/api/services/{serviceId}/rollback" \
  -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"version": 2}'
```

---

## Logs

```bash
# Build logs
curl -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  "https://api-kconsole.koompi.cloud/api/builds/{serviceId}"

# Runtime logs (last 1000 lines)
curl -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  "https://api-kconsole.koompi.cloud/api/logs/{serviceId}?limit=1000"
```

---

## Domains

```bash
# Set public subdomain
curl -s -X PUT "https://api-kconsole.koompi.cloud/api/services/{serviceId}" \
  -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"domain": "my-app"}'

# Add custom domain (DNS: CNAME app.example.com → tunnel.koompi.cloud)
curl -s -X POST "https://api-kconsole.koompi.cloud/api/services/{serviceId}/domain/custom" \
  -H "Authorization: Bearer $KCONSOLE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"domain": "app.example.com", "email": "admin@example.com"}'
```

---

## Resource Sizes

| ID | CPU | Memory | Storage |
|---|---|---|---|
| `nano` | 0.25 | 256MB | 10GB |
| `micro` | 0.5 | 512MB | 20GB |
| `small` | 1 | 1024MB | 50GB |
| `medium` | 2 | 2048MB | 100GB |
| `large` | 4 | 4096MB | 200GB |
| `xlarge` | 8 | 8192MB | 500GB |
