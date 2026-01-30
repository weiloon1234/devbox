#!/usr/bin/env bash
set -euo pipefail

WS_NAME="__WS_NAME__"

WORK="/workspace"
MARKER="$WORK/.seeded"

PUB_SRC="/seed/authorized_keys"

log() { echo "[ws $WS_NAME] $*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

log "bootstrap starting..."

# Detect uid 1000 user (ubuntu on 24.04)
DEV_UID=1000
DEV_USER="$(getent passwd 1000 | cut -d: -f1)"
[[ -n "$DEV_USER" ]] || fail "no uid 1000 user found"

HOME_DIR="$(getent passwd "$DEV_USER" | cut -d: -f6)"
SSH_DIR="$HOME_DIR/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

log "using user '$DEV_USER' ($HOME_DIR)"

# Ensure sudo
if [[ ! -f "/etc/sudoers.d/$DEV_USER" ]]; then
  echo "$DEV_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$DEV_USER"
  chmod 0440 "/etc/sudoers.d/$DEV_USER"
fi

# Ensure ssh host keys
if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
  log "generating ssh host keys"
  ssh-keygen -A
fi

# Fix workspace ownership once
if [[ "$(stat -c '%u' "$WORK")" != "$DEV_UID" ]]; then
  log "fixing ownership of $WORK"
  chown -R "$DEV_UID:$DEV_UID" "$WORK"
fi

# Seed user SSH (ONE TIME)
if [[ ! -f "$MARKER" ]]; then
  log "seeding fresh workspace volume..."

  [[ -f "$PUB_SRC" ]] || fail "missing seed pubkey at $PUB_SRC"

  sudo -u "$DEV_USER" mkdir -p "$SSH_DIR"
  sudo -u "$DEV_USER" chmod 700 "$SSH_DIR"

  sudo -u "$DEV_USER" touch "$AUTH_KEYS"
  sudo -u "$DEV_USER" chmod 600 "$AUTH_KEYS"

  PUB_LINE="$(cat "$PUB_SRC")"
  grep -qxF "$PUB_LINE" "$AUTH_KEYS" \
    || echo "$PUB_LINE" | sudo -u "$DEV_USER" tee -a "$AUTH_KEYS" >/dev/null

  sudo -u "$DEV_USER" touch "$MARKER"
  log "seed complete."
fi

# Harden sshd (DO NOT override AuthorizedKeysFile)
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config

mkdir -p /run/sshd
log "starting sshd..."
exec /usr/sbin/sshd -D -e