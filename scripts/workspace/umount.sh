#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "ERROR: $*" >&2; exit 1; }

WS="${1:-}"
[[ -n "$WS" ]] || fail "usage: devbox workspace umount <workspace>"

MOUNT_BASE="${DEVBOX_MOUNT_BASE:-$HOME/DevboxMount}"
MOUNT_POINT="$MOUNT_BASE/$WS"

if mount | grep -q "on ${MOUNT_POINT} "; then
  echo "[umount] unmounting: $MOUNT_POINT"
  umount "$MOUNT_POINT" 2>/dev/null || diskutil unmount "$MOUNT_POINT"
else
  echo "[umount] not mounted: $MOUNT_POINT"
fi