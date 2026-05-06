#!/usr/bin/env bash
# Smoke test for Temp-File-Web installation.
# Usage: bash scripts/smoke-test.sh [/etc/tfw/tfw.conf]

set -euo pipefail

CONFIG_FILE="${1:-/etc/tfw/tfw.conf}"
FAILED=0

pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; FAILED=$((FAILED + 1)); }

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
else
  echo "FAIL  Config not found at $CONFIG_FILE"
  exit 1
fi

# Derive base URL
url_scheme="https"
url_port="${HTTPS_PORT:-443}"
[[ "${SITE_MODE:-https}" == "http" ]] && url_scheme="http" && url_port="${HTTP_PORT:-80}"

authority="${ACCESS_HOST:-127.0.0.1}"
if { [[ "$url_scheme" == "http" ]] && [[ "$url_port" != "80" ]]; } || \
   { [[ "$url_scheme" == "https" ]] && [[ "$url_port" != "443" ]]; }; then
  authority="${authority}:${url_port}"
fi

BASE="${url_scheme}://${authority}"

curl_flags="-sk"
resolve_flag=""
if [[ -n "${IP:-}" && "$IP" != "127.0.0.1" ]]; then
  # shellcheck disable=SC2154
  resolve_flag="--resolve ${ACCESS_HOST}:${url_port}:${IP}"
fi

echo "Smoke testing: $BASE"
echo "---"

# 1. Root page
code=$(curl $curl_flags $resolve_flag -o /dev/null -w '%{http_code}' "$BASE/" 2>/dev/null || echo "ERR")
[[ "$code" == "200" ]] && pass "Root page / (got $code)" || fail "Root page / (got $code)"

# 2. Upload page
code=$(curl $curl_flags $resolve_flag -o /dev/null -w '%{http_code}' "$BASE/upload" 2>/dev/null || echo "ERR")
[[ "$code" == "200" ]] && pass "Upload page /upload (got $code)" || fail "Upload page /upload (got $code)"

# 3. Listing API
code=$(curl $curl_flags $resolve_flag -o /dev/null -w '%{http_code}' "$BASE/_listing/" 2>/dev/null || echo "ERR")
[[ "$code" == "200" ]] && pass "Listing API /_listing/ (got $code)" || fail "Listing API /_listing/ (got $code)"

# 5. Session status (expect 401 when not logged in)
code=$(curl $curl_flags $resolve_flag -o /dev/null -w '%{http_code}' "$BASE/_session_status" 2>/dev/null || echo "ERR")
[[ "$code" == "401" ]] && pass "Session status unauthenticated (got $code)" || fail "Session status unauthenticated (got $code)"

# 6. Upload API OPTIONS (expect 401 when not logged in due to auth_request)
code=$(curl $curl_flags $resolve_flag -o /dev/null -w '%{http_code}' -X PUT "$BASE/_upload_api/.tfw-smoke-probe" 2>/dev/null || echo "ERR")
[[ "$code" == "401" || "$code" == "411" ]] && pass "Upload API unauthenticated PUT (got $code)" || fail "Upload API unauthenticated PUT (got $code)"

# 7. Session login with invalid password (expect 401)
auth_user="$(awk -F: 'NR==1{print $1; exit}' "${AUTH_FILE:-/dev/null}" 2>/dev/null || true)"
if [[ -n "$auth_user" ]]; then
  code=$(curl $curl_flags $resolve_flag -o /dev/null -w '%{http_code}' -u "${auth_user}:__tfw_invalid__" "$BASE/_session_login" 2>/dev/null || echo "ERR")
  [[ "$code" == "401" ]] && pass "Session login invalid (got $code)" || fail "Session login invalid (got $code)"
else
  echo "SKIP  Session login (no auth user found)"
fi

# 8. Nginx config test
if command -v nginx >/dev/null 2>&1 && nginx -t >/dev/null 2>&1; then
  pass "Nginx config test"
else
  fail "Nginx config test"
fi

# 9. Nginx process
if pgrep -x nginx >/dev/null 2>&1; then
  pass "Nginx process running"
else
  fail "Nginx process not running"
fi

# 10. Data directories exist
for dir in "${DATA_DIR:-/srv/tfw/data}"; do
  if [[ -d "$dir" ]]; then
    pass "Directory exists: $dir"
  else
    fail "Directory missing: $dir"
  fi
done

echo "---"
echo "Result: $FAILED failure(s)"

exit "$FAILED"
