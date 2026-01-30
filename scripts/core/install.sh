#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail(){ echo "ERROR: $*" >&2; exit 1; }

# ----------------------------
# Args
# ----------------------------
DRY_RUN=0
for arg in "${@:-}"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    --help|-h)
      echo "usage: ./scripts/devbox.sh install [--dry-run|-n]"
      exit 0
      ;;
  esac
done

# ----------------------------
# Helpers
# ----------------------------
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $*"
    return 0
  fi
  eval "$@"
}

run_sudo() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] sudo $*"
    return 0
  fi
  sudo bash -lc "$*"
}

# Pick shell rc file
SHELL_NAME="$(basename "${SHELL:-}")"
if [[ "$SHELL_NAME" == "zsh" ]]; then
  RC_FILE="$HOME/.zshrc"
elif [[ "$SHELL_NAME" == "bash" ]]; then
  RC_FILE="$HOME/.bashrc"
else
  RC_FILE="$HOME/.zshrc"
fi

BIN_DIR="$HOME/bin"
run "mkdir -p \"$BIN_DIR\""

append_rc_once() {
  local line="$1"
  local comment="${2:-}"

  if [[ -f "$RC_FILE" ]] && grep -qxF "$line" "$RC_FILE"; then
    echo "[install] already in $RC_FILE: $line"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] append to $RC_FILE: ${comment:-# devbox}"
    echo "[dry-run] append to $RC_FILE: $line"
    return 0
  fi

  echo "" >> "$RC_FILE"
  [[ -n "$comment" ]] && echo "$comment" >> "$RC_FILE"
  echo "$line" >> "$RC_FILE"
}

ensure_path() {
  append_rc_once 'export PATH="$HOME/bin:$PATH"' "# devbox helpers"
}

ensure_mount_base() {
  append_rc_once 'export DEVBOX_MOUNT_BASE="$HOME/DevboxMount"' "# devbox mount base"
}

# ----------------------------
# Homebrew + pkg helpers
# ----------------------------
ensure_homebrew() {
  if has_cmd brew; then
    echo "[install] Homebrew OK"
    return 0
  fi
  echo "[install] Homebrew not found."
  echo "Install it from: https://brew.sh"
  echo "Then re-run: ./scripts/devbox.sh install"
  exit 1
}

ensure_brew_pkg() {
  local pkg="$1"
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    echo "[install] brew formula OK: $pkg"
  else
    echo "[install] Installing: $pkg"
    run "brew install $pkg"
  fi
}

ensure_brew_cask() {
  local cask="$1"
  if brew list --cask "$cask" >/dev/null 2>&1; then
    echo "[install] brew cask OK: $cask"
  else
    echo "[install] Installing cask: $cask"
    run "brew install --cask $cask"
  fi
}

# ----------------------------
# Docker Desktop
# ----------------------------
ensure_docker_desktop() {
  # 1) App exists
  if [[ -d "/Applications/Docker.app" ]]; then
    echo "[install] Docker Desktop app already installed"

    # 2) CLI exists?
    if has_cmd docker; then
      # 3) Daemon running?
      if docker info >/dev/null 2>&1; then
        echo "[install] Docker daemon is running"
        return 0
      else
        echo "[install] Docker Desktop installed but not running"
        echo "→ Please open Docker.app and wait until it says 'Docker is running'"
        return 0
      fi
    else
      echo "[install] Docker Desktop present but docker CLI not in PATH"
      echo "→ Open Docker.app once to finish setup"
      return 0
    fi
  fi

  # Not installed at all
  echo "[install] Docker Desktop not found; installing via Homebrew cask..."
  ensure_brew_cask docker

  echo "[install] Docker Desktop installed."
  echo "IMPORTANT:"
  echo "→ Open Docker.app manually once"
  echo "→ Complete initial setup"
  echo "→ Re-run: devbox bootstrap"
}

# ----------------------------
# mkcert + local TLS
# ----------------------------
ensure_mkcert() {
  ensure_brew_pkg mkcert
  ensure_brew_pkg nss || true
}

ensure_local_tls() {
  local cert_dir="$ROOT/proxy/certs"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] mkdir -p \"$cert_dir\""
  else
    mkdir -p "$cert_dir"
  fi

  if ! has_cmd mkcert; then
    echo "[install] mkcert not available; skipping TLS cert generation"
    return 0
  fi

  echo "[install] ensuring mkcert local CA is installed..."
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] mkcert -install"
  else
    mkcert -install >/dev/null 2>&1 || true
  fi

  local crt="$cert_dir/local.test.crt"
  local key="$cert_dir/local.test.key"

  if [[ -f "$crt" && -f "$key" ]]; then
    echo "[install] TLS cert already exists: proxy/certs/local.test.(crt|key)"
    return 0
  fi

  echo "[install] generating wildcard TLS cert for *.test + *.*.test ..."
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] mkcert -cert-file \"$crt\" -key-file \"$key\" \"*.test\" \"*.*.test\" \"localhost\" \"127.0.0.1\""
  else
    mkcert \
      -cert-file "$crt" \
      -key-file "$key" \
      "*.test" "*.*.test" \
      "localhost" \
      "127.0.0.1" >/dev/null
  fi

  echo "[install] generated: proxy/certs/local.test.(crt|key)"
}

