#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${ROOT_DIR}/scripts/lib"

# ---- template paths ----
NGINX_HTTPS_TEMPLATE="${ROOT_DIR}/nginx/site-https.conf.template"
NGINX_HTTP_TEMPLATE="${ROOT_DIR}/nginx/site-http.conf.template"
NGINX_ACME_TEMPLATE="${ROOT_DIR}/nginx/site-acme.conf.template"
NGINX_SITE_COMMON_TEMPLATE="${ROOT_DIR}/nginx/site-common.conf.template"
NGINX_MAIN_TEMPLATE="${ROOT_DIR}/templates/nginx-main.conf.template"
BROWSER_TEMPLATE="${ROOT_DIR}/web/file-browser.html.template"
UPLOAD_TEMPLATE="${ROOT_DIR}/web/file-upload.html.template"
SHARED_STYLES_TEMPLATE="${ROOT_DIR}/web/shared-styles.css.template"
AUTH_MAP_TEMPLATE="${ROOT_DIR}/nginx/site-auth-map.conf.template"
TFW_TEMPLATE="${ROOT_DIR}/templates/tfw.conf.template"
TFW_BIN_SRC="${ROOT_DIR}/bin/tfw"

# ---- user-configurable variables ----
ACTION="${1:-install}"
INSTALL_MODE="${INSTALL_MODE:-}"
LANGUAGE="${LANGUAGE:-}"
DOMAIN="${DOMAIN:-}"
SITE_ID="${SITE_ID:-}"
ACCESS_HOST="${ACCESS_HOST:-}"
SITE_TITLE="${SITE_TITLE:-}"
PROJECT_URL="${PROJECT_URL:-https://github.com/JayhaShf/Temp-File-Web}"
TFW_USER="${TFW_USER:-}"
DATA_DIR="${DATA_DIR:-}"
SITE_BASE_DIR="${SITE_BASE_DIR:-}"
SITE_DIR="${SITE_DIR:-}"
INSTALL_ACME_IS_SET=0
if [[ "${INSTALL_ACME+x}" == x ]]; then
  INSTALL_ACME_IS_SET=1
fi
ACME_EMAIL_IS_SET=0
if [[ "${ACME_EMAIL+x}" == x ]]; then
  ACME_EMAIL_IS_SET=1
fi
ACME_WEBROOT="${ACME_WEBROOT:-}"
ACME_EMAIL="${ACME_EMAIL:-}"
AUTH_USER="${AUTH_USER:-}"
AUTH_PASSWORD="${AUTH_PASSWORD:-}"
AUTH_SESSION_TOKEN="${AUTH_SESSION_TOKEN:-}"
MAX_UPLOAD_SIZE="${MAX_UPLOAD_SIZE:-}"
IP="${IP:-127.0.0.1}"
HTTP_PORT="${HTTP_PORT:-}"
HTTPS_PORT="${HTTPS_PORT:-}"
AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-1}"
INSTALL_ACME="${INSTALL_ACME:-1}"

# ---- derived paths ----
CONF_DIR="/etc/nginx/conf.d"
CONF_FILE=""
ACME_CONF_FILE=""
AUTH_MAP_FILE="${CONF_DIR}/temp-file-web-map.conf"
TFW_CONFIG_DIR="/etc/tfw"
TFW_CONFIG_FILE="${TFW_CONFIG_DIR}/tfw.conf"
ACME_HOME="/root/.acme.sh"
ACME_BIN="${ACME_HOME}/acme.sh"
ACCESS_LOG=""
ERROR_LOG=""
UNINSTALL_KEEP_DATA="${UNINSTALL_KEEP_DATA:-1}"
UNINSTALL_KEEP_CERTS="${UNINSTALL_KEEP_CERTS:-1}"
SITE_MODE="${SITE_MODE:-}"

LANG_HTML="en"
JS_LOCALE='"en-US"'

# ---- source library modules ----
. "$LIB_DIR/common.sh"
. "$LIB_DIR/i18n.sh"
. "$LIB_DIR/deps.sh"
. "$LIB_DIR/prompt.sh"
. "$LIB_DIR/validate.sh"
. "$LIB_DIR/template.sh"
. "$LIB_DIR/acme.sh"
. "$LIB_DIR/auth.sh"

# ---- remaining functions kept in install.sh ----

usage() {
  cat <<'EOF'
bash scripts/install.sh [install|upgrade|uninstall]

Environment examples:
  DOMAIN=files.example.com INSTALL_MODE=default LANGUAGE=zh bash scripts/install.sh install
  LANGUAGE=zh bash scripts/install.sh upgrade
  LANGUAGE=zh UNINSTALL_KEEP_DATA=1 UNINSTALL_KEEP_CERTS=1 bash scripts/install.sh uninstall
EOF
}

