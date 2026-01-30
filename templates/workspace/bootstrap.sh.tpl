#!/usr/bin/env bash
set -euo pipefail

WS_NAME="__WS_NAME__"

log(){ echo "[ws $WS_NAME] $*"; }
fail(){ echo "ERROR: $*" >&2; exit 1; }

PUB_SRC="/seed/authorized_keys"
KEY_SRC="/seed/id_key"

DEV_USER="ubuntu"
DEV_HOME="/home/$DEV_USER"
DEV_SSH="$DEV_HOME/.ssh"
DEV_AUTH="$DEV_SSH/authorized_keys"
DEV_KEY="$DEV_SSH/id_ed25519"
DEV_SSH_CFG="$DEV_SSH/config"

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

# Install private key for Git operations (GitHub + GitLab)
if [[ -f "$KEY_SRC" ]]; then
  install -m 600 -o "$DEV_USER" -g "$DEV_USER" "$KEY_SRC" "$DEV_KEY"
  log "installed private key for git"

  cat > "$DEV_SSH_CFG" <<'SSHCFG'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new

Host gitlab.com
  HostName gitlab.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
SSHCFG
  chown "$DEV_USER:$DEV_USER" "$DEV_SSH_CFG"
  chmod 600 "$DEV_SSH_CFG"
  log "installed ssh config (github.com + gitlab.com)"
else
  log "WARNING: no private key at $KEY_SRC — git push/pull over SSH will not work"
fi

# ── AI tool config seeding (optional, from /seed/ai/) ──
seed_file() {
  local src="$1" dest="$2"
  if [[ -f "$src" ]]; then
    local dest_dir; dest_dir="$(dirname "$dest")"
    install -d -m 700 -o "$DEV_USER" -g "$DEV_USER" "$dest_dir"
    install -m 600 -o "$DEV_USER" -g "$DEV_USER" "$src" "$dest"
    log "seeded $(basename "$dest")"
  fi
}

seed_dir() {
  local src="$1" dest="$2"
  if [[ -d "$src" ]] && [[ -n "$(ls -A "$src" 2>/dev/null)" ]]; then
    local parent; parent="$(dirname "$dest")"
    install -d -m 700 -o "$DEV_USER" -g "$DEV_USER" "$parent"
    cp -a "$src" "$dest"
    chown -R "$DEV_USER:$DEV_USER" "$dest"
    log "seeded $(basename "$dest")/"
  fi
}

# Claude Code (credentials file + env var + skip onboarding)
seed_file /seed/ai/claude/auth.json     "$DEV_HOME/.claude/.credentials.json"
if [[ -f /seed/ai/claude/auth.json ]]; then
  # Extract OAuth token for env var (interactive TUI needs this)
  CLAUDE_TOKEN="$(python3 -c "import json; d=json.load(open('/seed/ai/claude/auth.json')); print(d.get('claudeAiOauth',{}).get('accessToken',''))" 2>/dev/null || true)"
  if [[ -n "$CLAUDE_TOKEN" ]]; then
    grep -q 'CLAUDE_CODE_OAUTH_TOKEN' "$DEV_HOME/.bashrc" 2>/dev/null || \
      echo "export CLAUDE_CODE_OAUTH_TOKEN=\"$CLAUDE_TOKEN\"" >> "$DEV_HOME/.bashrc"
    chown "$DEV_USER:$DEV_USER" "$DEV_HOME/.bashrc"
    log "set CLAUDE_CODE_OAUTH_TOKEN in .bashrc"
  fi
  # Mark onboarding complete (without this, TUI always shows login screen)
  echo '{"hasCompletedOnboarding":true,"autoUpdates":false}' > "$DEV_HOME/.claude.json"
  chown "$DEV_USER:$DEV_USER" "$DEV_HOME/.claude.json"
  log "set hasCompletedOnboarding in .claude.json"
fi
seed_file /seed/ai/claude/settings.json "$DEV_HOME/.claude/settings.json"
seed_dir  /seed/ai/claude/agents        "$DEV_HOME/.claude/agents"
seed_dir  /seed/ai/claude/skills        "$DEV_HOME/.claude/skills"
seed_dir  /seed/ai/claude/plugins       "$DEV_HOME/.claude/plugins"

# Codex
seed_file /seed/ai/codex/auth.json    "$DEV_HOME/.codex/auth.json"
seed_file /seed/ai/codex/config.toml  "$DEV_HOME/.codex/config.toml"
seed_dir  /seed/ai/codex/rules        "$DEV_HOME/.codex/rules"
seed_dir  /seed/ai/codex/skills       "$DEV_HOME/.codex/skills"

