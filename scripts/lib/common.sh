#!/usr/bin/env bash

need_root() {
  [[ "$(id -u)" -eq 0 ]] || {
    echo "need root" >&2
    exit 1
  }
}

trim_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

backup_if_exists() {
  local file="$1"
  if [[ -e "$file" ]]; then
    cp "$file" "${file}.bak-$(date +%Y%m%d%H%M%S)"
  fi
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}
