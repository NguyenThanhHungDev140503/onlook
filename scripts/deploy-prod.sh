#!/usr/bin/env bash
#
# Deploy a specific image tag of Onlook to the production VPS.
#
# Usage:
#   IMAGE_TAG=<sha> scripts/deploy-prod.sh [vps-host]
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VPS="${1:-root@160.250.4.40}"
VPS_APP_DIR="/opt/onlook"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/codebadger_vps}"

IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo "latest")}"
IMAGE_PREFIX="ghcr.io/nguyenthanhhungdev140503"

SSH_CMD="ssh -i $SSH_KEY -o IdentitiesOnly=yes"

echo "🚀 Deploying Onlook (IMAGE_TAG=$IMAGE_TAG) to $VPS ..."

# 1. Sync config & compose files (excluding .env)
echo "→ Syncing docker-compose.yml and .env.defaults to VPS..."
$SSH_CMD "$VPS" "mkdir -p $VPS_APP_DIR"
rsync -avz \
  --exclude='.env' \
  --exclude='node_modules/' \
  --exclude='.next/' \
  --exclude='.git/' \
  -e "$SSH_CMD" \
  docker-compose.yml \
  .env.defaults \
  "$VPS:$VPS_APP_DIR/"

# 2. Check / Create .env on VPS if missing
echo "→ Checking .env on VPS..."
$SSH_CMD "$VPS" "
if [ ! -f $VPS_APP_DIR/.env ]; then
  cat > $VPS_APP_DIR/.env <<'ENV'
NODE_ENV=production
PORT=3000
NEXT_TELEMETRY_DISABLED=1
HOSTNAME=0.0.0.0
IMAGE_REGISTRY=$IMAGE_PREFIX/
IMAGE_TAG=$IMAGE_TAG
NEXT_PUBLIC_SITE_URL=http://160.250.4.40:3000
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=placeholder_anon_key
SUPABASE_DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
SUPABASE_SERVICE_ROLE_KEY=placeholder_service_role_key
OPENROUTER_BASE_URL=http://127.0.0.1:20129/v1
OPENROUTER_API_KEY=placeholder_key
CSB_API_KEY=placeholder_csb_key
ENV
  chmod 600 $VPS_APP_DIR/.env
fi
"

# 3. Save rollback state
CURRENT_TAG=$($SSH_CMD "$VPS" "cd $VPS_APP_DIR && grep '^IMAGE_TAG=' .env | cut -d= -f2" 2>/dev/null || echo "latest")

# 4. Update IMAGE_TAG in .env
echo "→ Updating IMAGE_TAG to $IMAGE_TAG in VPS .env..."
$SSH_CMD "$VPS" "cd $VPS_APP_DIR && sed -i '/^IMAGE_REGISTRY=/d; /^IMAGE_TAG=/d' .env && printf 'IMAGE_REGISTRY=%s/\nIMAGE_TAG=%s\n' '$IMAGE_PREFIX' '$IMAGE_TAG' >> .env"

# 5. Pull and redeploy
echo "→ Pulling and starting container..."
$SSH_CMD "$VPS" "cd $VPS_APP_DIR && docker compose config --quiet && docker compose pull && docker tag $IMAGE_PREFIX/onlook-web:$IMAGE_TAG onlook-web:latest && docker compose up -d --no-build"

# 6. Health check
echo "→ Verifying health check..."
for i in $(seq 1 30); do
  if $SSH_CMD "$VPS" "curl -fsS http://127.0.0.1:3000 >/dev/null 2>&1"; then
    echo "   Health check passed (HTTP 200 OK)."
    $SSH_CMD "$VPS" "echo '$CURRENT_TAG' > $VPS_APP_DIR/.last-deploy"
    echo "✅ Deployed $IMAGE_TAG to $VPS successfully."
    exit 0
  fi
  sleep 2
done

echo "❌ Health check timed out." >&2
exit 1