# Gemini CLI
seed_file /seed/ai/gemini/oauth_creds.json    "$DEV_HOME/.gemini/oauth_creds.json"
seed_file /seed/ai/gemini/settings.json       "$DEV_HOME/.gemini/settings.json"
seed_file /seed/ai/gemini/google_accounts.json "$DEV_HOME/.gemini/google_accounts.json"
seed_file /seed/ai/gemini/google_account_id   "$DEV_HOME/.gemini/google_account_id"
seed_file /seed/ai/gemini/GEMINI.md           "$DEV_HOME/.gemini/GEMINI.md"

# OpenCode (auth in ~/.local/share/opencode/, config in ~/.config/opencode/)
seed_file /seed/ai/opencode/auth.json "$DEV_HOME/.local/share/opencode/auth.json"
seed_dir  /seed/ai/opencode/config    "$DEV_HOME/.config/opencode"

# GitHub Copilot (auth in ~/.config/github-copilot/)
seed_file /seed/ai/github-copilot/apps.json    "$DEV_HOME/.config/github-copilot/apps.json"
seed_file /seed/ai/github-copilot/versions.json "$DEV_HOME/.config/github-copilot/versions.json"

# ── Git defaults ──
su "$DEV_USER" -c 'git config --global init.defaultBranch main'
su "$DEV_USER" -c 'git config --global user.name "__GIT_NAME__"'
su "$DEV_USER" -c 'git config --global user.email "__GIT_EMAIL__"'

# ── Workspace directory setup ──
mkdir -p /workspace/projects
chown "$DEV_USER:$DEV_USER" /workspace /workspace/projects

# Symlink ~/projects → /workspace/projects (convenience for SSH sessions)
ln -sfn /workspace/projects "$DEV_HOME/projects"
chown -h "$DEV_USER:$DEV_USER" "$DEV_HOME/projects"

# Persist IDE caches on the workspace volume
# (avoids re-downloading ~1GB IDE backend on every container restart)
# JetBrains Gateway stores backend at ~/.cache/JetBrains/ (~910MB)
# VS Code Remote stores server at ~/.vscode-server/
IDE_CACHE="/workspace/.ide-cache"
mkdir -p "$IDE_CACHE/cache-jetbrains" "$IDE_CACHE/config-jetbrains" "$IDE_CACHE/share-jetbrains" "$IDE_CACHE/vscode-server"
mkdir -p "$DEV_HOME/.cache" "$DEV_HOME/.config" "$DEV_HOME/.local/share"
# Remove real dirs before symlinking (ln -sfn won't replace a directory)
# .local/share/JetBrains = plugins (e.g. GitHub Copilot)
for pair in ".cache/JetBrains:cache-jetbrains" ".config/JetBrains:config-jetbrains" ".local/share/JetBrains:share-jetbrains" ".vscode-server:vscode-server"; do
  rel="${pair%%:*}" name="${pair##*:}"
  target="$DEV_HOME/$rel"
  # If it's a real directory (not already a symlink), migrate contents then remove
  if [ -d "$target" ] && [ ! -L "$target" ]; then
    cp -a "$target/." "$IDE_CACHE/$name/" 2>/dev/null || true
    rm -rf "$target"
  fi
  ln -sfn "$IDE_CACHE/$name" "$target"
  chown -h "$DEV_USER:$DEV_USER" "$target"
done
chown -R "$DEV_USER:$DEV_USER" "$IDE_CACHE"

# ── Dev Container config (workspace-level default) ──
DEVCONTAINER_DIR="/workspace/.devcontainer"
DEVCONTAINER_JSON="$DEVCONTAINER_DIR/devcontainer.json"
if [[ ! -f "$DEVCONTAINER_JSON" ]]; then
  mkdir -p "$DEVCONTAINER_DIR"
  cat > "$DEVCONTAINER_JSON" <<DCEOF
{
  "name": "devbox-$WS_NAME",
  "remoteUser": "$DEV_USER",
  "workspaceFolder": "/workspace",
  "customizations": {
    "vscode": {
      "extensions": [
        "bmewburn.vscode-intelephense-client",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "eamodio.gitlens"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash"
      }
    }
  }
}
DCEOF
  chown -R "$DEV_USER:$DEV_USER" "$DEVCONTAINER_DIR"
  log "created workspace devcontainer.json"
fi

# Ensure sshd runtime dir
mkdir -p /run/sshd

log "starting sshd..."
exec /usr/sbin/sshd -D -e