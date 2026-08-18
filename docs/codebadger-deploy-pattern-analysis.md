# CodeBadger vs Onlook: GHCR Build, Push & VPS Deployment Pattern Analysis

> **Target Codebase Investigated**: `/home/nguyen-thanh-hung/Downloads/codebadger`  
> **Destination Codebase**: `/home/nguyen-thanh-hung/Documents/onlook`  
> **Production VPS**: `160.250.4.40` (App Directory: `/opt/codebadger` for CodeBadger, `/opt/onlook` for Onlook)  
> **Primary Sources Cited**: Exact files, lines, and configurations from the CodeBadger and Onlook repositories.

---

## 1. Executive Summary & Core Mechanics

CodeBadger employs an **immutable, artifact-driven CI/CD deployment pipeline** targeting GitHub Container Registry (GHCR) and a dedicated production VPS (`160.250.4.40`). 

### Core Architecture Highlights
1. **Zero Source Code & Zero Build Toolchain on VPS**: The VPS never builds Docker images, never runs package managers (npm/bun/pip), and does not require source code checkouts.
2. **Dual-Tagging Strategy**:
   - **Canonical Tag**: Immutable Git commit SHA (`${GITHUB_SHA}` or `git rev-parse --short HEAD`). Production `.env` on VPS always binds explicitly to this SHA.
   - **Local Convenience Tag**: `:latest` tag exists solely as an alias locally on the VPS (re-pointed to the active SHA) to prevent race conditions or unexpected fallbacks.
3. **Multi-Environment Orchestration via Docker Compose**:
   - Compose files utilize standard interpolation: `image: ${IMAGE_REGISTRY:-}image-name:${IMAGE_TAG:-latest}`.
   - In local development: `IMAGE_REGISTRY` is empty, `IMAGE_TAG` defaults to `latest`.
   - In production: `IMAGE_REGISTRY=ghcr.io/<org>/`, `IMAGE_TAG=<commit-sha>`.
4. **Resilient Production Deploy & Automated Rollback**:
   - The previous active image tag is recorded in `.last-deploy` before changing configuration.
   - Post-deployment verification tests (`/health` probe + smoke tests) validate runtime health.
   - On verification failure, a trapped error (`trap 'rollback_on_error $?' ERR`) immediately reverts `.env` to the prior tag, re-tags local aliases, runs `docker compose up -d --no-build`, and exits with failure status to alert CI.

---

## 2. Deep Dive: CodeBadger Primary Sources Analysis

### 2.1 Docker Images & OCI Specifications
CodeBadger produces two distinct container images:
1. **MCP Server Container (`Dockerfile.mcp`)**:
   - Base: `python:3.13-slim` (`Dockerfile.mcp:8`).
   - OCI Annotation: `LABEL org.opencontainers.image.source="https://github.com/NguyenThanhHungDev140503/codebadger"` (`Dockerfile.mcp:12`). This is essential for automatic GitHub Actions `GITHUB_TOKEN` package write permissions without requiring manual Personal Access Tokens.
   - Docker CLI: Embeds static Docker CLI binary (`Dockerfile.mcp:15-27`) to drive the host Docker daemon via mounted socket `/var/run/docker.sock`.
2. **Joern CPG Analysis Server (`Dockerfile`)**:
   - Base: `eclipse-temurin:21-jdk-noble` (`Dockerfile:7`).
   - OCI Annotation: `LABEL org.opencontainers.image.source="https://github.com/NguyenThanhHungDev140503/codebadger"` (`Dockerfile:10`).
   - Installs Joern v4.0.594 (`Dockerfile:18-31`) and Rust toolchain (`Dockerfile:39-42`).

### 2.2 GitHub Container Registry (GHCR) Authentication & Push
CodeBadger implements two paths for GHCR build & push:

#### A. Automated Path: GitHub Actions CI/CD (`.github/workflows/deploy-vps.yml`)
- **Workflow Permissions** (`.github/workflows/deploy-vps.yml:22-24`):
  ```yaml
  permissions:
    contents: read
    packages: write
  ```
  `packages: write` grants the ephemeral `${{ secrets.GITHUB_TOKEN }}` permission to publish packages to `ghcr.io`.
