#!/usr/bin/env bash
# ssh-config.sh — manage ~/.ssh/config entries for devbox workspaces
#
# Usage:
#   source "$ROOT/scripts/lib/ssh-config.sh"
#   ssh_config_set "devbox-alex" 2223 "/path/to/key" "/workspace"
#   ssh_config_set "devbox-alex--hxc" 2223 "/path/to/key" "/workspace/projects/hxc"
#   ssh_config_remove "devbox-alex--hxc"

SSH_CONFIG="$HOME/.ssh/config"

# Add or update an SSH config block for a devbox host.
# Args: host_alias ssh_port identity_file remote_dir
ssh_config_set() {
  local alias="$1" port="$2" key="$3" remote_dir="$4"

  mkdir -p "$HOME/.ssh"
  touch "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"

  # Remove existing block if present
  ssh_config_remove "$alias" 2>/dev/null

  cat >> "$SSH_CONFIG" <<EOF

# [devbox] auto-generated
Host $alias
  HostName 127.0.0.1
  Port $port
  User ubuntu
  IdentityFile $key
  IdentitiesOnly yes
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  RemoteCommand cd $remote_dir && exec bash -l
  RequestTTY yes
EOF
}

# Remove a devbox SSH config block by alias.
# Args: host_alias
ssh_config_remove() {
  local alias="$1"
  [[ -f "$SSH_CONFIG" ]] || return 0

  # Remove the comment line + Host block (everything until next Host or EOF)
  local tmp
  tmp="$(mktemp)"
  awk -v host="$alias" '
    /^# \[devbox\]/ { pending=1; next }
    /^Host / {
      if (pending && $2 == host) { skip=1; pending=0; next }
      if (pending) { print "# [devbox] auto-generated" }
      pending=0
      if (skip) { skip=0 }
    }
    skip { next }
    pending { print "# [devbox] auto-generated"; pending=0 }
    { print }
  ' "$SSH_CONFIG" > "$tmp"
  mv "$tmp" "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
}
