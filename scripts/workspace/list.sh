#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GEN_ROOT="$ROOT/generated/workspaces"

source "$ROOT/scripts/lib/ws-meta.sh"

# ---------- helpers ----------
container_status() {
  local name="$1"
  local state
  state="$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || true)"
  if [[ "$state" == "running" ]]; then
    echo "up"
  elif [[ -n "$state" ]]; then
    echo "$state"
  else
    echo "down"
  fi
}

# ---------- infrastructure ----------
echo "=== Infrastructure ==="
echo ""
printf "  %-22s %-12s %-8s %s\n" "CONTAINER" "IMAGE" "STATUS" "PORT"
printf "  %-22s %-12s %-8s %s\n" "─────────" "─────" "──────" "────"

printf "  %-22s %-12s %-8s %s\n" "devbox-traefik" "traefik:v3.1" "$(container_status devbox-traefik)" "80, 443"
printf "  %-22s %-12s %-8s %s\n" "devbox-mysql" "mysql:8.4" "$(container_status devbox-mysql)" "3306"
printf "  %-22s %-12s %-8s %s\n" "devbox-postgres" "postgres:16" "$(container_status devbox-postgres)" "5432"
printf "  %-22s %-12s %-8s %s\n" "devbox-redis" "redis:7" "$(container_status devbox-redis)" "6379"

echo ""

# ---------- workspaces ----------
echo "=== Workspaces ==="
echo ""

if [[ ! -d "$GEN_ROOT" ]]; then
  echo "  (no workspaces configured)"
  exit 0
fi

shopt -s nullglob
FOUND=0

for wsdir in "$GEN_ROOT"/*/; do
  [[ -d "$wsdir" ]] || continue
  ws="$(basename "$wsdir")"

  if ws_load_meta "$ws" 2>/dev/null; then
    port="$SSH_PORT"
    key="$PUBKEY_FILE"
    git_info="$GIT_NAME <$GIT_EMAIL>"
  else
    port="?"
    key="?"
    git_info="?"
  fi

  ws_status="$(container_status "ws-$ws")"

  echo "  [$ws]  ssh: 127.0.0.1:$port  status: $ws_status  git: $git_info"
  echo ""

  printf "    %-28s %-8s\n" "CONTAINER" "STATUS"
  printf "    %-28s %-8s\n" "─────────" "──────"
  printf "    %-28s %-8s\n" "ws-$ws" "$ws_status"
  printf "    %-28s %-8s\n" "ws-$ws-nginx" "$(container_status "ws-$ws-nginx")"
  printf "    %-28s %-8s\n" "ws-$ws-php81" "$(container_status "ws-$ws-php81")"
  printf "    %-28s %-8s\n" "ws-$ws-php82" "$(container_status "ws-$ws-php82")"
  printf "    %-28s %-8s\n" "ws-$ws-php83" "$(container_status "ws-$ws-php83")"
  printf "    %-28s %-8s\n" "ws-$ws-php84" "$(container_status "ws-$ws-php84")"
  printf "    %-28s %-8s\n" "ws-$ws-php85" "$(container_status "ws-$ws-php85")"
  echo ""

  FOUND=$((FOUND+1))
done
shopt -u nullglob

if [[ $FOUND -eq 0 ]]; then
  echo "  (no workspaces found)"
fi
