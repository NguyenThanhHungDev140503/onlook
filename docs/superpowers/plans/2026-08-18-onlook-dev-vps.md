# Onlook Dev VPS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run Onlook from `/opt/onlook` with `bun dev` on the VPS and expose it through the existing Cloudflare hostname.

**Architecture:** Add a separate dev Compose file with source and dependency volumes, then run the existing monorepo `dev` script inside a Bun container. Keep `/opt/onlook/.env` as the runtime environment and reset/seed the approved Supabase development database before starting the app.

**Tech Stack:** Docker Compose, Bun, Next.js Turbopack, Supabase, Cloudflare Tunnel.

## Global Constraints

- Keep `https://onlook.hungnguyen.online` routed to `localhost:3000`.
- Do not modify `docker-compose.yml` production image deployment.
- Do not modify CodeBadger, Redis, Postgres, or unrelated VPS services.
- `bun db:seed` resets the Supabase database before inserting seed data.

---

### Task 1: Add Dev Compose Runtime

**Files:**
- Create: `docker-compose.dev.yml`

- [ ] Add a Bun dev service using `/opt/onlook` as `/app`, host networking, `.env`, named `node_modules` and `.next` volumes, port `3000`, and command `bun install --frozen-lockfile && bun dev --hostname 0.0.0.0`.
- [ ] Validate locally with `docker compose -f docker-compose.dev.yml config --quiet`.

### Task 2: Switch VPS Runtime and Seed Database

**Files:**
- Remote: `/opt/onlook/.env`
- Remote: `/opt/onlook/docker-compose.dev.yml`

- [ ] Sync only `docker-compose.dev.yml` to `/opt/onlook`; preserve `.env`.
- [ ] Ensure `SUPABASE_URL` exists in remote `.env` using the existing Supabase project URL.
- [ ] Stop/remove only `onlook-web` from the production compose project.
- [ ] Run `docker compose -f docker-compose.dev.yml run --rm onlook-dev bun db:seed`.
- [ ] Start `docker compose -f docker-compose.dev.yml up -d`.

### Task 3: Verify Dev Deployment

- [ ] Confirm logs show Next.js dev server ready on port `3000`.
- [ ] Confirm `curl -fsSI http://127.0.0.1:3000` succeeds.
- [ ] Confirm `curl -fsSI https://onlook.hungnguyen.online` succeeds through Cloudflare Tunnel.
- [ ] Confirm only the Onlook container changed.
