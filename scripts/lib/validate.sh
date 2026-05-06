#!/usr/bin/env bash

is_valid_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 ))
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

preflight_checks() {
  local errors=0

  # Port conflict detection
  if command -v ss >/dev/null 2>&1; then
    if ss -tlnp "sport = :$HTTP_PORT" 2>/dev/null | grep -q LISTEN; then
      echo "WARNING: Port $HTTP_PORT appears to be in use already" >&2
      errors=$((errors + 1))
    fi
    if [[ "$HTTP_PORT" != "$HTTPS_PORT" ]] && ss -tlnp "sport = :$HTTPS_PORT" 2>/dev/null | grep -q LISTEN; then
      echo "WARNING: Port $HTTPS_PORT appears to be in use already" >&2
      errors=$((errors + 1))
    fi
  elif command -v netstat >/dev/null 2>&1; then
    if netstat -tlnp 2>/dev/null | grep -q ":$HTTP_PORT "; then
      echo "WARNING: Port $HTTP_PORT appears to be in use already" >&2
      errors=$((errors + 1))
    fi
    if [[ "$HTTP_PORT" != "$HTTPS_PORT" ]] && netstat -tlnp 2>/dev/null | grep -q ":$HTTPS_PORT "; then
      echo "WARNING: Port $HTTPS_PORT appears to be in use already" >&2
      errors=$((errors + 1))
    fi
  fi

  # Disk space check
  local parent_dir
  parent_dir="$(dirname "$DATA_DIR")"
  if [[ -d "$parent_dir" ]]; then
    local available_kb
    available_kb="$(df "$parent_dir" 2>/dev/null | awk 'NR==2{print $4}')"
    if [[ -n "$available_kb" && "$available_kb" -lt 1048576 ]]; then
      echo "WARNING: Low disk space on $parent_dir ($((available_kb / 1024)) MB available)" >&2
      errors=$((errors + 1))
    fi
  fi

  # Nginx user existence
  if [[ -n "$TFW_USER" ]] && ! id -u "$TFW_USER" >/dev/null 2>&1; then
    echo "WARNING: Nginx runtime user '$TFW_USER' does not exist" >&2
    errors=$((errors + 1))
  fi

  # DNS resolution check (if ACME enabled)
  if [[ "$INSTALL_ACME" == "1" && -n "$DOMAIN" ]]; then
    local resolved=""
    if command -v host >/dev/null 2>&1; then
      resolved="$(host "$DOMAIN" 2>/dev/null | head -1 || true)"
    elif command -v dig >/dev/null 2>&1; then
      resolved="$(dig +short "$DOMAIN" 2>/dev/null || true)"
    elif command -v nslookup >/dev/null 2>&1; then
      resolved="$(nslookup "$DOMAIN" 2>/dev/null 2>&1 || true)"
    fi
    if [[ -z "$resolved" ]]; then
      echo "WARNING: Domain '$DOMAIN' could not be resolved. ACME may fail." >&2
    fi
  fi

  # Template file integrity
  local required_templates=(
    "$NGINX_HTTPS_TEMPLATE" "$NGINX_HTTP_TEMPLATE" "$NGINX_ACME_TEMPLATE"
    "$NGINX_SITE_COMMON_TEMPLATE" "$AUTH_MAP_TEMPLATE"
    "$BROWSER_TEMPLATE" "$UPLOAD_TEMPLATE" "$SHARED_STYLES_TEMPLATE"
    "$TFW_TEMPLATE" "$TFW_BIN_SRC"
  )
  for tmpl in "${required_templates[@]}"; do
    if [[ ! -f "$tmpl" ]]; then
      echo "ERROR: Required template not found: $tmpl" >&2
      errors=$((errors + 1))
    fi
  done

  if [[ "$errors" -gt 0 ]]; then
    echo "Pre-flight check found $errors issue(s)." >&2
    echo "Set SKIP_PREFLIGHT=1 to bypass this check." >&2
    [[ "${SKIP_PREFLIGHT:-0}" == "1" ]] && return 0
    exit 1
  fi
}
