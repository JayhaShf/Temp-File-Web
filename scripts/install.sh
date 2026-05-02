#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_HTTPS_TEMPLATE="${ROOT_DIR}/nginx/site-https.conf.template"
NGINX_HTTP_TEMPLATE="${ROOT_DIR}/nginx/site-http.conf.template"
NGINX_ACME_TEMPLATE="${ROOT_DIR}/nginx/site-acme.conf.template"
NGINX_SITE_COMMON_TEMPLATE="${ROOT_DIR}/nginx/site-common.conf.template"
NGINX_MAIN_TEMPLATE="${ROOT_DIR}/templates/nginx-main.conf.template"
BROWSER_TEMPLATE="${ROOT_DIR}/web/file-browser.html.template"
UPLOAD_TEMPLATE="${ROOT_DIR}/web/file-upload.html.template"
TFW_TEMPLATE="${ROOT_DIR}/templates/tfw.conf.template"
TFW_BIN_SRC="${ROOT_DIR}/bin/tfw"

ACTION="${1:-install}"
INSTALL_MODE="${INSTALL_MODE:-}"
LANGUAGE="${LANGUAGE:-}"
DOMAIN="${DOMAIN:-}"
SITE_ID="${SITE_ID:-}"
ACCESS_HOST="${ACCESS_HOST:-}"
SITE_TITLE="${SITE_TITLE:-}"
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
MAX_UPLOAD_SIZE="${MAX_UPLOAD_SIZE:-}"
IP="${IP:-127.0.0.1}"
HTTP_PORT="${HTTP_PORT:-}"
HTTPS_PORT="${HTTPS_PORT:-}"
AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-1}"
INSTALL_ACME="${INSTALL_ACME:-1}"

CONF_DIR="/etc/nginx/conf.d"
CONF_FILE=""
ACME_CONF_FILE=""
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

need_root() {
  [[ "$(id -u)" -eq 0 ]] || {
    echo "need root" >&2
    exit 1
  }
}

