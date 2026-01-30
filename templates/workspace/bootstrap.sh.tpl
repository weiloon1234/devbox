#!/usr/bin/env bash
set -euo pipefail

WS_NAME="__WS_NAME__"

log(){ echo "[ws $WS_NAME] $*"; }
fail(){ echo "ERROR: $*" >&2; exit 1; }

PUB_SRC="/seed/authorized_keys"

DEV_USER="ubuntu"
DEV_HOME="/home/$DEV_USER"
DEV_SSH="$DEV_HOME/.ssh"
DEV_AUTH="$DEV_SSH/authorized_keys"

log "bootstrap starting..."

# Seed key must exist (compose mounts it)
[[ -f "$PUB_SRC" ]] || fail "missing seed public key at $PUB_SRC"

# User must exist (image responsibility)
id "$DEV_USER" >/dev/null 2>&1 || fail "user '$DEV_USER' missing in image"

# Ensure SSH host keys exist
if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
  log "generating SSH host keys"
  ssh-keygen -A
fi

# Install authorized_keys (deterministic overwrite, not append)
install -d -m 700 -o "$DEV_USER" -g "$DEV_USER" "$DEV_SSH"
install -m 600 -o "$DEV_USER" -g "$DEV_USER" "$PUB_SRC" "$DEV_AUTH"

# Ensure sshd runtime dir
mkdir -p /run/sshd

log "starting sshd..."
exec /usr/sbin/sshd -D -e