- **GHCR Login Action** (`.github/workflows/deploy-vps.yml:36-41`):
  ```yaml
  - name: Log in to GitHub Container Registry
    uses: docker/login-action@v4
    with:
      registry: ghcr.io
      username: ${{ github.actor }}
      password: ${{ secrets.GITHUB_TOKEN }}
  ```
- **Buildx & Multi-Tagging Push** (`.github/workflows/deploy-vps.yml:43-67`):
  Uses `docker/setup-buildx-action@v4` and `docker/build-push-action@v7` targeting `linux/amd64`, pushing tags:
  - `ghcr.io/nguyenthanhhungdev140503/codebadger-mcp:${{ steps.image.outputs.tag }}` (where tag is `${GITHUB_SHA}`)
  - `ghcr.io/nguyenthanhhungdev140503/codebadger-mcp:latest`

#### B. Manual Path: Local Push Script (`scripts/push.sh`)
- Reads git short SHA: `SHA=$(git rev-parse --short HEAD)` (`scripts/push.sh:18`).
- Sets registry: `REGISTRY="ghcr.io/nguyenthanhhungdev140503"` (`scripts/push.sh:17`).
- Tags and pushes local images (`scripts/push.sh:22-33`):
  ```bash
  docker tag "codebadger-mcp:$SHA" "$REGISTRY/codebadger-mcp:$SHA"
  docker tag "codebadger-mcp:latest" "$REGISTRY/codebadger-mcp:latest"
  docker push "$REGISTRY/codebadger-mcp:$SHA"
  docker push "$REGISTRY/codebadger-mcp:latest"
  ```
- *Prerequisite*: Developer executes `echo $PAT | docker login ghcr.io -u <username> --password-stdin` using a Classic GitHub PAT with `write:packages` scope (`docs/deployment.md:88-90`).

### 2.3 VPS Deployment & State Preservation (`.github/workflows/deploy-vps.yml` & `scripts/deploy-prod.sh`)
- **Secrets Setup** (`.github/workflows/deploy-vps.yml:79-87`):
  - `VPS_HOST`: `root@160.250.4.40`
  - `VPS_SSH_PRIVATE_KEY`: ED25519 private key
  - `VPS_KNOWN_HOSTS`: Known host signature to prevent MITM attacks.
- **Rsync Deployment Files (Excluding State & Secrets)** (`.github/workflows/deploy-vps.yml:89-99`):
  ```bash
  rsync -az --info=progress2 \
    --exclude='.env' --exclude='playground/' --exclude='pgdata/' --exclude='logs/' \
    -e 'ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes' \
    docker-compose.yml .env.defaults scripts \
    "$VPS_HOST:$VPS_APP_DIR/"
  ```
- **Idempotent `.env` Initialization & Version Rotation** (`.github/workflows/deploy-vps.yml:158-182`):
  1. Checks if `/opt/codebadger/.env` exists; if not, writes host baseline (`.github/workflows/deploy-vps.yml:158-170`).
  2. Reads active `IMAGE_TAG` and writes it to `/opt/codebadger/.last-deploy` (`.github/workflows/deploy-vps.yml:171-179`).
  3. Updates `.env` to the incoming release SHA (`.github/workflows/deploy-vps.yml:180-182`):
     ```bash
     sed -i '/^IMAGE_REGISTRY=/d; /^IMAGE_TAG=/d' .env
     printf 'IMAGE_REGISTRY=%s/\nIMAGE_TAG=%s\n' "$IMAGE_PREFIX" "$IMAGE_TAG" >> .env
     ```
- **Service Re-creation Without Build** (`.github/workflows/deploy-vps.yml:183-193`):
  ```bash
  docker compose config --quiet
  docker compose pull
  docker tag "$IMAGE_PREFIX/codebadger-mcp:$IMAGE_TAG" codebadger-mcp:latest
  docker compose up -d --no-build
  ```
- **Automated Health Check & Rollback Trap** (`.github/workflows/deploy-vps.yml:120-156`, `194-198`):
  - Polls `http://127.0.0.1:4242/health` for up to 60 seconds (30 iterations × 2s).
  - Executes `bash scripts/smoke-test.sh`.
  - If any command fails, `trap 'rollback_on_error $?' ERR` restores `$previous_tag` from `.last-deploy` and re-deploys old containers.

---

## 3. Analysis of Onlook Current Setup

