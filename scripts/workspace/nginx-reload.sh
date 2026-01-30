#!/usr/bin/env bash
set -euo pipefail
WS="${1:-}"
[[ -n "$WS" ]] || { echo "usage: devbox workspace nginx-reload <workspace>"; exit 1; }
docker exec "ws-$WS-nginx" nginx -s reload