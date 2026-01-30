#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GEN="$ROOT/generated/workspaces"
MOUNT_BASE="${DEVBOX_MOUNT_BASE:-$HOME/DevboxMount}"

fail() { echo "ERROR: $*" >&2; exit 1; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

WS="${1:-}"
[[ -n "$WS" ]] || fail "usage: ws-delete <workspace>"

WS_DIR="$GEN/$WS"
COMPOSE="$WS_DIR/docker-compose.yml"
MOUNT_POINT="$MOUNT_BASE/$WS"

echo "=== devbox ws-delete ==="
echo "Workspace: $WS"
echo

# 1) Stop containers + remove volumes
if [[ -f "$COMPOSE" ]]; then
  ok "Stopping containers + volumes..."
  docker compose -f "$COMPOSE" down -v || warn "docker compose down failed"
else
  warn "No docker-compose.yml found (already removed?)"
fi

# 2) Remove generated workspace files
if [[ -d "$WS_DIR" ]]; then
  ok "Removing generated workspace files..."
  rm -rf "$WS_DIR"
else
  warn "Generated workspace directory not found"
fi

# 3) Unmount if mounted
if [[ -d "$MOUNT_POINT" ]] && mount | grep -q "on ${MOUNT_POINT} "; then
  ok "Unmounting workspace mount..."
  umount "$MOUNT_POINT" || warn "Failed to unmount (try manually)"
fi

# 4) Remove mount directory
if [[ -d "$MOUNT_POINT" ]]; then
  ok "Removing mount directory..."
  rm -rf "$MOUNT_POINT"
fi

echo
ok "Workspace '$WS' deleted."
echo "You can recreate it with:"
echo "  devbox workspace new"