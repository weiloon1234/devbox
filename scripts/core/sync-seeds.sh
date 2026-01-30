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

# ── Claude Code ──────────────────────────────────────────
echo "Claude Code:"
mkdir -p "$SEEDS/claude"

# Auth: macOS Keychain or Linux file
if [[ -f "$HOME/.claude/credentials.json" ]]; then
  cp "$HOME/.claude/credentials.json" "$SEEDS/claude/credentials.json"
  chmod 600 "$SEEDS/claude/credentials.json"
  ok "auth (from credentials file)"
elif [[ "$(uname)" == "Darwin" ]]; then
  CLAUDE_CREDS="$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)"
  if [[ -n "$CLAUDE_CREDS" ]]; then
    echo "$CLAUDE_CREDS" > "$SEEDS/claude/credentials.json"
    chmod 600 "$SEEDS/claude/credentials.json"
    ok "auth (from macOS Keychain)"
  else
    skip "auth (not found in Keychain)"
  fi
else
  skip "auth (no credentials found)"
fi

# Settings, agents, plugins config, skills
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
sync_file "$HOME/.opencode/auth.json" "$SEEDS/opencode/auth.json" "auth"
echo

echo "Seeds dir: $SEEDS"
find "$SEEDS" -type f | sort
