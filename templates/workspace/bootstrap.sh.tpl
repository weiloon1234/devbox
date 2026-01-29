#!/usr/bin/env bash
set -euo pipefail

WORK="/workspace"
MARKER="$WORK/.seeded"

PUB_SRC="/seed/authorized_keys"
SSH_DIR="$WORK/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"
SSH_CONFIG="$SSH_DIR/config"
GITCONFIG="$WORK/.gitconfig"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

# If already seeded, just continue
if [[ -f "$MARKER" ]]; then
  exec "$@"
fi

echo "[ws __WS_NAME__] seeding fresh workspace volume..."

# Safety: public key must be mounted
[[ -f "$PUB_SRC" ]] || fail "missing seed public key at $PUB_SRC (check devbox/keys/__PUBKEY_FILE__)"

# Prepare .ssh
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

# Append pubkey if not already present (idempotent)
PUB_LINE="$(cat "$PUB_SRC")"
if ! grep -qxF "$PUB_LINE" "$AUTH_KEYS" 2>/dev/null; then
  echo "$PUB_LINE" >> "$AUTH_KEYS"
fi

# Minimal SSH config
if [[ ! -f "$SSH_CONFIG" ]]; then
  cat > "$SSH_CONFIG" <<'EOF'
Host *
  ServerAliveInterval 60
  StrictHostKeyChecking accept-new
EOF
  chmod 600 "$SSH_CONFIG"
fi

# Minimal git config (seeded per workspace)
if [[ ! -f "$GITCONFIG" ]]; then
  cat > "$GITCONFIG" <<EOF
[user]
  name = __GIT_NAME__
  email = __GIT_EMAIL__
[core]
  autocrlf = input
EOF
fi

touch "$MARKER"
echo "[ws __WS_NAME__] seed complete."

exec "$@"