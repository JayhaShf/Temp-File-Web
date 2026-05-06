#!/usr/bin/env bash

detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo apt
  elif command -v dnf >/dev/null 2>&1; then
    echo dnf
  elif command -v yum >/dev/null 2>&1; then
    echo yum
  else
    echo none
  fi
}

install_dependencies() {
  local manager missing=()
  local dep

  for dep in nginx curl openssl sed awk grep find tail ls envsubst; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      missing+=("$dep")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi

  [[ "$AUTO_INSTALL_DEPS" == "1" ]] || {
    printf 'missing dependencies: %s\n' "${missing[*]}" >&2
    exit 1
  }

  echo "$(msg deps)"
  manager="$(detect_pkg_manager)"
  case "$manager" in
    apt)
      apt-get update
      DEBIAN_FRONTEND=noninteractive apt-get install -y nginx curl openssl apache2-utils gettext-base
      ;;
    dnf)
      dnf install -y nginx curl openssl httpd-tools gettext
      ;;
    yum)
      yum install -y nginx curl openssl httpd-tools gettext
      ;;
    *)
      echo "$(msg deps_fail)" >&2
      exit 1
      ;;
  esac
}

detect_nginx_user() {
  if id -u www-data >/dev/null 2>&1; then
    printf '%s\n' "www-data"
  elif id -u nginx >/dev/null 2>&1; then
    printf '%s\n' "nginx"
  else
    printf '%s\n' "www-data"
  fi
}

default_http_port() {
  if [[ -n "$DOMAIN" ]]; then
    printf '%s\n' "80"
  else
    printf '%s\n' "8080"
  fi
}

default_https_port() {
  if [[ -n "$DOMAIN" ]]; then
    printf '%s\n' "443"
  else
    printf '%s\n' "8443"
  fi
}

slugify_site_id() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  value="$(printf '%s' "$value" | sed 's/[^a-z0-9._-]/-/g')"
  value="$(printf '%s' "$value" | sed 's/--*/-/g; s/^-//; s/-$//')"
  printf '%s' "${value:-site}"
}

default_site_id() {
  if [[ -n "$DOMAIN" ]]; then
    slugify_site_id "$DOMAIN"
  elif [[ -n "$ACCESS_HOST" ]]; then
    slugify_site_id "$ACCESS_HOST"
  else
    slugify_site_id "$IP"
  fi
}

apply_defaults() {
  SITE_TITLE="${SITE_TITLE:-Temp File Web}"
  TFW_USER="${TFW_USER:-$(detect_nginx_user)}"
  ACCESS_HOST="${ACCESS_HOST:-${DOMAIN:-$IP}}"
  SITE_ID="${SITE_ID:-$(default_site_id)}"
  DATA_DIR="${DATA_DIR:-/srv/tfw/data}"
  UPLOAD_DIR="${UPLOAD_DIR:-$DATA_DIR}"
  SITE_BASE_DIR="${SITE_BASE_DIR:-/etc/tfw/sites}"
  SITE_DIR="${SITE_DIR:-$SITE_BASE_DIR/$SITE_ID}"
  ACME_WEBROOT="${ACME_WEBROOT:-/var/www/_acme-challenge}"
  HTTP_PORT="${HTTP_PORT:-$(default_http_port)}"
  HTTPS_PORT="${HTTPS_PORT:-$(default_https_port)}"
  if [[ "$INSTALL_ACME" == "1" && -n "$DOMAIN" && "$ACME_EMAIL_IS_SET" -eq 0 ]]; then
    ACME_EMAIL="admin@$DOMAIN"
  fi
  AUTH_USER="${AUTH_USER:-uploader}"
  AUTH_SESSION_TOKEN="${AUTH_SESSION_TOKEN:-$(random_session_token)}"
  AUTH_SESSION_MAX_AGE="${AUTH_SESSION_MAX_AGE:-86400}"
  TFW_PROJECT_DIR="${TFW_PROJECT_DIR:-$ROOT_DIR}"
  MAX_UPLOAD_SIZE="${MAX_UPLOAD_SIZE:-2g}"
  CONF_FILE="${CONF_FILE:-$CONF_DIR/temp-file-web.conf}"
  ACME_CONF_FILE="${ACME_CONF_FILE:-$CONF_DIR/temp-file-web-acme.conf}"
  ACCESS_LOG="/var/log/nginx/$SITE_ID.access.log"
  ERROR_LOG="/var/log/nginx/$SITE_ID.error.log"
}

restore_runtime_derived_values() {
  ACCESS_HOST="${ACCESS_HOST:-${DOMAIN:-$IP}}"
  SITE_ID="${SITE_ID:-$(default_site_id)}"
  HTTP_PORT="${HTTP_PORT:-80}"
  HTTPS_PORT="${HTTPS_PORT:-443}"
  CONF_FILE="${CONF_FILE:-$CONF_DIR/temp-file-web.conf}"
  ACME_CONF_FILE="${ACME_CONF_FILE:-$CONF_DIR/temp-file-web-acme.conf}"
  UPLOAD_DIR="${UPLOAD_DIR:-$DATA_DIR/uploads}"
  SITE_DIR="${SITE_DIR:-$SITE_BASE_DIR/$SITE_ID}"
  ACCESS_LOG="${ACCESS_LOG:-/var/log/nginx/$SITE_ID.access.log}"
  ERROR_LOG="${ERROR_LOG:-/var/log/nginx/$SITE_ID.error.log}"
  SITE_MODE="${SITE_MODE:-https}"
  INSTALL_ACME="${INSTALL_ACME:-1}"
  # Fix up values that may be literal template placeholders from broken renders
  if [[ "$SITE_MODE" == '${SITE_MODE}' ]]; then SITE_MODE="http"; fi
  if [[ "$INSTALL_ACME" == '${INSTALL_ACME}' ]]; then INSTALL_ACME="0"; fi
  TFW_PROJECT_DIR="${TFW_PROJECT_DIR:-$ROOT_DIR}"
}

ensure_dirs() {
  mkdir -p \
    "$CONF_DIR" \
    "$TFW_CONFIG_DIR" \
    "$SITE_DIR" \
    "$SITE_DIR/certs" \
    "$DATA_DIR" \
    "$UPLOAD_DIR"

  if [[ "$INSTALL_ACME" == "1" ]]; then
    mkdir -p "$ACME_WEBROOT/.well-known/acme-challenge"
  fi

  chmod 0755 "$DATA_DIR" "$UPLOAD_DIR"
  chmod 0700 "$SITE_DIR/certs"

  if id -u "$TFW_USER" >/dev/null 2>&1; then
    chown -R "$TFW_USER":"$(id -gn "$TFW_USER")" "$DATA_DIR"
  fi
}
