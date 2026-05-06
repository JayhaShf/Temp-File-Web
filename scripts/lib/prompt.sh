#!/usr/bin/env bash

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