# ----------------------------
# SSHFS (macFUSE + sshfs)
# ----------------------------
ensure_sshfs() {
  ensure_brew_cask macfuse

  # sshfs on macOS: use sshfs-mac tap (brew sshfs is linux-only)
  if command -v sshfs >/dev/null 2>&1; then
    echo "[install] sshfs already installed"
  else
    echo "[install] Installing sshfs-mac..."
    run "brew tap gromgit/fuse"
    run "brew install gromgit/fuse/sshfs-mac"
  fi

  echo "[install] macFUSE + sshfs installed."
  echo "[install] If sshfs fails later, reboot macOS once (macFUSE sometimes needs it)."
}

# ----------------------------
# dnsmasq (prompt + auto intel/as)
# ----------------------------
ensure_dnsmasq() {
  if ! has_cmd brew; then
    echo "[install] Homebrew missing; cannot install dnsmasq"
    return 1
  fi

  if brew list --formula dnsmasq >/dev/null 2>&1; then
    echo "[install] dnsmasq already installed"
  else
    echo "[install] Installing dnsmasq..."
    run "brew install dnsmasq"
  fi

  local brew_prefix
  brew_prefix="$(brew --prefix)"
  local conf_dir="${brew_prefix}/etc/dnsmasq.d"
  local conf_file="${conf_dir}/devbox-test.conf"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] mkdir -p \"$conf_dir\""
  else
    mkdir -p "$conf_dir"
  fi

  if [[ -f "$conf_file" ]]; then
    echo "[install] dnsmasq *.test rule already exists: $conf_file"
  else
    echo "[install] Creating dnsmasq rule: *.test → 127.0.0.1"
    # use sudo to avoid permissions issues across setups
    run_sudo "mkdir -p '$conf_dir' && printf '%s\n' 'address=/test/127.0.0.1' > '$conf_file'"
  fi

  # Start service (may require sudo depending on brew setup)
  if brew services list | grep -q '^dnsmasq.*started'; then
    echo "[install] dnsmasq already running"
  else
    echo "[install] Starting dnsmasq (sudo required)"
    run_sudo "brew services start dnsmasq"
  fi

  echo "[install] Wildcard DNS enabled (*.test → 127.0.0.1)"
}

prompt_dnsmasq() {
  echo
  echo "[install] Wildcard DNS setup"
  echo "This enables: *.test → 127.0.0.1 (recommended for devbox)"
  echo "Requires sudo (may prompt once)."
  read -r -p "Enable wildcard DNS via dnsmasq? (y/N): " ANSWER
  ANSWER="$(echo "$ANSWER" | tr '[:upper:]' '[:lower:]')"

  if [[ "$ANSWER" != "y" ]]; then
    echo "[install] Skipping dnsmasq setup"
    return 0
  fi

  ensure_dnsmasq
}

# ----------------------------
# Wrapper installation
# ----------------------------
install_cmd() {
  local name="$1"
  local target="$2"
  [[ -f "$ROOT/$target" ]] || fail "missing $target"

  local out="$BIN_DIR/$name"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] write wrapper: $out -> $ROOT/$target"
    return 0
  fi

  cat > "$out" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$ROOT/$target" "\$@"
EOF
  chmod +x "$out"
  echo "[install] Installed $name -> $target"
}

# ----------------------------
# Main flow
# ----------------------------
echo "=== devbox install ==="
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[install] DRY-RUN enabled (no changes will be made)"
fi

ensure_path
ensure_mount_base
ensure_homebrew

prompt_dnsmasq

ensure_mkcert
ensure_local_tls
ensure_sshfs
ensure_docker_desktop

# Single CLI wrapper
install_cmd devbox scripts/devbox.sh

# Remove legacy devbox-* wrappers from ~/bin/
LEGACY_CMDS=(
  devbox-bootstrap devbox-reset devbox-ws-new devbox-ws-list
  devbox-ws-ssh devbox-ws-php devbox-ws-delete devbox-add-project
  devbox-db-mysql devbox-db-psql devbox-db-redis devbox-tls-status
  devbox-up devbox-down devbox-mount devbox-umount
  devbox-mount-all devbox-umount-all devbox-doctor devbox-refresh
  devbox-fresh
)
for old in "${LEGACY_CMDS[@]}"; do
  if [[ -f "$BIN_DIR/$old" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] remove legacy wrapper: $BIN_DIR/$old"
    else
      rm -f "$BIN_DIR/$old"
      echo "[install] Removed legacy wrapper: $old"
    fi
  fi
done

echo
echo "[install] Done."
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[install] (dry-run) Nothing changed."
else
  echo "Restart your terminal or run:"
  echo "  source \"$RC_FILE\""
fi
echo
echo "Next:"
echo "  devbox bootstrap"
echo "  devbox workspace new"
echo "  devbox workspace mount <workspace>"