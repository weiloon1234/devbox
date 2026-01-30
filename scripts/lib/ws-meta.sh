#!/usr/bin/env bash
# ws-meta.sh — shared helper for loading workspace metadata
#
# Usage:
#   source "$ROOT/scripts/lib/ws-meta.sh"
#   ws_load_meta "personal"
#
# Exports: WS_NAME, SSH_PORT, PUBKEY_FILE, WS_PRIVKEY, GIT_NAME, GIT_EMAIL

ws_load_meta() {
  local name="$1"
  local env_file="$ROOT/generated/workspaces/$name/ws.env"
  local compose="$ROOT/generated/workspaces/$name/docker-compose.yml"

  if [[ -f "$env_file" ]]; then
    # shellcheck source=/dev/null
    source "$env_file"
  elif [[ -f "$compose" ]]; then
    echo "WARNING: ws.env missing for '$name'; falling back to compose parsing" >&2

    WS_NAME="$name"

    SSH_PORT="$(grep -E '^\s*-\s*"127\.0\.0\.1:[0-9]+:22"' "$compose" \
      | head -n1 \
      | sed -E 's/.*127\.0\.0\.1:([0-9]+):22.*/\1/')"
    [[ -n "$SSH_PORT" ]] || { echo "ERROR: cannot detect ssh port in $compose" >&2; return 1; }

    PUBKEY_FILE="$(grep -E 'keys/[^:]+\.pub:/seed/authorized_keys:ro' "$compose" \
      | head -n1 \
      | sed -E 's/.*keys\/([^:]+\.pub):\/seed\/authorized_keys:ro.*/\1/')"
    [[ -n "$PUBKEY_FILE" ]] || { echo "ERROR: cannot detect pubkey in $compose" >&2; return 1; }

    GIT_NAME="${GIT_NAME:-$name}"
    GIT_EMAIL="${GIT_EMAIL:-${name}@localhost}"
  else
    echo "ERROR: no ws.env or docker-compose.yml for workspace '$name'" >&2
    return 1
  fi

  # Derive private key path from pubkey filename
  WS_PRIVKEY="$HOME/.ssh/${PUBKEY_FILE%.pub}"

  export WS_NAME SSH_PORT PUBKEY_FILE WS_PRIVKEY GIT_NAME GIT_EMAIL
}