msg() {
  local key="$1"
  case "$LANGUAGE" in
    zh)
      case "$key" in
        choose_lang) echo "请选择安装语言 / Choose installation language: [1] 中文 [2] English" ;;
        choose_mode) echo "请选择安装模式: [1] 交互式安装 [2] 一键默认安装" ;;
        start) echo "开始安装模板项目..." ;;
        upgrade) echo "开始升级已安装站点..." ;;
        uninstall) echo "开始卸载已安装站点..." ;;
        deps) echo "检查并安装依赖..." ;;
        deps_fail) echo "无法自动安装依赖，请手动安装后重试。" ;;
        issue_acme) echo "正在使用 acme.sh 申请证书..." ;;
        install_conf) echo "正在写入站点配置与页面..." ;;
        gen_auth) echo "正在生成上传认证文件..." ;;
        done) echo "安装完成。" ;;
        next) echo "建议下一步执行: tfw info && tfw status" ;;
        uninstall_done) echo "卸载完成。" ;;
        uninstall_keep_data) echo "已保留数据目录。" ;;
        uninstall_keep_certs) echo "已保留证书目录。" ;;
        upgrade_done) echo "升级完成。" ;;
        ask_has_domain) echo "是否已绑定域名" ;;
        ask_domain) echo "输入绑定域名（可留空）" ;;
        ask_access_host) echo "输入访问主机名或 IP（留空使用 IP）" ;;
        ask_http_port) echo "输入 HTTP 端口（留空使用 80）" ;;
        ask_https_port) echo "输入 HTTPS 端口（留空使用 443）" ;;
        ask_title) echo "输入站点标题（留空使用默认值）" ;;
        ask_user) echo "输入 Nginx 运行用户（留空自动检测）" ;;
        ask_data) echo "输入数据目录（留空使用默认值）" ;;
        ask_site_base) echo "输入站点资源根目录（留空使用默认值）" ;;
        ask_install_acme) echo "是否启用 acme.sh 自动申请证书" ;;
        ask_acme_webroot) echo "输入 ACME challenge webroot（留空使用默认值）" ;;
        ask_acme_email) echo "输入证书通知邮箱（留空跳过）" ;;
        ask_auth_user) echo "输入上传用户名（留空使用默认值）" ;;
        ask_auth_password) echo "输入上传密码（留空则随机生成）" ;;
        confirm_auth_password) echo "再次输入上传密码确认" ;;
        ask_upload_size) echo "输入单文件上传大小上限，例如 2g（留空使用默认值）" ;;
        bad_domain) echo "域名不能包含空格。" ;;
        bad_access_host) echo "访问主机名或 IP 不能为空，且不能包含空格。" ;;
        bad_port) echo "端口必须是 1 到 65535 之间的整数。" ;;
        password_mismatch) echo "两次输入的密码不一致，请重试。" ;;
        invalid_yes_no) echo "请输入 y 或 n。" ;;
        acme_need_domain) echo "启用 acme.sh 时必须填写域名。" ;;
        acme_need_http_80) echo "启用 acme.sh 时 HTTP 端口必须为 80。" ;;
        acme_skip) echo "跳过 acme.sh 证书申请，将保留证书路径配置但不签发证书。" ;;
        tls_missing) echo "未发现可用证书文件。" ;;
        tls_next) echo "如需启用 HTTPS，请把证书放到站点 certs 目录后重新执行安装或 upgrade。" ;;
        http_ready) echo "当前已写入 HTTP 站点配置，可先直接使用。" ;;
        acme_install) echo "正在安装 acme.sh..." ;;
        nginx_main_hint) echo "主 nginx.conf 模板位于" ;;
        summary) echo "安装参数如下：" ;;
        mode_default) echo "使用一键默认安装参数。" ;;
        mode_interactive) echo "进入交互式安装。" ;;
        missing_runtime) echo "未找到现有运行配置，无法执行 upgrade 或 uninstall。" ;;
        keep_hint) echo "默认保留数据和证书；如需删除可设置 UNINSTALL_KEEP_DATA=0 或 UNINSTALL_KEEP_CERTS=0。" ;;
        not_set) echo "（未设置）" ;;
        yes) echo "是" ;;
        no) echo "否" ;;
      esac
      ;;
    *)
      case "$key" in
        choose_lang) echo "Choose installation language: [1] Chinese [2] English" ;;
        choose_mode) echo "Choose installation mode: [1] Interactive [2] One-click defaults" ;;
        start) echo "Starting template project installation..." ;;
        upgrade) echo "Starting upgrade for the installed site..." ;;
        uninstall) echo "Starting uninstall for the installed site..." ;;
        deps) echo "Checking and installing dependencies..." ;;
        deps_fail) echo "Failed to auto-install dependencies. Install them manually and retry." ;;
        issue_acme) echo "Issuing certificate with acme.sh..." ;;
        install_conf) echo "Rendering site configuration and pages..." ;;
        gen_auth) echo "Generating upload auth file..." ;;
        done) echo "Installation completed." ;;
        next) echo "Recommended next step: tfw info && tfw status" ;;
        uninstall_done) echo "Uninstall completed." ;;
        uninstall_keep_data) echo "Data directory was kept." ;;
        uninstall_keep_certs) echo "Certificate directory was kept." ;;
        upgrade_done) echo "Upgrade completed." ;;
        ask_has_domain) echo "Do you have a bound domain" ;;
        ask_domain) echo "Enter the domain name (optional)" ;;
        ask_access_host) echo "Enter the access host or IP (leave empty to use IP)" ;;
        ask_http_port) echo "Enter the HTTP port (leave empty for 80)" ;;
        ask_https_port) echo "Enter the HTTPS port (leave empty for 443)" ;;
        ask_title) echo "Enter the site title (leave empty for default)" ;;
        ask_user) echo "Enter the Nginx runtime user (leave empty to auto-detect)" ;;
        ask_data) echo "Enter the data directory (leave empty for default)" ;;
        ask_site_base) echo "Enter the site asset base directory (leave empty for default)" ;;
        ask_install_acme) echo "Enable acme.sh automatic certificate issuance" ;;
        ask_acme_webroot) echo "Enter the ACME challenge webroot (leave empty for default)" ;;
        ask_acme_email) echo "Enter the certificate notification email (leave empty to skip)" ;;
        ask_auth_user) echo "Enter the upload username (leave empty for default)" ;;
        ask_auth_password) echo "Enter the upload password (leave empty for random)" ;;
        confirm_auth_password) echo "Confirm the upload password" ;;
        ask_upload_size) echo "Enter the max upload size per file, for example 2g (leave empty for default)" ;;
        bad_domain) echo "Domain must not contain spaces." ;;
        bad_access_host) echo "Access host or IP must not be empty and must not contain spaces." ;;
        bad_port) echo "Port must be an integer between 1 and 65535." ;;
        password_mismatch) echo "The passwords did not match. Try again." ;;
        invalid_yes_no) echo "Enter y or n." ;;
        acme_need_domain) echo "DOMAIN is required when acme.sh is enabled." ;;
        acme_need_http_80) echo "HTTP port must be 80 when acme.sh is enabled." ;;
        acme_skip) echo "Skipping acme.sh issuance. Certificate paths will remain configured but no cert will be issued." ;;
        tls_missing) echo "TLS assets were not found." ;;
        tls_next) echo "To enable HTTPS later, place the certificate files in the site certs directory and rerun install or upgrade." ;;
        http_ready) echo "An HTTP site config was written and is ready to use." ;;
        acme_install) echo "Installing acme.sh..." ;;
        nginx_main_hint) echo "Main nginx.conf template:" ;;
        summary) echo "Installation parameters:" ;;
        mode_default) echo "Using one-click default installation parameters." ;;
        mode_interactive) echo "Entering interactive installation." ;;
        missing_runtime) echo "Existing runtime config was not found, so upgrade or uninstall cannot continue." ;;
        keep_hint) echo "Data and certs are kept by default. Set UNINSTALL_KEEP_DATA=0 or UNINSTALL_KEEP_CERTS=0 to remove them." ;;
        not_set) echo "(not set)" ;;
        yes) echo "yes" ;;
        no) echo "no" ;;
      esac
      ;;
  esac
}

usage() {
  cat <<'EOF'
bash scripts/install.sh [install|upgrade|uninstall]

Environment examples:
  DOMAIN=files.example.com INSTALL_MODE=default LANGUAGE=zh bash scripts/install.sh install
  LANGUAGE=zh bash scripts/install.sh upgrade
  LANGUAGE=zh UNINSTALL_KEEP_DATA=1 UNINSTALL_KEEP_CERTS=1 bash scripts/install.sh uninstall
EOF
}

