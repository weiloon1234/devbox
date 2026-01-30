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

# Point to the correct ini directory for this PHP version
# (extension_dir is set inside 00-extension-dir.ini)
export PHP_INI_SCAN_DIR="/opt/php/$VERSION/etc/php/conf.d"

# Use the bundled dynamic linker to isolate from host glibc (Debian 13 vs Ubuntu 24.04)
LINKER="$(ls /opt/php/$VERSION/lib/ld-linux-* 2>/dev/null | head -1)"
if [ -n "$LINKER" ] && [ -x "$LINKER" ]; then
  exec "$LINKER" --library-path "/opt/php/$VERSION/lib" "$PHP_BIN" "$@"
else
  export LD_LIBRARY_PATH="/opt/php/$VERSION/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  exec "$PHP_BIN" "$@"
fi
