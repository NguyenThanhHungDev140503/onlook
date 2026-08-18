# Onlook Dev VPS

## Goal

Run Onlook from source in development mode on the VPS, replacing the current
standalone production image. Keep the existing public hostname:

`https://onlook.hungnguyen.online`

## Runtime

- Source directory: `/opt/onlook`
- Command: `bun dev`
- Port: `3000`
- Network mode: host, so the app can reach local VPS services when needed
- Environment: `/opt/onlook/.env`
- Restart policy: `unless-stopped`

The dev process runs through Docker Compose with the repository source mounted
into the container. Dependencies are installed in the container and retained
in a named volume. Source edits on the VPS are visible to Next.js Turbopack
through the bind mount.

## Database

Use Supabase project `kshwfxpqpsazfxghjfkw` as the development database.

Run:

```bash
bun db:seed
```

The seed script first calls `resetDb()`, so existing tables and data in this
Supabase project are intentionally replaced with the seed state. This is
approved because the project is not production.

## Deployment Changes

- Replace the VPS image-based compose service with a dev compose service.
- Do not modify Cloudflare Tunnel routing; `onlook.hungnguyen.online` already
  points to `localhost:3000`.
- Do not alter persistent CodeBadger, Postgres, Redis, or other unrelated VPS
  services.
- Do not run the production GitHub Actions deployment after switching to dev,
  because it would replace the dev container with the standalone image again.

## Verification

- `docker compose config --quiet` succeeds.
- Dev container remains running after startup.
- Logs show Next.js ready on port `3000`.
- `curl -fsSI https://onlook.hungnguyen.online` returns HTTP success.
- Browser page loads without the previous Zaraz or environment validation
  errors.
- Seed completes successfully and Supabase contains the sample state.