prompt() {
  local text="$1"
  local default="${2:-}"
  local answer
  if [[ -n "$default" ]]; then
    read -r -p "$text [$default]: " answer
  else
    read -r -p "$text: " answer
  fi
  answer="$(trim_value "$answer")"
  printf '%s' "${answer:-$default}"
}

trim_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

prompt_optional() {
  local text="$1"
  local current="${2:-}"
  local hint="${3:-}"
  local answer

  if [[ -n "$current" ]]; then
    read -r -p "$text [$current]: " answer
  elif [[ -n "$hint" ]]; then
    read -r -p "$text [$hint]: " answer
  else
    read -r -p "$text: " answer
  fi

  answer="$(trim_value "$answer")"
  if [[ -n "$answer" ]]; then
    printf '%s' "$answer"
  else
    printf '%s' "$current"
  fi
}

prompt_required() {
  local text="$1"
  local default="${2:-}"
  local error_key="${3:-bad_domain}"
  local answer

  while true; do
    answer="$(prompt "$text" "$default")"
    if [[ -n "$answer" ]]; then
      printf '%s' "$answer"
      return 0
    fi
    echo "$(msg "$error_key")" >&2
  done
}

prompt_port() {
  local text="$1"
  local default="${2:-}"
  local answer

  while true; do
    answer="$(prompt "$text" "$default")"
    if is_valid_port "$answer"; then
      printf '%s' "$answer"
      return 0
    fi
    echo "$(msg bad_port)" >&2
  done
}

prompt_yes_no() {
  local text="$1"
  local default="${2:-y}"
  local answer normalized

  while true; do
    read -r -p "$text [$default]: " answer
    answer="$(trim_value "$answer")"
    normalized="${answer:-$default}"
    normalized="$(printf '%s' "$normalized" | tr '[:upper:]' '[:lower:]')"

    case "$normalized" in
      y|yes|1|true|on)
        printf '1'
        return 0
        ;;
      n|no|0|false|off)
        printf '0'
        return 0
        ;;
      *)
        echo "$(msg invalid_yes_no)" >&2
        ;;
    esac
  done
}

ensure_interactive_acme_inputs() {
  if [[ "$INSTALL_ACME" != "1" ]]; then
    return 0
  fi

  if [[ -z "$DOMAIN" ]]; then
    echo "$(msg acme_need_domain)" >&2
    DOMAIN="$(prompt_required "$(msg ask_domain)" "" "bad_domain")"
  fi

  if [[ "$HTTP_PORT" != "80" ]]; then
    echo "$(msg acme_need_http_80)" >&2
    HTTP_PORT="80"
  fi
}

prompt_secret() {
  local text="$1"
  local answer
  read -r -s -p "$text: " answer
  printf '\n' >&2
  printf '%s' "$answer"
}

prompt_secret_confirm() {
  local text="$1"
  local confirm_text="$2"
  local answer answer2

  while true; do
    answer="$(prompt_secret "$text")"
    if [[ -z "$answer" ]]; then
      printf '%s' "$answer"
      return 0
    fi

    answer2="$(prompt_secret "$confirm_text")"
    if [[ "$answer" == "$answer2" ]]; then
      printf '%s' "$answer"
      return 0
    fi

    echo "$(msg password_mismatch)" >&2
  done
}

load_existing_runtime_config() {
  if [[ -f "$TFW_CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    . "$TFW_CONFIG_FILE"
    return 0
  fi
  return 1
}

choose_language() {
  if [[ -n "$LANGUAGE" ]]; then
    return 0
  fi

  local answer
  echo "$(msg choose_lang)"
  read -r answer
  case "$answer" in
    1|zh|ZH|cn|CN)
      LANGUAGE="zh"
      ;;
    *)
      LANGUAGE="en"
      ;;
  esac
}

choose_install_mode() {
  if [[ -n "$INSTALL_MODE" ]]; then
    return 0
  fi

  local answer
  echo "$(msg choose_mode)"
  read -r answer
  case "$answer" in
    1|interactive)
      INSTALL_MODE="interactive"
      ;;
    *)
      INSTALL_MODE="default"
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

is_valid_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 ))
}

apply_defaults() {
  SITE_TITLE="${SITE_TITLE:-Temp File Web}"
  TFW_USER="${TFW_USER:-$(detect_nginx_user)}"
  ACCESS_HOST="${ACCESS_HOST:-${DOMAIN:-$IP}}"
  SITE_ID="${SITE_ID:-$(default_site_id)}"
  DATA_DIR="${DATA_DIR:-/srv/tfw/data}"
  UPLOAD_DIR="${DATA_DIR}/uploads"
  SITE_BASE_DIR="${SITE_BASE_DIR:-/etc/tfw/sites}"
  SITE_DIR="${SITE_DIR:-$SITE_BASE_DIR/$SITE_ID}"
  ACME_WEBROOT="${ACME_WEBROOT:-/var/www/_acme-challenge}"
  HTTP_PORT="${HTTP_PORT:-$(default_http_port)}"
  HTTPS_PORT="${HTTPS_PORT:-$(default_https_port)}"
  if [[ "$INSTALL_ACME" == "1" && -n "$DOMAIN" && "$ACME_EMAIL_IS_SET" -eq 0 ]]; then
    ACME_EMAIL="admin@$DOMAIN"
  fi
  AUTH_USER="${AUTH_USER:-uploader}"
  MAX_UPLOAD_SIZE="${MAX_UPLOAD_SIZE:-2g}"
  CONF_FILE="${CONF_FILE:-$CONF_DIR/tfw-$SITE_ID.conf}"
  ACME_CONF_FILE="${ACME_CONF_FILE:-$CONF_DIR/tfw-$SITE_ID-acme.conf}"
  ACCESS_LOG="/var/log/nginx/$SITE_ID.access.log"
  ERROR_LOG="/var/log/nginx/$SITE_ID.error.log"
}

