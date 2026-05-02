#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_CONF_SRC="${ROOT_DIR}/nginx/file.conf"
FILE_BROWSER_SRC="${ROOT_DIR}/web/file-browser.html"
FILE_UPLOAD_SRC="${ROOT_DIR}/web/file-upload.html"
TFW_SRC="${ROOT_DIR}/bin/tfw"
HTPASSWD_EXAMPLE="${ROOT_DIR}/templates/file-upload.htpasswd.example"

need_root() {
  [[ "$(id -u)" -eq 0 ]] || {
    echo "need root" >&2
    exit 1
  }
}

backup_if_exists() {
  local file="$1"
  if [[ -e "$file" ]]; then
    cp "$file" "${file}.bak-$(date +%Y%m%d%H%M%S)"
  fi
}

need_root

mkdir -p /etc/nginx/conf.d
mkdir -p /etc/nginx/jayha.top

backup_if_exists /etc/nginx/conf.d/file.conf
backup_if_exists /etc/nginx/jayha.top/file-browser.html
backup_if_exists /etc/nginx/jayha.top/file-upload.html
backup_if_exists /usr/local/bin/tfw

install -m 0644 "$NGINX_CONF_SRC" /etc/nginx/conf.d/file.conf
install -m 0644 "$FILE_BROWSER_SRC" /etc/nginx/jayha.top/file-browser.html
install -m 0644 "$FILE_UPLOAD_SRC" /etc/nginx/jayha.top/file-upload.html
install -m 0755 "$TFW_SRC" /usr/local/bin/tfw

if [[ ! -f /etc/nginx/jayha.top/file-upload.htpasswd ]]; then
  install -m 0644 "$HTPASSWD_EXAMPLE" /etc/nginx/jayha.top/file-upload.htpasswd
  echo "created /etc/nginx/jayha.top/file-upload.htpasswd from example"
fi

nginx -t
echo "installed. run: tfw status"