| Aspect | Onlook Status (`/home/nguyen-thanh-hung/Documents/onlook`) | CodeBadger Comparison |
|---|---|---|
| **Runtime & Framework** | Bun 1.3.1 + Next.js 16 App Router standalone (`Dockerfile:1-29`) | Python 3.13 + Java 21 / Joern |
| **Docker Build** | Single Dockerfile at root (`Dockerfile`), standalone build in `apps/web/client` | Multi-image (`Dockerfile.mcp`, `Dockerfile`) |
| **Compose Configuration** | `docker-compose.yml:1-17` contains `build:` stanza, hardcoded `apps/web/client/.env` | Clean `${IMAGE_REGISTRY:-}...${IMAGE_TAG:-latest}` parameterized references without inline build definitions |
| **CI/CD Workflows** | `.github/workflows/ci.yml` runs typecheck & tests, no build-push to GHCR | Complete CI/CD in `.github/workflows/deploy-vps.yml` building linux/amd64, pushing to GHCR, and deploying to VPS |
| **Container Networking** | `network_mode: host` to access Supabase on `127.0.0.1:54321/54322` | Bridge network `codebadger` + loopback port publishing |
| **Health Check** | Container health check using `bun -e "fetch('http://localhost:3000')"` (`Dockerfile:25-26`) | Built-in HTTP `/health` route + smoke test script |

---

## 4. Implementation Pattern for Onlook

To match CodeBadger's deployment quality, Onlook requires 4 core adjustments:

### 4.1 Update `Dockerfile` with OCI Label
In `/home/nguyen-thanh-hung/Documents/onlook/Dockerfile`:
Add OCI metadata label so GitHub Actions can link the container package to the repository:
```dockerfile
LABEL org.opencontainers.image.source="https://github.com/onlook-dev/onlook"
```

### 4.2 Parameterize `docker-compose.yml` for Registry & Local Builds
Update `/home/nguyen-thanh-hung/Documents/onlook/docker-compose.yml`:
```yaml
name: onlook

services:
  web-client:
    image: ${IMAGE_REGISTRY:-}onlook-web:${IMAGE_TAG:-latest}
    container_name: onlook-web
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "3000:3000"
    network_mode: host
```

### 4.3 Add `.env.defaults`
Create `/home/nguyen-thanh-hung/Documents/onlook/.env.defaults` to define git-tracked stable defaults:
```ini
# Production environment configuration defaults for Onlook
NODE_ENV=production
PORT=3000
NEXT_TELEMETRY_DISABLED=1
HOSTNAME=0.0.0.0

# Image registry and tag
IMAGE_REGISTRY=
IMAGE_TAG=latest
```