restore_runtime_derived_values() {
  ACCESS_HOST="${ACCESS_HOST:-${DOMAIN:-$IP}}"
  SITE_ID="${SITE_ID:-$(default_site_id)}"
  HTTP_PORT="${HTTP_PORT:-80}"
  HTTPS_PORT="${HTTPS_PORT:-443}"
  CONF_FILE="${CONF_FILE:-$CONF_DIR/tfw-$SITE_ID.conf}"
  ACME_CONF_FILE="${ACME_CONF_FILE:-$CONF_DIR/tfw-$SITE_ID-acme.conf}"
  UPLOAD_DIR="${UPLOAD_DIR:-$DATA_DIR/uploads}"
  SITE_DIR="${SITE_DIR:-$SITE_BASE_DIR/$SITE_ID}"
  ACCESS_LOG="${ACCESS_LOG:-/var/log/nginx/$SITE_ID.access.log}"
  ERROR_LOG="${ERROR_LOG:-/var/log/nginx/$SITE_ID.error.log}"
  SITE_MODE="${SITE_MODE:-https}"
}

collect_interactive_input() {
  echo "$(msg mode_interactive)"

  if [[ -z "$DOMAIN" ]]; then
    if [[ "$(prompt_yes_no "$(msg ask_has_domain)" "n")" == "1" ]]; then
      DOMAIN="$(prompt_required "$(msg ask_domain)" "" "bad_domain")"
    fi
  else
    DOMAIN="$(prompt "$(msg ask_domain)" "${DOMAIN:-}")"
  fi
  ACCESS_HOST="$(prompt_required "$(msg ask_access_host)" "${ACCESS_HOST:-$IP}" "bad_access_host")"
  HTTP_PORT="$(prompt_port "$(msg ask_http_port)" "${HTTP_PORT:-$(default_http_port)}")"
  HTTPS_PORT="$(prompt_port "$(msg ask_https_port)" "${HTTPS_PORT:-$(default_https_port)}")"
  SITE_TITLE="$(prompt "$(msg ask_title)" "${SITE_TITLE:-Temp File Web}")"
  TFW_USER="$(prompt "$(msg ask_user)" "${TFW_USER:-$(detect_nginx_user)}")"
  DATA_DIR="$(prompt "$(msg ask_data)" "${DATA_DIR:-/srv/tfw/data}")"
  SITE_BASE_DIR="$(prompt "$(msg ask_site_base)" "${SITE_BASE_DIR:-/etc/tfw/sites}")"

  if [[ "$INSTALL_ACME_IS_SET" -eq 0 ]]; then
    if [[ "$(prompt_yes_no "$(msg ask_install_acme)" "y")" == "1" ]]; then
      INSTALL_ACME="1"
    else
      INSTALL_ACME="0"
    fi
  fi

  ensure_interactive_acme_inputs

  if [[ "$INSTALL_ACME" == "1" ]]; then
    ACME_WEBROOT="$(prompt "$(msg ask_acme_webroot)" "${ACME_WEBROOT:-/var/www/_acme-challenge}")"
    if [[ "$ACME_EMAIL_IS_SET" -eq 1 ]]; then
      ACME_EMAIL="$(prompt_optional "$(msg ask_acme_email)" "$ACME_EMAIL")"
    else
      ACME_EMAIL="$(prompt_optional "$(msg ask_acme_email)" "" "${DOMAIN:+admin@$DOMAIN}")"
      ACME_EMAIL_IS_SET=1
    fi
  fi
  AUTH_USER="$(prompt "$(msg ask_auth_user)" "${AUTH_USER:-uploader}")"
  AUTH_PASSWORD="$(prompt_secret_confirm "$(msg ask_auth_password)" "$(msg confirm_auth_password)")"
  MAX_UPLOAD_SIZE="$(prompt "$(msg ask_upload_size)" "${MAX_UPLOAD_SIZE:-2g}")"
}

set_default_mode_values() {
  echo "$(msg mode_default)"
  if [[ -z "$ACCESS_HOST" ]]; then
    ACCESS_HOST="${DOMAIN:-$IP}"
  fi
  HTTP_PORT="${HTTP_PORT:-$(default_http_port)}"
  HTTPS_PORT="${HTTPS_PORT:-$(default_https_port)}"
  if [[ -z "$DOMAIN" && "$INSTALL_ACME_IS_SET" -eq 0 ]]; then
    INSTALL_ACME="0"
  fi
}

