#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail(){ echo "ERROR: $*" >&2; exit 1; }

prompt() {
  local var_name="$1"
  local label="$2"
  local default="${3:-}"
  local input=""
  if [[ -n "$default" ]]; then
    read -r -p "$label [$default]: " input
    input="${input:-$default}"
  else
    read -r -p "$label: " input
  fi
  printf -v "$var_name" '%s' "$input"
}

lower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

echo "=== devbox workspace add-project ==="

# Workspace selection
prompt WS "Workspace name (example: personal/private)" ""
WS="$(lower "$WS")"
[[ -n "$WS" ]] || fail "workspace is required"

# Validate workspace exists
COMPOSE="$ROOT/generated/workspaces/$WS/docker-compose.yml"
[[ -f "$COMPOSE" ]] || fail "workspace not found: generated/workspaces/$WS (run devbox workspace new first)"

# Domain
prompt DOMAIN "Domain (example: api.${WS}.test)" ""
DOMAIN="$(lower "$DOMAIN")"
[[ -n "$DOMAIN" ]] || fail "domain is required"
[[ "$DOMAIN" == *".test" ]] || fail "domain must end with .test"

# Project folder
prompt PROJECT "Project folder name inside /workspace/projects" ""
PROJECT="$(lower "$PROJECT")"
[[ -n "$PROJECT" ]] || fail "project folder is required"

# Type
echo "Select project type:"
echo "  1) laravel  (php, webroot=public, entry=index.php)"
echo "  2) php      (php, webroot=.,      entry=index.php)"
echo "  3) static   (files, webroot=.,    entry=index.html)"
echo "  4) spa      (vite build, webroot=dist, entry=index.html)"
echo "  5) proxy    (go/rust/node server on port, nginx reverse proxy)"
read -r -p "Type [1-5]: " TYPE_CHOICE

case "$TYPE_CHOICE" in
  1) TYPE="laravel" ;;
  2) TYPE="php" ;;
  3) TYPE="static" ;;
  4) TYPE="spa" ;;
  5) TYPE="proxy" ;;
  *) fail "invalid type selection" ;;
esac

# Defaults
WEBROOT_DEFAULT="."
ENTRY_DEFAULT=""
UPSTREAM_PORT_DEFAULT=""

case "$TYPE" in
  laravel)
    WEBROOT_DEFAULT="public"
    ENTRY_DEFAULT="index.php"
    ;;
  php)
    WEBROOT_DEFAULT="."
    ENTRY_DEFAULT="index.php"
    ;;
  static)
    WEBROOT_DEFAULT="."
    ENTRY_DEFAULT="index.html"
    ;;
  spa)
    WEBROOT_DEFAULT="dist"
    ENTRY_DEFAULT="index.html"
    ;;
  proxy)
    WEBROOT_DEFAULT="."
    UPSTREAM_PORT_DEFAULT="3000"
    ;;
esac

prompt WEBROOT "Webroot path relative to project (example: public, dist, .)" "$WEBROOT_DEFAULT"

if [[ "$TYPE" != "proxy" ]]; then
  prompt ENTRY "Entry file (example: index.php, index.html)" "$ENTRY_DEFAULT"
fi

if [[ "$TYPE" == "proxy" ]]; then
  prompt UPSTREAM_PORT "Upstream port inside workspace container (bind to 0.0.0.0)" "$UPSTREAM_PORT_DEFAULT"
  [[ "$UPSTREAM_PORT" =~ ^[0-9]+$ ]] || fail "upstream port must be numeric"
fi

# Remote paths inside workspace volume
REMOTE_PROJECT_DIR="/workspace/projects/$PROJECT"
REMOTE_WEB_DIR="$REMOTE_PROJECT_DIR/$WEBROOT"
REMOTE_STUB_DIR="/workspace/nginx-stubs/$WS"
REMOTE_STUB_PATH="$REMOTE_STUB_DIR/$DOMAIN.conf"

echo
echo "Summary:"
echo " - workspace: $WS"
echo " - type:      $TYPE"
echo " - domain:    https://$DOMAIN"
echo " - project:   $REMOTE_PROJECT_DIR"
echo " - webroot:   $REMOTE_WEB_DIR"
if [[ "$TYPE" != "proxy" ]]; then
  echo " - entry:     $ENTRY"
else
  echo " - upstream:  ws-$WS:$UPSTREAM_PORT"
fi
echo

read -r -p "Create/update nginx stub and reload nginx? (y/N): " CONFIRM
CONFIRM="$(lower "$CONFIRM")"
[[ "$CONFIRM" == "y" ]] || exit 0