### 4.4 Create GitHub Actions Workflow (`.github/workflows/deploy-vps.yml`)
Create `.github/workflows/deploy-vps.yml` in Onlook:
```yaml
name: Build and deploy Onlook to VPS

on:
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: onlook-production
  cancel-in-progress: false

env:
  REGISTRY: ghcr.io
  IMAGE_PREFIX: ghcr.io/nguyenthanhhungdev140503
  VPS_APP_DIR: /opt/onlook

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    outputs:
      image_tag: ${{ steps.image.outputs.tag }}

    steps:
      - name: Check out release commit
        uses: actions/checkout@v4

      - name: Set image tag
        id: image
        run: echo "tag=${GITHUB_SHA}" >> "$GITHUB_OUTPUT"

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and publish Onlook Web image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: Dockerfile
          platforms: linux/amd64
          push: true
          tags: |
            ${{ env.IMAGE_PREFIX }}/onlook-web:${{ steps.image.outputs.tag }}
            ${{ env.IMAGE_PREFIX }}/onlook-web:latest

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: production
    permissions:
      contents: read

    steps:
      - name: Check out deployment files
        uses: actions/checkout@v4

      - name: Configure SSH
        env:
          VPS_SSH_PRIVATE_KEY: ${{ secrets.VPS_SSH_PRIVATE_KEY }}
          VPS_KNOWN_HOSTS: ${{ secrets.VPS_KNOWN_HOSTS }}
        run: |
          install -m 700 -d ~/.ssh
          printf '%s\n' "$VPS_SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
          printf '%s\n' "$VPS_KNOWN_HOSTS" > ~/.ssh/known_hosts

      - name: Sync Compose and deployment files
        env:
          VPS_HOST: ${{ secrets.VPS_HOST }}
        run: |
          ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes "$VPS_HOST" \
            'install -d -m 0755 /opt/onlook'
          rsync -az --info=progress2 \
            --exclude='.env' --exclude='node_modules/' --exclude='.next/' \
            -e 'ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes' \
            docker-compose.yml .env.defaults \
            "$VPS_HOST:$VPS_APP_DIR/"

      - name: Pull and deploy the immutable image tag
        env:
          VPS_HOST: ${{ secrets.VPS_HOST }}
          IMAGE_TAG: ${{ needs.build-and-push.outputs.image_tag }}
        run: |
          ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes "$VPS_HOST" \
            "IMAGE_TAG='$IMAGE_TAG' IMAGE_PREFIX='$IMAGE_PREFIX' bash -s" <<'REMOTE'
          set -euo pipefail
          cd /opt/onlook

          previous_tag=""
          rollback_armed=false

          tag_local_latest() {
            local tag="$1"
            docker tag "$IMAGE_PREFIX/onlook-web:$tag" onlook-web:latest
          }

          wait_for_health() {
            for _ in $(seq 1 30); do
              if curl -fsS http://127.0.0.1:3000 >/dev/null 2>&1; then
                return 0
              fi
              sleep 2
            done
            return 1
          }

          rollback_on_error() {
            local failed_status="$1"
            trap - ERR
            set +e

            if [[ "$rollback_armed" != true ]]; then
              echo "Deployment failed before a previous image tag was available; skipping rollback." >&2
              exit "$failed_status"
            fi

            echo "Deployment failed; restoring previous immutable tag: $previous_tag" >&2
            sed -i '/^IMAGE_REGISTRY=/d; /^IMAGE_TAG=/d' .env
            printf 'IMAGE_REGISTRY=%s/\nIMAGE_TAG=%s\n' "$IMAGE_PREFIX" "$previous_tag" >> .env

            if docker compose config --quiet \
              && docker compose pull \
              && tag_local_latest "$previous_tag" \
              && docker compose up -d --no-build \
              && wait_for_health; then
              echo "Automatic rollback restored $previous_tag; deployment remains failed." >&2
            else
              echo "Automatic rollback also failed; inspect the VPS immediately." >&2
            fi
            exit "$failed_status"
          }

          trap 'rollback_on_error $?' ERR

          if [[ ! -f .env ]]; then
            cat > .env <<'ENV'
          NODE_ENV=production
          PORT=3000
          NEXT_TELEMETRY_DISABLED=1
          HOSTNAME=0.0.0.0
          ENV
            chmod 600 .env
          fi

          previous_tag="$(sed -n 's/^IMAGE_TAG=//p' .env | tail -1)"
          if [[ -n "$previous_tag" ]]; then
            printf '%s\n' "$previous_tag" > .last-deploy
            rollback_armed=true
          fi
          sed -i '/^IMAGE_REGISTRY=/d; /^IMAGE_TAG=/d' .env
          printf 'IMAGE_REGISTRY=%s/\nIMAGE_TAG=%s\n' "$IMAGE_PREFIX" "$IMAGE_TAG" >> .env

          docker compose config --quiet
          docker compose pull
          tag_local_latest "$IMAGE_TAG"
          docker compose up -d --no-build

          wait_for_health
          curl -fsS http://127.0.0.1:3000 >/dev/null
          trap - ERR
          REMOTE
```

---

## 5. Summary of Key Differences & Recommendations

1. **GHCR Permissions**:
   - Ensure the repository setting for GitHub Packages is granted or the `LABEL org.opencontainers.image.source` is included in the `Dockerfile`.
2. **Secrets Configuration on GitHub Repo**:
   - `VPS_HOST`: `root@160.250.4.40`
   - `VPS_SSH_PRIVATE_KEY`: Deployment private key matching authorized keys on `160.250.4.40`.
   - `VPS_KNOWN_HOSTS`: Pinned host key for `160.250.4.40`.
3. **VPS First-Time Setup**:
   - Ensure the directory `/opt/onlook` exists on the VPS with appropriate write permissions.
   - If the GHCR package is private, execute `echo "$PAT" | docker login ghcr.io -u <username> --password-stdin` on the VPS once.