validate_inputs() {
  [[ "$DOMAIN" != *" "* ]] || {
    echo "$(msg bad_domain)" >&2
    exit 1
  }

  [[ -n "$ACCESS_HOST" && "$ACCESS_HOST" != *" "* ]] || {
    echo "$(msg bad_access_host)" >&2
    exit 1
  }

  is_valid_port "$HTTP_PORT" || {
    echo "$(msg bad_port)" >&2
    exit 1
  }

  is_valid_port "$HTTPS_PORT" || {
    echo "$(msg bad_port)" >&2
    exit 1
  }

  if [[ "$INSTALL_ACME" == "1" && -z "$DOMAIN" ]]; then
    echo "$(msg acme_need_domain)" >&2
    exit 1
  fi

  if [[ "$INSTALL_ACME" == "1" && "$HTTP_PORT" != "80" ]]; then
    echo "$(msg acme_need_http_80)" >&2
    exit 1
  fi
}

backup_if_exists() {
  local file="$1"
  if [[ -e "$file" ]]; then
    cp "$file" "${file}.bak-$(date +%Y%m%d%H%M%S)"
  fi
}

sed_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//&/\\&}"
  value="${value//|/\\|}"
  printf '%s' "$value"
}

js_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\'/\\\'}"
  value="${value//$'\n'/\\n}"
  printf "'%s'" "$value"
}

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

  for dep in nginx curl openssl sed awk grep find tail ls; do
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
      DEBIAN_FRONTEND=noninteractive apt-get install -y nginx curl openssl apache2-utils
      ;;
    dnf)
      dnf install -y nginx curl openssl httpd-tools
      ;;
    yum)
      yum install -y nginx curl openssl httpd-tools
      ;;
    *)
      echo "$(msg deps_fail)" >&2
      exit 1
      ;;
  esac
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

random_password() {
  openssl rand -base64 18 | tr -d '=+/\n' | cut -c1-20
}

render_template() {
  local src="$1"
  local dest="$2"
  local tmp

  tmp="$(mktemp)"
  cp "$src" "$tmp"

  sed -i \
    -e "s|\${DOMAIN}|$(sed_escape "$DOMAIN")|g" \
    -e "s|\${SITE_ID}|$(sed_escape "$SITE_ID")|g" \
    -e "s|\${ACCESS_HOST}|$(sed_escape "$ACCESS_HOST")|g" \
    -e "s|\${ACCESS_BASE}|$(sed_escape "$(build_access_base)")|g" \
    -e "s|\${SITE_TITLE}|$(sed_escape "$SITE_TITLE")|g" \
    -e "s|\${LANG_HTML}|$(sed_escape "$LANG_HTML")|g" \
    -e "s|\${CONF}|$(sed_escape "$CONF_FILE")|g" \
    -e "s|\${SITE_DIR}|$(sed_escape "$SITE_DIR")|g" \
    -e "s|\${AUTH_FILE}|$(sed_escape "$SITE_DIR/file-upload.htpasswd")|g" \
    -e "s|\${DATA_DIR}|$(sed_escape "$DATA_DIR")|g" \
    -e "s|\${UPLOAD_DIR}|$(sed_escape "$UPLOAD_DIR")|g" \
    -e "s|\${BROWSER_HTML}|$(sed_escape "$SITE_DIR/file-browser.html")|g" \
    -e "s|\${UPLOAD_HTML}|$(sed_escape "$SITE_DIR/file-upload.html")|g" \
    -e "s|\${ACCESS_LOG}|$(sed_escape "$ACCESS_LOG")|g" \
    -e "s|\${ERROR_LOG}|$(sed_escape "$ERROR_LOG")|g" \
    -e "s|\${ACME_WEBROOT}|$(sed_escape "$ACME_WEBROOT")|g" \
    -e "s|\${CERT_FILE}|$(sed_escape "$SITE_DIR/certs/fullchain.cer")|g" \
    -e "s|\${KEY_FILE}|$(sed_escape "$SITE_DIR/certs/$SITE_ID.key")|g" \
    -e "s|\${MAX_UPLOAD_SIZE}|$(sed_escape "$MAX_UPLOAD_SIZE")|g" \
    -e "s|\${IP}|$(sed_escape "$IP")|g" \
    -e "s|\${HTTP_PORT}|$(sed_escape "$HTTP_PORT")|g" \
    -e "s|\${HTTPS_PORT}|$(sed_escape "$HTTPS_PORT")|g" \
    -e "s|\${LANGUAGE}|$(sed_escape "$LANGUAGE")|g" \
    -e "s|\${ACME_HOME}|$(sed_escape "$ACME_HOME")|g" \
    -e "s|\${ACME_BIN}|$(sed_escape "$ACME_BIN")|g" \
    "$tmp"

  install -m 0644 "$tmp" "$dest"
  rm -f "$tmp"
}

build_access_base() {
  local scheme port authority
  if [[ "$SITE_MODE" == "https" ]]; then
    scheme="https"
    port="$HTTPS_PORT"
  else
    scheme="http"
    port="$HTTP_PORT"
  fi

  authority="$ACCESS_HOST"
  if [[ "$scheme" == "http" && "$port" != "80" ]]; then
    authority="${authority}:${port}"
  elif [[ "$scheme" == "https" && "$port" != "443" ]]; then
    authority="${authority}:${port}"
  fi

  printf '%s://%s' "$scheme" "$authority"
}

