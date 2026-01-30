#!/bin/sh
# Wrapper: resolve .php-version from CWD upward, default 8.4
set -e

DEFAULT_VERSION="8.4"
VERSION=""

# Walk up from CWD looking for .php-version
dir="$PWD"
while true; do
  if [ -f "$dir/.php-version" ]; then
    VERSION="$(cat "$dir/.php-version" | tr -d '[:space:]')"
    break
  fi
  parent="$(dirname "$dir")"
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done

[ -n "$VERSION" ] || VERSION="$DEFAULT_VERSION"

PHP_BIN="/opt/php/$VERSION/bin/php"
if [ ! -x "$PHP_BIN" ]; then
  echo "ERROR: PHP $VERSION not available (no $PHP_BIN)" >&2
  exit 1
fi

export LD_LIBRARY_PATH="/opt/php/$VERSION/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$PHP_BIN" "$@"
