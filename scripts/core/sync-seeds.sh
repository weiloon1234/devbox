#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SEEDS="$ROOT/seeds"

mkdir -p "$SEEDS"

ok(){ echo "  ✅ $*"; }
skip(){ echo "  ⏭  $*"; }

sync_file() {
  local src="$1" dest="$2" label="$3"
  if [[ -f "$src" ]]; then
    cp "$src" "$dest"
    chmod 600 "$dest"
    ok "$label"
  else
    skip "$label (not found)"
  fi
}

sync_dir() {
  local src="$1" dest="$2" label="$3"
  if [[ -d "$src" ]] && [[ -n "$(ls -A "$src" 2>/dev/null)" ]]; then
    rm -rf "$dest"
    cp -a "$src" "$dest"
    ok "$label"
  else
    skip "$label (not found or empty)"
  fi
}

echo "=== devbox sync-seeds ==="
echo "Syncing AI tool config from host → seeds/"
echo

# ── Claude Code (native binary) ──────────────────────────
echo "Claude Code:"
mkdir -p "$SEEDS/claude"

# Auth: native binary uses ~/.config/claude-code/auth.json on Linux
# On macOS, stored in Keychain under "Claude Code-credentials"
if [[ -f "$HOME/.config/claude-code/auth.json" ]]; then
  cp "$HOME/.config/claude-code/auth.json" "$SEEDS/claude/auth.json"
  chmod 600 "$SEEDS/claude/auth.json"
  ok "auth (from ~/.config/claude-code/auth.json)"
elif [[ "$(uname)" == "Darwin" ]]; then
  CLAUDE_CREDS="$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)"
  if [[ -n "$CLAUDE_CREDS" ]]; then
    echo "$CLAUDE_CREDS" > "$SEEDS/claude/auth.json"
    chmod 600 "$SEEDS/claude/auth.json"
    ok "auth (from macOS Keychain)"
  else
    skip "auth (not found in Keychain)"
  fi
else
  skip "auth (no credentials found)"
fi

# Settings, agents, plugins config, skills (from ~/.claude/)
sync_file "$HOME/.claude/settings.json" "$SEEDS/claude/settings.json" "settings"
sync_dir  "$HOME/.claude/agents"        "$SEEDS/claude/agents"        "agents"
sync_dir  "$HOME/.claude/skills"        "$SEEDS/claude/skills"        "skills"

# Plugins: copy config files only (not the cache)
mkdir -p "$SEEDS/claude/plugins"
for pf in config.json installed_plugins.json known_marketplaces.json; do
  sync_file "$HOME/.claude/plugins/$pf" "$SEEDS/claude/plugins/$pf" "plugins/$pf"
done

echo

# ── Codex ────────────────────────────────────────────────
echo "Codex:"
mkdir -p "$SEEDS/codex"
sync_file "$HOME/.codex/auth.json"    "$SEEDS/codex/auth.json"    "auth"
sync_file "$HOME/.codex/config.toml"  "$SEEDS/codex/config.toml"  "config"
sync_dir  "$HOME/.codex/rules"        "$SEEDS/codex/rules"        "rules"
sync_dir  "$HOME/.codex/skills"       "$SEEDS/codex/skills"       "skills"
echo

# ── Gemini CLI ───────────────────────────────────────────
echo "Gemini CLI:"
mkdir -p "$SEEDS/gemini"
sync_file "$HOME/.gemini/oauth_creds.json"    "$SEEDS/gemini/oauth_creds.json"    "auth"
sync_file "$HOME/.gemini/settings.json"       "$SEEDS/gemini/settings.json"       "settings"
sync_file "$HOME/.gemini/google_accounts.json" "$SEEDS/gemini/google_accounts.json" "google_accounts"
sync_file "$HOME/.gemini/google_account_id"   "$SEEDS/gemini/google_account_id"   "google_account_id"
sync_file "$HOME/.gemini/GEMINI.md"           "$SEEDS/gemini/GEMINI.md"           "GEMINI.md"
echo

# ── OpenCode ─────────────────────────────────────────────
echo "OpenCode:"
mkdir -p "$SEEDS/opencode"

# Auth: ~/.local/share/opencode/auth.json
sync_file "$HOME/.local/share/opencode/auth.json" "$SEEDS/opencode/auth.json" "auth"

# Config: ~/.config/opencode/ (includes opencode.json, oh-my-opencode, plugins)
if [[ -d "$HOME/.config/opencode" ]]; then
  mkdir -p "$SEEDS/opencode/config"
  # Copy all config files (opencode.json, oh-my-opencode.json, antigravity-accounts.json, etc.)
  for f in "$HOME/.config/opencode"/*.json; do
    [[ -f "$f" ]] && sync_file "$f" "$SEEDS/opencode/config/$(basename "$f")" "config/$(basename "$f")"
  done
  # Copy node_modules for plugins (oh-my-opencode etc.)
  if [[ -d "$HOME/.config/opencode/node_modules" ]]; then
    rm -rf "$SEEDS/opencode/config/node_modules"
    cp -a "$HOME/.config/opencode/node_modules" "$SEEDS/opencode/config/node_modules"
    ok "config/node_modules (plugins)"
  fi
  sync_file "$HOME/.config/opencode/package.json" "$SEEDS/opencode/config/package.json" "config/package.json"
  sync_file "$HOME/.config/opencode/bun.lock"     "$SEEDS/opencode/config/bun.lock"     "config/bun.lock"
fi
echo

# ── GitHub Copilot ─────────────────────────────────────
echo "GitHub Copilot:"
mkdir -p "$SEEDS/github-copilot"
sync_file "$HOME/.config/github-copilot/apps.json"     "$SEEDS/github-copilot/apps.json"     "auth (apps.json)"
sync_file "$HOME/.config/github-copilot/versions.json"  "$SEEDS/github-copilot/versions.json"  "versions"
echo

echo "Seeds dir: $SEEDS"
find "$SEEDS" -type f | sort