render_nginx_template() {
  local src="$1"
  local dest="$2"
  local common_tmp merged_tmp

  common_tmp="$(mktemp)"
  merged_tmp="$(mktemp)"

  render_template "$NGINX_SITE_COMMON_TEMPLATE" "$common_tmp"
  cp "$src" "$merged_tmp"

  sed -i -e "/\${SITE_COMMON}/r $common_tmp" -e "/\${SITE_COMMON}/d" "$merged_tmp"
  render_template "$merged_tmp" "$dest"

  rm -f "$common_tmp" "$merged_tmp"
}

fill_page_i18n() {
  local file="$1"

  if [[ "$LANGUAGE" == "zh" ]]; then
    LANG_HTML="zh-CN"
    JS_LOCALE='"zh-CN"'
    sed -i \
      -e "s|\${BROWSER_TITLE_SUFFIX}|文件列表|g" \
      -e "s|\${UPLOAD_TITLE_SUFFIX}|上传|g" \
      -e "s|\${BROWSER_EYEBROW_ROOT}|公开文件目录|g" \
      -e "s|\${BROWSER_MAIN_TITLE}|文件列表|g" \
      -e "s|\${BROWSER_LOADING}|正在加载目录数据…|g" \
      -e "s|\${NAV_ROOT}|根目录|g" \
      -e "s|\${NAV_UPLOADS}|上传目录|g" \
      -e "s|\${NAV_UPLOAD}|上传文件|g" \
      -e "s|\${NAV_PARENT}|上一级|g" \
      -e "s|\${FILTER_LABEL}|筛选文件名|g" \
      -e "s|\${FILTER_PLACEHOLDER}|输入关键字，按名称过滤|g" \
      -e "s|\${COUNT_SUFFIX}|个项目|g" \
      -e "s|\${UPLOAD_EYEBROW}|上传入口 /upload|g" \
      -e "s|\${UPLOAD_MAIN_TITLE}|上传到 /uploads/|g" \
      -e "s|\${UPLOAD_SUBTITLE_PREFIX}|这个页面会把文件直接写入 |g" \
      -e "s|\${UPLOAD_SUBTITLE_SUFFIX}|，上传完成后可以在公开目录里直接访问。|g" \
      -e "s|\${UPLOAD_PICK}|选择文件|g" \
      -e "s|\${UPLOAD_START}|开始上传|g" \
      -e "s|\${UPLOAD_OPEN_DIR}|打开上传目录|g" \
      -e "s|\${UPLOAD_HINT}|支持多选；同名文件会被覆盖。当前上限由服务端配置决定。|g" \
      -e "s|\${UPLOAD_DONE_PREFIX}|上传完成后，文件公开地址是 |g" \
      -e "s|\${UPLOAD_DONE_SUFFIX}|。|g" \
      -e "s|\${UPLOAD_FILE_PLACEHOLDER}|文件名|g" \
      -e "s|\${JS_UNKNOWN_SIZE}|$(js_string "未知大小")|g" \
      -e "s|\${JS_UNKNOWN_TIME}|$(js_string "未知时间")|g" \
      -e "s|\${JS_EYEBROW_ROOT}|$(js_string "公开文件目录")|g" \
      -e "s|\${JS_EYEBROW_CHILD}|$(js_string "公开子目录")|g" \
      -e "s|\${JS_TITLE_ROOT}|$(js_string "文件列表")|g" \
      -e "s|\${JS_TITLE_PREFIX}|$(js_string "目录")|g" \
      -e "s|\${JS_SUBTITLE}|$(js_string "页面样式已统一，文件仍然保持原来的公开直链访问方式。")|g" \
      -e "s|\${JS_STATE_LOADING}|$(js_string "正在加载目录数据…")|g" \
      -e "s|\${JS_STATE_NO_MATCH}|$(js_string "没有匹配这个关键字的文件。")|g" \
      -e "s|\${JS_STATE_EMPTY}|$(js_string "当前目录还没有文件。")|g" \
      -e "s|\${JS_STATE_LOAD_FAIL}|$(js_string "目录读取失败")|g" \
      -e "s|\${JS_ITEM_COUNT_SUFFIX}|$(js_string "个项目")|g" \
      -e "s|\${JS_LABEL_DIR}|$(js_string "目录")|g" \
      -e "s|\${JS_LABEL_ENTER}|$(js_string "进入目录")|g" \
      -e "s|\${JS_LABEL_OPEN}|$(js_string "打开文件")|g" \
      -e "s|\${JS_LABEL_COPY}|$(js_string "复制路径")|g" \
      -e "s|\${JS_LABEL_COPIED}|$(js_string "已复制")|g" \
      -e "s|\${JS_LABEL_COPY_FAIL}|$(js_string "复制失败")|g" \
      -e "s|\${JS_LABEL_DOWNLOAD}|$(js_string "下载")|g" \
      -e "s|\${JS_SITE_TITLE}|$(js_string "$SITE_TITLE")|g" \
      -e "s|\${JS_TITLE_SUFFIX}|$(js_string "文件列表")|g" \
      -e "s|\${JS_LOCALE}|$JS_LOCALE|g" \
      -e "s|\${JS_UPLOAD_WAIT}|$(js_string "等待上传")|g" \
      -e "s|\${JS_UPLOAD_PREPARING}|$(js_string "准备上传")|g" \
      -e "s|\${JS_UPLOAD_UPLOADING}|$(js_string "上传中")|g" \
      -e "s|\${JS_UPLOAD_DONE}|$(js_string "上传完成")|g" \
      -e "s|\${JS_UPLOAD_OPEN_FILE}|$(js_string "打开文件")|g" \
      -e "s|\${JS_UPLOAD_FAILED}|$(js_string "上传失败")|g" \
      -e "s|\${JS_UPLOAD_NET_ERROR}|$(js_string "网络错误")|g" \
      -e "s|\${JS_UPLOAD_ABORTED}|$(js_string "上传已取消")|g" \
      "$file"
  else
    LANG_HTML="en"
    JS_LOCALE='"en-US"'
    sed -i \
      -e "s|\${BROWSER_TITLE_SUFFIX}|file index|g" \
      -e "s|\${UPLOAD_TITLE_SUFFIX}|upload|g" \
      -e "s|\${BROWSER_EYEBROW_ROOT}|Public file directory|g" \
      -e "s|\${BROWSER_MAIN_TITLE}|File index|g" \
      -e "s|\${BROWSER_LOADING}|Loading directory data...|g" \
      -e "s|\${NAV_ROOT}|Root|g" \
      -e "s|\${NAV_UPLOADS}|Uploads|g" \
      -e "s|\${NAV_UPLOAD}|Upload|g" \
      -e "s|\${NAV_PARENT}|Parent|g" \
      -e "s|\${FILTER_LABEL}|Filter by name|g" \
      -e "s|\${FILTER_PLACEHOLDER}|Type to filter by file name|g" \
      -e "s|\${COUNT_SUFFIX}|items|g" \
      -e "s|\${UPLOAD_EYEBROW}|Upload entry /upload|g" \
      -e "s|\${UPLOAD_MAIN_TITLE}|Upload to /uploads/|g" \
      -e "s|\${UPLOAD_SUBTITLE_PREFIX}|This page writes files directly to |g" \
      -e "s|\${UPLOAD_SUBTITLE_SUFFIX}| and makes them publicly accessible after upload.|g" \
      -e "s|\${UPLOAD_PICK}|Choose files|g" \
      -e "s|\${UPLOAD_START}|Start upload|g" \
      -e "s|\${UPLOAD_OPEN_DIR}|Open uploads|g" \
      -e "s|\${UPLOAD_HINT}|Multiple files are supported. Existing files with the same name will be overwritten. The limit is controlled by the server config.|g" \
      -e "s|\${UPLOAD_DONE_PREFIX}|After upload, the public file URL is |g" \
      -e "s|\${UPLOAD_DONE_SUFFIX}|.|g" \
      -e "s|\${UPLOAD_FILE_PLACEHOLDER}|filename|g" \
      -e "s|\${JS_UNKNOWN_SIZE}|$(js_string "Unknown size")|g" \
      -e "s|\${JS_UNKNOWN_TIME}|$(js_string "Unknown time")|g" \
      -e "s|\${JS_EYEBROW_ROOT}|$(js_string "Public file directory")|g" \
      -e "s|\${JS_EYEBROW_CHILD}|$(js_string "Public subdirectory")|g" \
      -e "s|\${JS_TITLE_ROOT}|$(js_string "File index")|g" \
      -e "s|\${JS_TITLE_PREFIX}|$(js_string "Directory")|g" \
      -e "s|\${JS_SUBTITLE}|$(js_string "The interface is customized while direct file URLs remain unchanged.")|g" \
      -e "s|\${JS_STATE_LOADING}|$(js_string "Loading directory data...")|g" \
      -e "s|\${JS_STATE_NO_MATCH}|$(js_string "No files matched this keyword.")|g" \
      -e "s|\${JS_STATE_EMPTY}|$(js_string "This directory is empty.")|g" \
      -e "s|\${JS_STATE_LOAD_FAIL}|$(js_string "Failed to load directory")|g" \
      -e "s|\${JS_ITEM_COUNT_SUFFIX}|$(js_string "items")|g" \
      -e "s|\${JS_LABEL_DIR}|$(js_string "Directory")|g" \
      -e "s|\${JS_LABEL_ENTER}|$(js_string "Open folder")|g" \
      -e "s|\${JS_LABEL_OPEN}|$(js_string "Open file")|g" \
      -e "s|\${JS_LABEL_COPY}|$(js_string "Copy path")|g" \
      -e "s|\${JS_LABEL_COPIED}|$(js_string "Copied")|g" \
      -e "s|\${JS_LABEL_COPY_FAIL}|$(js_string "Copy failed")|g" \
      -e "s|\${JS_LABEL_DOWNLOAD}|$(js_string "Download")|g" \
      -e "s|\${JS_SITE_TITLE}|$(js_string "$SITE_TITLE")|g" \
      -e "s|\${JS_TITLE_SUFFIX}|$(js_string "file index")|g" \
      -e "s|\${JS_LOCALE}|$JS_LOCALE|g" \
      -e "s|\${JS_UPLOAD_WAIT}|$(js_string "Waiting")|g" \
      -e "s|\${JS_UPLOAD_PREPARING}|$(js_string "Preparing upload")|g" \
      -e "s|\${JS_UPLOAD_UPLOADING}|$(js_string "Uploading")|g" \
      -e "s|\${JS_UPLOAD_DONE}|$(js_string "Upload complete")|g" \
      -e "s|\${JS_UPLOAD_OPEN_FILE}|$(js_string "Open file")|g" \
      -e "s|\${JS_UPLOAD_FAILED}|$(js_string "Upload failed")|g" \
      -e "s|\${JS_UPLOAD_NET_ERROR}|$(js_string "Network error")|g" \
      -e "s|\${JS_UPLOAD_ABORTED}|$(js_string "Upload aborted")|g" \
      "$file"
  fi
}