# Determine PHP upstream if needed
PHP_UPSTREAM=""
if [[ "$TYPE" == "laravel" || "$TYPE" == "php" ]]; then
  # Read .php-version from project root (default 8.4)
  PHP_VERSION="$(docker exec "ws-$WS" bash -lc "cat '$REMOTE_PROJECT_DIR/.php-version' 2>/dev/null || true" | tr -d '\r' | xargs || true)"
  [[ -n "$PHP_VERSION" ]] || PHP_VERSION="8.4"

  case "$PHP_VERSION" in
    8.1) PHP_UPSTREAM="ws-$WS-php81" ;;
    8.2) PHP_UPSTREAM="ws-$WS-php82" ;;
    8.3) PHP_UPSTREAM="ws-$WS-php83" ;;
    8.4) PHP_UPSTREAM="ws-$WS-php84" ;;
    8.5) PHP_UPSTREAM="ws-$WS-php85" ;;
    *) fail "unsupported php version '$PHP_VERSION' (supported: 8.1, 8.2, 8.3, 8.4, 8.5). Set $REMOTE_PROJECT_DIR/.php-version" ;;
  esac
fi

# Create directories + write stub inside workspace volume
docker exec "ws-$WS" bash -lc "mkdir -p '$REMOTE_PROJECT_DIR' '$REMOTE_STUB_DIR'"

# Scaffold per-project .devcontainer/devcontainer.json (skip if exists)
docker exec "ws-$WS" bash -lc "[ -f '$REMOTE_PROJECT_DIR/.devcontainer/devcontainer.json' ]" 2>/dev/null || \
  docker exec -i "ws-$WS" bash -c "mkdir -p '$REMOTE_PROJECT_DIR/.devcontainer' && cat > '$REMOTE_PROJECT_DIR/.devcontainer/devcontainer.json'" <<EOF
{
  "name": "${PROJECT}",
  "remoteUser": "ubuntu",
  "workspaceFolder": "${REMOTE_PROJECT_DIR}",
  "customizations": {
    "vscode": {
      "extensions": [],
      "settings": {}
    }
  }
}
EOF

case "$TYPE" in
  laravel|php)
    # PHP / Laravel stub
    docker exec "ws-$WS" bash -lc "cat > '$REMOTE_STUB_PATH' <<'EOF'
server {
  listen 80;
  server_name ${DOMAIN};

  root ${REMOTE_WEB_DIR};
  index index.php index.html;

  location / {
    try_files \$uri \$uri/ /index.php?\$query_string;
  }

  location ~ \\.php\$ {
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    fastcgi_index index.php;
    fastcgi_read_timeout 300;
    fastcgi_pass ${PHP_UPSTREAM}:9000;
  }

  location ~* \\.(jpg|jpeg|png|gif|css|js|ico|svg|woff2?)\$ {
    expires 7d;
    access_log off;
  }
}
EOF"
    ;;

  static|spa)
    # Static stub (serves files directly)
    docker exec "ws-$WS" bash -lc "cat > '$REMOTE_STUB_PATH' <<'EOF'
server {
  listen 80;
  server_name ${DOMAIN};

  root ${REMOTE_WEB_DIR};
  index ${ENTRY};

  location / {
    try_files \$uri \$uri/ =404;
  }
}
EOF"
    ;;

  proxy)
    # Reverse proxy stub (Go/Rust/Node server)
    docker exec "ws-$WS" bash -lc "cat > '$REMOTE_STUB_PATH' <<'EOF'
map \$http_upgrade \$connection_upgrade {
  default upgrade;
  ''      close;
}

server {
  listen 80;
  server_name ${DOMAIN};

  location / {
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;

    # WebSocket support
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;

    proxy_read_timeout 300;
    proxy_pass http://ws-${WS}:${UPSTREAM_PORT};
  }
}
EOF"
    ;;
esac

# Reload nginx (workspace nginx container)
docker exec "ws-$WS-nginx" nginx -s reload

# Add per-project SSH config entry for VS Code Remote SSH
source "$ROOT/scripts/lib/ws-meta.sh"
ws_load_meta "$WS"
source "$ROOT/scripts/lib/ssh-config.sh"
ssh_config_set "devbox-${WS}--${PROJECT}" "$SSH_PORT" "$WS_PRIVKEY" "$REMOTE_PROJECT_DIR"

echo "OK:"
echo " - created:    $REMOTE_PROJECT_DIR"
echo " - wrote stub: $REMOTE_STUB_PATH"
echo " - reloaded:   ws-$WS-nginx"
echo " - ssh config: Host devbox-${WS}--${PROJECT}"
echo
echo "Access:"
echo "  SSH:    devbox workspace ssh $WS  →  cd projects/$PROJECT"
echo "  VS Code: Remote-SSH → devbox-${WS}--${PROJECT}"
echo "  Finder: ~/DevboxMount/$WS/projects/$PROJECT"
echo "  URL:    https://$DOMAIN"