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

# Ensure seed pubkey exists
[[ -f "$PUB_SRC" ]] || fail "missing seed public key at $PUB_SRC"

# Ensure user exists
id "$DEV_USER" >/dev/null 2>&1 || fail "user '$DEV_USER' missing in image"

# Ensure SSH host keys exist
if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
  log "generating SSH host keys"
  ssh-keygen -A
fi

# Ensure account not locked (belt + suspenders)
# If /etc/shadow has '!' prefixed hash, ssh may refuse the user even for pubkey.
if grep -q "^${DEV_USER}:!" /etc/shadow; then
  log "unlocking user (setting dummy password; password auth stays disabled)"
  echo "${DEV_USER}:devbox" | chpasswd
fi

# Seed authorized_keys into HOME (NOT /workspace)
mkdir -p "$DEV_SSH"
chmod 700 "$DEV_SSH"
touch "$DEV_AUTH"
chmod 600 "$DEV_AUTH"

PUB_LINE="$(cat "$PUB_SRC")"
if ! grep -qxF "$PUB_LINE" "$DEV_AUTH" 2>/dev/null; then
  echo "$PUB_LINE" >> "$DEV_AUTH"
fi

chown -R "$DEV_USER:$DEV_USER" "$DEV_SSH"

# sshd config: key-only, correct authorized_keys path
SSHD_CONFIG="/etc/ssh/sshd_config"

# Ensure AuthorizedKeysFile points to HOME
if grep -q '^AuthorizedKeysFile' "$SSHD_CONFIG"; then
  sed -i "s|^AuthorizedKeysFile.*|AuthorizedKeysFile ${DEV_SSH}/authorized_keys|" "$SSHD_CONFIG"
else
  echo "AuthorizedKeysFile ${DEV_SSH}/authorized_keys" >> "$SSHD_CONFIG"
fi

sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' "$SSHD_CONFIG" || true
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' "$SSHD_CONFIG" || true
sed -i 's/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG" || true
sed -i 's/^#\?UsePAM .*/UsePAM no/' "$SSHD_CONFIG" || true

# Ensure sshd runtime dir
mkdir -p /run/sshd

log "starting sshd..."
exec /usr/sbin/sshd -D -e