render_pages() {
  local browser_tmp upload_tmp

  browser_tmp="$(mktemp)"
  upload_tmp="$(mktemp)"
  cp "$BROWSER_TEMPLATE" "$browser_tmp"
  cp "$UPLOAD_TEMPLATE" "$upload_tmp"

  fill_page_i18n "$browser_tmp"
  fill_page_i18n "$upload_tmp"

  render_template "$browser_tmp" "$SITE_DIR/file-browser.html"
  render_template "$upload_tmp" "$SITE_DIR/file-upload.html"

  rm -f "$browser_tmp" "$upload_tmp"
}

write_auth_file() {
  local password hash old_umask
  echo "$(msg gen_auth)"

  password="${AUTH_PASSWORD:-$(random_password)}"
  hash="$(openssl passwd -apr1 "$password")"
  old_umask="$(umask)"
  umask 077
  printf '%s:%s\n' "$AUTH_USER" "$hash" > "$SITE_DIR/file-upload.htpasswd"
  umask "$old_umask"
  AUTH_PASSWORD="$password"
}

install_acme_sh() {
  [[ "$INSTALL_ACME" == "1" ]] || {
    echo "$(msg acme_skip)"
    return 0
  }

  if [[ -x "$ACME_BIN" ]]; then
    return 0
  fi

  echo "$(msg acme_install)"
  if [[ -n "$ACME_EMAIL" ]]; then
    curl -fsSL https://get.acme.sh | sh -s email="$ACME_EMAIL"
  else
    curl -fsSL https://get.acme.sh | sh
  fi
}

