#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "ERROR: $*" >&2; exit 1; }
ok(){ echo "✅ $*"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

[[ "${DEVBOX_MOUNT_BASE:-$HOME/DevboxMount}" == "$HOME/"* ]] || fail "DEVBOX_MOUNT_BASE must live under \$HOME"

WS="${1:-}"
[[ -n "$WS" ]] || fail "usage: ws-mount <workspace>"

source "$ROOT/scripts/lib/ws-meta.sh"
ws_load_meta "$WS"

MOUNT_BASE="${DEVBOX_MOUNT_BASE:-$HOME/DevboxMount}"
MOUNT_POINT="$MOUNT_BASE/$WS"

if [[ ! -f "$WS_PRIVKEY" ]]; then
  echo "⚠️  $WS: missing private key: $WS_PRIVKEY (skipping mount)"
  exit 0
fi

mkdir -p "$MOUNT_POINT"

if mount | grep -q "on ${MOUNT_POINT} "; then
  ok "already mounted: $MOUNT_POINT"
  exit 0
fi

echo "[mount] mounting ws-$WS (/workspace) -> $MOUNT_POINT (key: $WS_PRIVKEY)"
sshfs -p "$SSH_PORT" ubuntu@127.0.0.1:/workspace "$MOUNT_POINT" \
  -o IdentityFile="$WS_PRIVKEY" \
  -o IdentitiesOnly=yes \
  -o reconnect \
  -o follow_symlinks \
  -o defer_permissions \
  -o volname="devbox-$WS"
