#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SEEDS="$ROOT/seeds"

mkdir -p "$SEEDS"

ok(){ echo "✅ $*"; }
skip(){ echo "⏭  $*"; }

echo "=== devbox sync-seeds ==="
echo "Syncing AI tool auth from macOS → seeds/"
echo

# Codex: ~/.codex/auth.json
if [[ -f "$HOME/.codex/auth.json" ]]; then
  cp "$HOME/.codex/auth.json" "$SEEDS/codex-auth.json"
  ok "codex auth"
else
  skip "codex (~/.codex/auth.json not found)"
fi

# Claude Code: ~/.claude/credentials.json (Linux file-based auth)
# On macOS, Claude uses Keychain — no file exists.
# User must run `claude` once inside the container to create credentials.json,
# then copy it here for future seeding.
if [[ -f "$HOME/.claude/credentials.json" ]]; then
  cp "$HOME/.claude/credentials.json" "$SEEDS/claude-credentials.json"
  ok "claude auth"
elif [[ -f "$SEEDS/claude-credentials.json" ]]; then
  ok "claude auth (using existing seed)"
else
  skip "claude (~/.claude/credentials.json not found)"
  echo "   Tip: run 'claude' inside a workspace first, then copy"
  echo "   the credentials.json from the container to seeds/"
fi

# Gemini: ~/.gemini/oauth_creds.json
if [[ -f "$HOME/.gemini/oauth_creds.json" ]]; then
  cp "$HOME/.gemini/oauth_creds.json" "$SEEDS/gemini-oauth.json"
  ok "gemini auth"
else
  skip "gemini (~/.gemini/oauth_creds.json not found)"
fi

# OpenCode: ~/.opencode/auth.json
if [[ -f "$HOME/.opencode/auth.json" ]]; then
  cp "$HOME/.opencode/auth.json" "$SEEDS/opencode-auth.json"
  ok "opencode auth"
else
  skip "opencode (~/.opencode/auth.json not found)"
fi

echo
echo "Seeds dir: $SEEDS"
ls -la "$SEEDS"
