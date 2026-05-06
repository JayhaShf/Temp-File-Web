#!/usr/bin/env bash

random_password() {
  openssl rand -base64 18 | tr -d '=+/\n' | cut -c1-20
}

random_session_token() {
  openssl rand -hex 24
}

set_auth_file_permissions() {
  local owner_group

  chmod 0640 "$SITE_DIR/file-upload.htpasswd"
  if id -u "$TFW_USER" >/dev/null 2>&1; then
    owner_group="$(id -gn "$TFW_USER")"
    chown root:"$owner_group" "$SITE_DIR/file-upload.htpasswd"
  else
    chown root:root "$SITE_DIR/file-upload.htpasswd"
  fi
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
  set_auth_file_permissions
  AUTH_PASSWORD="$password"
}