render_acme_challenge_conf() {
  render_template "$NGINX_ACME_TEMPLATE" "$ACME_CONF_FILE"
}

render_site_conf() {
  render_nginx_template "$NGINX_HTTPS_TEMPLATE" "$CONF_FILE"
}

render_http_site_conf() {
  render_nginx_template "$NGINX_HTTP_TEMPLATE" "$CONF_FILE"
}

install_tfw_config() {
  render_template "$TFW_TEMPLATE" "$TFW_CONFIG_FILE"
}

issue_certificate() {
  [[ "$INSTALL_ACME" == "1" ]] || return 0
  [[ -x "$ACME_BIN" ]] || {
    echo "$(msg acme_skip)"
    return 0
  }

  echo "$(msg issue_acme)"
  "$ACME_BIN" --set-default-ca --server letsencrypt
  "$ACME_BIN" --issue -d "$DOMAIN" -w "$ACME_WEBROOT"
  "$ACME_BIN" --install-cert -d "$DOMAIN" \
    --key-file "$SITE_DIR/certs/$SITE_ID.key" \
    --fullchain-file "$SITE_DIR/certs/fullchain.cer" \
    --reloadcmd "nginx -t && (systemctl reload nginx || nginx -s reload)"
}

issue_certificate_if_enabled() {
  if [[ "$INSTALL_ACME" != "1" ]]; then
    return 0
  fi

  if issue_certificate; then
    return 0
  fi

  echo "$(msg acme_skip)"
  return 1
}

have_tls_assets() {
  [[ -f "$SITE_DIR/certs/fullchain.cer" && -f "$SITE_DIR/certs/$SITE_ID.key" ]]
}

set_site_mode() {
  if have_tls_assets; then
    SITE_MODE="https"
  else
    SITE_MODE="http"
  fi
}

print_summary() {
  echo "$(msg summary)"
  echo "  language        : $LANGUAGE"
  echo "  mode            : $INSTALL_MODE"
  echo "  domain          : $DOMAIN"
  echo "  site title      : $SITE_TITLE"
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

reload_nginx_for_acme() {
  [[ "$INSTALL_ACME" == "1" ]] || return 0
  nginx -t
  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart nginx || nginx -s reload
  else
    nginx -s reload
  fi
}

finalize_https_config() {
  render_site_conf
  SITE_MODE="https"
  install_tfw_config
  rm -f "$ACME_CONF_FILE"
  nginx -t
  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart nginx || nginx -s reload
  else
    nginx -s reload
  fi
}

reload_nginx_if_present() {
  if ! command -v nginx >/dev/null 2>&1; then
    return 0
  fi

  nginx -t || return 1
  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart nginx || nginx -s reload
  else
    nginx -s reload
  fi
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

  rm -f "$CONF_FILE" "$ACME_CONF_FILE" "$TFW_CONFIG_FILE" /usr/local/bin/tfw

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
    echo "expected cert dir: $SITE_DIR/certs/"
    echo "$(msg tls_next)"
    exit 0
  fi

  echo "$(msg done)"
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
