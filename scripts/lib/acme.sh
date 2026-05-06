#!/usr/bin/env bash

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

render_auth_map_conf() {
  render_template "$AUTH_MAP_TEMPLATE" "$AUTH_MAP_FILE"
}

install_tfw_config() {
  render_template "$TFW_TEMPLATE" "$TFW_CONFIG_FILE"
  render_auth_map_conf
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

reload_nginx_for_acme() {
  [[ "$INSTALL_ACME" == "1" ]] || return 0
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