load_existing_runtime_config() {
  if [[ -f "$TFW_CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    . "$TFW_CONFIG_FILE"
    return 0
  fi
  return 1
}

print_summary() {
  echo "$(msg summary)"
  echo "  language        : $LANGUAGE"
  echo "  mode            : $INSTALL_MODE"
  echo "  domain          : $DOMAIN"
  echo "  site title      : $SITE_TITLE"
  echo "  project url     : $PROJECT_URL"
  echo "  nginx user      : $TFW_USER"
  echo "  data dir        : $DATA_DIR"
  echo "  upload dir      : $UPLOAD_DIR"
  echo "  site dir        : $SITE_DIR"
  echo "  site mode       : ${SITE_MODE:-auto}"
  echo "  access host     : $ACCESS_HOST"
  echo "  http port       : $HTTP_PORT"
  echo "  https port      : $HTTPS_PORT"
  echo "  acme enabled    : $(if [[ "$INSTALL_ACME" == "1" ]]; then msg yes; else msg no; fi)"
  if [[ "$INSTALL_ACME" == "1" ]]; then
    echo "  acme webroot    : $ACME_WEBROOT"
    echo "  acme email      : ${ACME_EMAIL:-$(msg not_set)}"
  fi
  echo "  auth user       : $AUTH_USER"
  echo "  upload max size : $MAX_UPLOAD_SIZE"
}

install_runtime_files() {
  echo "$(msg install_conf)"

  backup_if_exists "$CONF_FILE"
  backup_if_exists "$ACME_CONF_FILE"
  backup_if_exists "$AUTH_MAP_FILE"
  backup_if_exists "$TFW_CONFIG_FILE"
  backup_if_exists /usr/local/bin/tfw

  render_pages
  if [[ "$INSTALL_ACME" == "1" ]]; then
    render_acme_challenge_conf
  else
    rm -f "$ACME_CONF_FILE"
  fi
  install_tfw_config
  install -m 0755 "$TFW_BIN_SRC" /usr/local/bin/tfw
}

upgrade_runtime_files() {
  echo "$(msg upgrade)"

  load_existing_runtime_config || {
    echo "$(msg missing_runtime)" >&2
    exit 1
  }

  restore_runtime_derived_values
  set_site_mode
  backup_if_exists "$CONF_FILE"
  backup_if_exists "$TFW_CONFIG_FILE"
  backup_if_exists "$AUTH_MAP_FILE"
  backup_if_exists /usr/local/bin/tfw

  render_pages
  install -m 0755 "$TFW_BIN_SRC" /usr/local/bin/tfw

  if have_tls_assets; then
    SITE_MODE="https"
    render_site_conf
    rm -f "$ACME_CONF_FILE"
  elif [[ "$INSTALL_ACME" == "1" ]]; then
    SITE_MODE="http"
    render_acme_challenge_conf
  else
    SITE_MODE="http"
    render_http_site_conf
    rm -f "$ACME_CONF_FILE"
  fi

  install_tfw_config

  reload_nginx_if_present || true
  echo "$(msg upgrade_done)"
}

uninstall_runtime_files() {
  echo "$(msg uninstall)"

  load_existing_runtime_config || {
    echo "$(msg missing_runtime)" >&2
    exit 1
  }

  restore_runtime_derived_values
  echo "$(msg keep_hint)"

  rm -f "$CONF_FILE" "$ACME_CONF_FILE" "$AUTH_MAP_FILE" "$TFW_CONFIG_FILE" /usr/local/bin/tfw

  if [[ "$UNINSTALL_KEEP_CERTS" == "0" ]]; then
    rm -rf "$SITE_DIR/certs"
  else
    echo "$(msg uninstall_keep_certs)"
  fi

  rm -f "$SITE_DIR/file-browser.html" "$SITE_DIR/file-upload.html" "$SITE_DIR/file-upload.htpasswd"

  if [[ "$UNINSTALL_KEEP_DATA" == "0" ]]; then
    rm -rf "$DATA_DIR"
  else
    echo "$(msg uninstall_keep_data)"
  fi

  if [[ -d "$SITE_DIR" ]] && [[ -z "$(find "$SITE_DIR" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    rmdir "$SITE_DIR" || true
  fi

  reload_nginx_if_present || true
  echo "$(msg uninstall_done)"
}

main() {
  need_root

  case "$ACTION" in
    install)
      ;;
    upgrade)
      choose_language
      upgrade_runtime_files
      exit 0
      ;;
    uninstall)
      choose_language
      uninstall_runtime_files
      exit 0
      ;;
    help|-h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac

  choose_language
  choose_install_mode

  if [[ "$INSTALL_MODE" == "interactive" ]]; then
    collect_interactive_input
  else
    set_default_mode_values
  fi

  validate_inputs
  preflight_checks
  apply_defaults
  set_site_mode
  print_summary

  echo "$(msg start)"
  install_dependencies
  ensure_dirs
  install_runtime_files
  write_auth_file
  install_acme_sh
  reload_nginx_for_acme

  issue_certificate_if_enabled || true

  if have_tls_assets; then
    finalize_https_config
  else
    SITE_MODE="http"
    render_http_site_conf
    install_tfw_config
    rm -f "$ACME_CONF_FILE"
    reload_nginx_if_present || true
    echo "$(msg tls_missing)"
    echo "$(msg http_ready)"
    echo "site mode       : $SITE_MODE"
    echo "access host     : $ACCESS_HOST"
    echo "access port     : $(current_access_port)"
    echo "upload user     : $AUTH_USER"
    echo "upload password : $AUTH_PASSWORD"
    echo "expected cert dir: $SITE_DIR/certs/"
    echo "$(msg tls_next)"
    exit 0
  fi

  echo "$(msg done)"
  echo "site mode       : $SITE_MODE"
  echo "access host     : $ACCESS_HOST"
  echo "access port     : $(current_access_port)"
  echo "tfw config      : $TFW_CONFIG_FILE"
  echo "site config     : $CONF_FILE"
  echo "cert file       : $SITE_DIR/certs/fullchain.cer"
  echo "key file        : $SITE_DIR/certs/$SITE_ID.key"
  echo "upload user     : $AUTH_USER"
  echo "upload password : $AUTH_PASSWORD"
  echo "$(msg nginx_main_hint) ${NGINX_MAIN_TEMPLATE}"
  echo "$(msg next)"
}

main "$@"
