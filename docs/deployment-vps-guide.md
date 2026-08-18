# Onlook VPS Deployment Guide (Docker & Docker Registry)

Deployment guide for Onlook monorepo onto CodeBadger VPS (`160.250.4.40`).

---

## 1. System & Architecture Overview

- **Monorepo**: Bun (`v1.3.1`), Next.js 16 App Router (`apps/web/client`), Drizzle ORM (`packages/db`), Supabase local/self-hosted backend (`apps/backend`).
- **Web Client Container**: Next.js standalone build running on Bun inside Docker.
- **Backend / Database**: Supabase stack or PostgreSQL running alongside web client.

---

## 2. Prerequisites

- **Local Machine**: Docker, access to Docker Registry (Docker Hub / GHCR).
- **VPS (`160.250.4.40`)**:
  - SSH key: `~/.ssh/codebadger_vps`
  - Docker & Docker Compose v2.0+ installed
  - Dedicated directory: `/opt/onlook`

---

## 3. Workflow: Docker Registry Deployment (No Source Code on VPS)

### Step 1: Build & Push Image (Local / CI)

```bash
# Define image tag
IMAGE_TAG="onlook-web:latest" # or your-registry/onlook-web:latest

# Build image
docker build -t $IMAGE_TAG .

# Push to registry (if using remote registry)
# docker push $IMAGE_TAG
```

### Step 2: Prepare VPS Directory & Configuration

On VPS (`/opt/onlook`):

1. Create `docker-compose.yml`:
```yaml
name: onlook

services:
  web-client:
    image: ghcr.io/nguyenthanhhungdev140503/onlook-web:latest
    container_name: onlook-web
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "3000:3000"
    network_mode: host
```

2. Create `.env`:
```ini
NODE_ENV=production
NEXT_PUBLIC_SITE_URL=http://160.250.4.40:3000

# Supabase Local
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon-key>
SUPABASE_DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>

# LLM Providers (OpenRouter or local 9Router)
OPENROUTER_BASE_URL=http://127.0.0.1:20129/v1
OPENROUTER_API_KEY=<your-9router-or-openrouter-key>
CSB_API_KEY=<codesandbox-key>
```

### Step 3: Run Containers on VPS

```bash
cd /opt/onlook
docker compose pull # if using remote registry
docker compose up -d
```

### Step 4: Verify Deployment

```bash
docker compose ps
curl -fsS http://127.0.0.1:3000
```

---

## 6. Port Mapping Reference & Troubleshooting

### Exposed Ports
- `3000`: Onlook Next.js Web Client
- `54321`: Supabase API Gateway (Kong)
- `54322`: PostgreSQL Database
- `54323`: Supabase Studio Dashboard
- `54327`: Supabase Analytics
- `8080` / `8081`: Onlook Editor RPC server (when running `apps/web/server`)
- `8083`: Onlook Preload server (when running `apps/web/preload`)

### Common Failure Modes & Fixes
1. **Network Connectivity between Container and Supabase**:
   - `docker-compose.yml` must retain `network_mode: host` when connecting to localhost Supabase (`127.0.0.1:54321` and `127.0.0.1:54322`).
2. **Build Memory Exhaustion**:
   - If `next build` OOMs during Docker build on low RAM VPS, add swap space (`fallocate -l 4G /swapfile && mkswap /swapfile && swapon /swapfile`) or pass `NODE_OPTIONS="--max-old-space-size=4096"`.
3. **Missing Static Files in Standalone Next.js**:
   - The standalone build step in `apps/web/client/package.json` (`build:standalone`) copies `public/` and `.next/static/` into `.next/standalone/apps/web/client/`. Ensure this step finishes without error.
