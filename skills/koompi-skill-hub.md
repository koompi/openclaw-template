---
name: koompi-skill-hub
description: Manage and publish skills on KOOMPI Skill Hub. Use this skill to submit new skills for review, list available skills, manage API keys, and for super admins to review and accept/reject submissions. Requires a KOOMPI OAuth token.
---

# KOOMPI Skill Hub Agent Skill

This skill enables the agent to interact with the KOOMPI Skill Hub API to manage the lifecycle of AI skills, API keys, and categories.

## Core Directives

1. **Skill Lifecycle Management**
   - **Submit Skill**: When a user wants to "publish" or "submit" a skill:
     1. Collect required info: `name`, `files` (array of `{name, content}`), `category`, and `description`.
     2. Use `POST /api/skills` to submit.
     3. Inform the user that the skill is now "pending" review.
   - **Update Skill**: Owners or Admins can use `PATCH /api/skills/{id}` to update a skill. This resets the status to `pending`.
   - **List Skills**: Use `GET /api/skills`.
     - Guests/Unauthenticated: See only `accepted` skills.
     - Users: See `accepted` skills and their own submissions.
     - Super Admins: See all skills.
   - **Fetch & Use a Skill**: When a user asks to "use", "load", or "run" a skill from the hub:
     1. Call `GET https://skill.koompi.ai/api/skills` (no auth needed for accepted skills).
     2. Find the matching skill by `name` or `id` in the response.
     3. Parse the `files` field (JSON array of `{name, content}`) to get the skill's files.
     4. Read the `SKILL.md` entry — its `content` is the full skill instruction set.
     5. Follow those instructions as if the skill had been loaded directly.

2. **Super Admin Review Workflow**
   - If the user is a superadmin and wants to "review", "approve", or "reject" skills:
     1. Use `GET /api/skills` to list all skills.
     2. Filter for skills with `status: "pending"`.
     3. Use `PUT /api/skills/{id}` with `{"status": "accepted"}` or `{"status": "rejected"}` to update.

3. **API Key Management**
   - Users can manage their API keys for programmatic access.
   - **List Keys**: `GET /api/keys`.
   - **Create Key**: `POST /api/keys` with `{"name": string}`.
   - **Delete Key**: `DELETE /api/keys/{id}`.

4. **Category Management**
   - **List Categories**: `GET /api/categories` (Public).
   - **Manage Categories (Admin Only)**: `POST /api/categories` to create and `DELETE /api/categories/{id}` to remove.

5. **Skill File Storage**
   - Skill files are stored directly in SQLite as a JSON array on the `files` field.
   - Each entry: `{"name": string, "content": string}`.
   - There is no separate upload step — pass `files` directly when submitting or updating a skill.

## Authentication & Verification

All API requests (except public GETs) require:
```bash
Authorization: Bearer {KOOMPI_TOKEN}
```

**API Base URL:** `https://skill.koompi.ai` (or current project host)

**Verify Identity:**
The hub uses `https://oauth.koompi.org/v2/oauth/userinfo` to verify tokens and retrieve the user's role (user or superadmin).

## API Reference

### Skills
- `GET /api/skills` - List skills (context-aware). Response: `{ skills: Skill[] }`
  ```
  Skill {
    id: string
    name: string
    description: string
    category: string
    status: "accepted" | "pending" | "rejected"
    author_name: string
    files: string  // JSON-encoded [{name: string, content: string}]
    created_at: string
  }
  ```
  To read files: `JSON.parse(skill.files)` → `[{name, content}]`
- `POST /api/skills` - Submit new skill. Body: `{"name", "files": [{"name", "content"}], "category"?, "description"?}`.
- `PATCH /api/skills/{id}` - Update skill (Owner/Admin). Body: `{"name", "files": [{"name", "content"}], "category"?, "description"?}`.
- `PUT /api/skills/{id}` - Review skill (Admin). Body: `{"status": "accepted" | "rejected" | "pending"}`.
- `DELETE /api/skills/{id}` - Delete skill (Owner/Admin).

### API Keys
- `GET /api/keys` - List your API keys.
- `POST /api/keys` - Create new API key. Body: `{"name": string}`.
- `DELETE /api/keys/{id}` - Revoke API key.

### Categories
- `GET /api/categories` - List categories.
- `POST /api/categories` - Create category (Admin). Body: `{"name": string}`.
- `DELETE /api/categories/{id}` - Delete category (Admin).

### Uploads
- ~~Upload endpoints removed — files are stored directly in SQLite.~~

## Quick Operations Guide

- **Fetch all available skills (no auth needed):**
  ```bash
  curl https://skill.koompi.ai/api/skills
  ```
  Then find the skill you want and read `JSON.parse(skill.files)` to get the file contents.

- **Approve a skill (Super Admin):**
  ```bash
  curl -X PUT https://skill.koompi.ai/api/skills/{id} \
    -H "Authorization: Bearer {TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"status": "accepted"}'
  ```

- **Submit a skill:**
  ```bash
  curl -X POST https://skill.koompi.ai/api/skills \
    -H "Authorization: Bearer {TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"name": "MySkill", "description": "What it does", "category": "Coding", "files": [{"name": "SKILL.md", "content": "---\nname: MySkill\n---\n# Instructions"}]}'
  ```

- **Generate a new API Key:**
  ```bash
  curl -X POST https://skill.koompi.ai/api/keys \
    -H "Authorization: Bearer {TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"name": "Production Key"}'
  ```