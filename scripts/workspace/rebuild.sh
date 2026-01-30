#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GEN_ROOT="$ROOT/generated/workspaces"

source "$ROOT/scripts/lib/ws-meta.sh"

fail() { echo "ERROR: $*" >&2; exit 1; }

usage() {
  echo "Usage: devbox workspace rebuild [<name>] [--no-cache]"
  echo ""
  echo "Rebuild the workspace image and recreate container(s)."
  echo "Code volumes are preserved — no data loss."
  echo ""
  echo "  <name>       Rebuild a specific workspace (default: all)"
  echo "  --no-cache   Force full image rebuild without Docker cache"
}

NO_CACHE=""
WS_NAME=""

for arg in "$@"; do
  case "$arg" in
    --no-cache) NO_CACHE="--no-cache" ;;
    -h|--help)  usage; exit 0 ;;
    *)          WS_NAME="$arg" ;;
  esac
done

docker info >/dev/null 2>&1 || fail "Docker daemon not reachable. Start Docker Desktop."

# ── Rebuild PHP images ──
echo "[devbox] rebuilding php images..."
for v in 8.1 8.2 8.3 8.4 8.5; do
  docker build $NO_CACHE -t "devbox-php:${v}" -f "$ROOT/images/php/${v}/Dockerfile" "$ROOT/images/php"
done

# ── Rebuild workspace image ──
echo "[devbox] rebuilding workspace image..."
docker build $NO_CACHE -t devbox-workspace:latest "$ROOT/images/workspace"

# ── Recreate container(s) ──
if [[ -n "$WS_NAME" ]]; then
  # Single workspace
  COMPOSE="$GEN_ROOT/$WS_NAME/docker-compose.yml"
  [[ -f "$COMPOSE" ]] || fail "workspace '$WS_NAME' not found at $COMPOSE"
  echo "[devbox] recreating workspace: $WS_NAME"
  docker compose -f "$COMPOSE" up -d --force-recreate
else
  # All workspaces
  REBUILT=0
  if [[ -d "$GEN_ROOT" ]]; then
    shopt -s nullglob
    for compose in "$GEN_ROOT"/*/docker-compose.yml; do
      [[ -f "$compose" ]] || continue
      ws="$(basename "$(dirname "$compose")")"
      echo "[devbox] recreating workspace: $ws"
      docker compose -f "$compose" up -d --force-recreate
      REBUILT=$((REBUILT+1))
    done
    shopt -u nullglob
  fi
  echo "[devbox] rebuilt and recreated $REBUILT workspace(s)"
fi

echo "[devbox] done. Volumes preserved — no data lost."
