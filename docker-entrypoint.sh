#!/usr/bin/env bash
# Docker entrypoint: render config and start nginx.
set -euo pipefail

cd /opt/tfw

# Defaults for container environment
export DOMAIN="${DOMAIN:-localhost}"
export LANGUAGE="${LANGUAGE:-en}"
export INSTALL_MODE="${INSTALL_MODE:-default}"
export INSTALL_ACME="${INSTALL_ACME:-0}"
export AUTO_INSTALL_DEPS=0
export TFW_USER="nginx"

bash scripts/install.sh install || true

# Fix nginx user for alpine
sed -i 's/^user .*/user nginx;/' /etc/nginx/nginx.conf 2>/dev/null || true

exec nginx -g "daemon off;"
