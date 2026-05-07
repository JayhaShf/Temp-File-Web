#!/usr/bin/env bash

js_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\'/\\\'}"
  value="${value//$'\n'/\\n}"
  printf "'%s'" "$value"
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

build_auth_cookie_flags() {
  local flags max_age
  max_age="${AUTH_SESSION_MAX_AGE:-86400}"
  flags="Path=/; HttpOnly; SameSite=Strict; Max-Age=${max_age}"
  if [[ "$SITE_MODE" == "https" ]]; then
    flags="${flags}; Secure"
  fi
  printf '%s' "$flags"
}

current_access_port() {
  if [[ "$SITE_MODE" == "https" ]]; then
    printf '%s\n' "$HTTPS_PORT"
  else
    printf '%s\n' "$HTTP_PORT"
  fi
}

render_template() {
  local src="$1" dest="$2"

  export DOMAIN SITE_ID ACCESS_HOST SITE_TITLE PROJECT_URL LANG_HTML
  export DATA_DIR UPLOAD_DIR ACCESS_LOG ERROR_LOG
  export ACME_WEBROOT MAX_UPLOAD_SIZE IP HTTP_PORT HTTPS_PORT LANGUAGE
  export ACME_HOME ACME_BIN SITE_DIR AUTH_SESSION_TOKEN AUTH_SESSION_MAX_AGE
  export INSTALL_ACME SITE_MODE TFW_PROJECT_DIR
  export ACCESS_BASE="$(build_access_base)"
  export AUTH_COOKIE_FLAGS="$(build_auth_cookie_flags)"
  export AUTH_COOKIE_NAME="tfw_upload_auth"
  export AUTH_FILE="${AUTH_FILE:-$SITE_DIR/file-upload.htpasswd}"
  export BROWSER_HTML="${BROWSER_HTML:-$SITE_DIR/file-browser.html}"
  export UPLOAD_HTML="${UPLOAD_HTML:-$SITE_DIR/file-upload.html}"
  export CERT_FILE="${CERT_FILE:-$SITE_DIR/certs/fullchain.cer}"
  export KEY_FILE="${KEY_FILE:-$SITE_DIR/certs/$SITE_ID.key}"
  export CONF="$CONF_FILE"

  envsubst '
    $DOMAIN $SITE_ID $ACCESS_HOST $ACCESS_BASE $SITE_TITLE $PROJECT_URL
    $LANG_HTML $CONF $SITE_DIR $AUTH_FILE $AUTH_SESSION_TOKEN
    $AUTH_COOKIE_NAME $AUTH_COOKIE_FLAGS $DATA_DIR $UPLOAD_DIR
    $BROWSER_HTML $UPLOAD_HTML $ACCESS_LOG $ERROR_LOG
    $ACME_WEBROOT $CERT_FILE $KEY_FILE $MAX_UPLOAD_SIZE
    $IP $HTTP_PORT $HTTPS_PORT $LANGUAGE $ACME_HOME $ACME_BIN
    $AUTH_SESSION_MAX_AGE $INSTALL_ACME $SITE_MODE $TFW_PROJECT_DIR
  ' < "$src" > "$dest"
}

render_nginx_template() {
  local src="$1" dest="$2"
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
      -e "s|\${NAV_UPLOAD}|上传文件|g" \
      -e "s|\${NAV_PARENT}|上一级|g" \
      -e "s|\${NAV_PROJECT}|项目地址|g" \
      -e "s|\${MANAGE_LOGIN}|登录管理|g" \
      -e "s|\${MANAGE_LOGOUT}|退出管理|g" \
      -e "s|\${FILTER_LABEL}|筛选文件名|g" \
      -e "s|\${FILTER_PLACEHOLDER}|输入关键字，按名称过滤|g" \
      -e "s|\${COUNT_SUFFIX}|个项目|g" \
      -e "s|\${UPLOAD_EYEBROW}|上传入口|g" \
      -e "s|\${UPLOAD_MAIN_TITLE}|上传文件|g" \
      -e "s|\${UPLOAD_SUBTITLE_PREFIX}|文件将写入 |g" \
      -e "s|\${UPLOAD_SUBTITLE_SUFFIX}|，上传完成后可在根目录直接访问。|g" \
      -e "s|\${UPLOAD_PICK}|选择文件|g" \
      -e "s|\${UPLOAD_START}|开始上传|g" \
      -e "s|\${UPLOAD_OPEN_DIR}|打开根目录|g" \
      -e "s|\${UPLOAD_HINT}|支持多选；同名文件会被覆盖。当前上限由服务端配置决定。|g" \
      -e "s|\${UPLOAD_DONE_PREFIX}|上传完成后，文件公开地址是 |g" \
      -e "s|\${UPLOAD_DONE_SUFFIX}|。|g" \
      -e "s|\${UPLOAD_FILE_PLACEHOLDER}|文件名|g" \
      -e "s|\${AUTH_USER_LABEL}|用户名|g" \
      -e "s|\${AUTH_PASSWORD_LABEL}|密码|g" \
      -e "s|\${AUTH_SUBMIT}|登录并进入上传|g" \
      -e "s|\${AUTH_LOGOUT}|退出登录|g" \
      -e "s|\${AUTH_OK}|已登录|g" \
      -e "s|\${AUTH_HINT}|登录后可继续保持当前页面风格进行上传。认证信息仅用于当前页面会话。|g" \
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
      -e "s|\${JS_LABEL_DELETE}|$(js_string "删除")|g" \
      -e "s|\${JS_LABEL_DELETING}|$(js_string "正在删除")|g" \
      -e "s|\${JS_LABEL_DELETED}|$(js_string "已删除")|g" \
      -e "s|\${JS_LABEL_DELETE_FAILED}|$(js_string "删除失败")|g" \
      -e "s|\${JS_LABEL_DELETE_CONFIRM}|$(js_string "确定删除 {name} 吗？此操作不可撤销。")|g" \
      -e "s|\${JS_MANAGE_READY_TITLE}|$(js_string "管理模式已开启")|g" \
      -e "s|\${JS_MANAGE_READY_TEXT}|$(js_string "当前上传会话有效，可以删除根目录中的文件。")|g" \
      -e "s|\${JS_MANAGE_LOCKED_TITLE}|$(js_string "当前为只读浏览")|g" \
      -e "s|\${JS_MANAGE_LOCKED_TEXT}|$(js_string "登录后会回到此目录，并显示文件删除操作。")|g" \
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
      -e "s|\${JS_AUTH_REQUIRED}|$(js_string "请输入用户名和密码")|g" \
      -e "s|\${JS_AUTH_FAILED}|$(js_string "认证失败，请检查用户名和密码")|g" \
      -e "s|\${JS_AUTH_NETWORK}|$(js_string "认证请求失败")|g" \
      -e "s|\${JS_AUTH_CHECKING}|$(js_string "正在验证")|g" \
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
      -e "s|\${NAV_UPLOAD}|Upload|g" \
      -e "s|\${NAV_PARENT}|Parent|g" \
      -e "s|\${NAV_PROJECT}|Project|g" \
      -e "s|\${MANAGE_LOGIN}|Sign in to manage|g" \
      -e "s|\${MANAGE_LOGOUT}|Sign out|g" \
      -e "s|\${FILTER_LABEL}|Filter by name|g" \
      -e "s|\${FILTER_PLACEHOLDER}|Type to filter by file name|g" \
      -e "s|\${COUNT_SUFFIX}|items|g" \
      -e "s|\${UPLOAD_EYEBROW}|Upload entry|g" \
      -e "s|\${UPLOAD_MAIN_TITLE}|Upload files|g" \
      -e "s|\${UPLOAD_SUBTITLE_PREFIX}|Files are written to |g" \
      -e "s|\${UPLOAD_SUBTITLE_SUFFIX}| and are publicly accessible from the root directory after upload.|g" \
      -e "s|\${UPLOAD_PICK}|Choose files|g" \
      -e "s|\${UPLOAD_START}|Start upload|g" \
      -e "s|\${UPLOAD_OPEN_DIR}|Open root|g" \
      -e "s|\${UPLOAD_HINT}|Multiple files are supported. Existing files with the same name will be overwritten. The limit is controlled by the server config.|g" \
      -e "s|\${UPLOAD_DONE_PREFIX}|After upload, the public file URL is |g" \
      -e "s|\${UPLOAD_DONE_SUFFIX}|.|g" \
      -e "s|\${UPLOAD_FILE_PLACEHOLDER}|filename|g" \
      -e "s|\${AUTH_USER_LABEL}|Username|g" \
      -e "s|\${AUTH_PASSWORD_LABEL}|Password|g" \
      -e "s|\${AUTH_SUBMIT}|Sign in to upload|g" \
      -e "s|\${AUTH_LOGOUT}|Sign out|g" \
      -e "s|\${AUTH_OK}|Signed in|g" \
      -e "s|\${AUTH_HINT}|After sign-in, the page keeps the same interface style and continues directly into upload mode.|g" \
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
      -e "s|\${JS_LABEL_DELETE}|$(js_string "Delete")|g" \
      -e "s|\${JS_LABEL_DELETING}|$(js_string "Deleting")|g" \
      -e "s|\${JS_LABEL_DELETED}|$(js_string "Deleted")|g" \
      -e "s|\${JS_LABEL_DELETE_FAILED}|$(js_string "Delete failed")|g" \
      -e "s|\${JS_LABEL_DELETE_CONFIRM}|$(js_string "Delete {name}? This cannot be undone.")|g" \
      -e "s|\${JS_MANAGE_READY_TITLE}|$(js_string "Manage mode is active")|g" \
      -e "s|\${JS_MANAGE_READY_TEXT}|$(js_string "Your upload session is valid. You can delete files in the root directory.")|g" \
      -e "s|\${JS_MANAGE_LOCKED_TITLE}|$(js_string "Read-only browsing")|g" \
      -e "s|\${JS_MANAGE_LOCKED_TEXT}|$(js_string "Sign in to return here with delete actions enabled.")|g" \
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
      -e "s|\${JS_AUTH_REQUIRED}|$(js_string "Enter username and password")|g" \
      -e "s|\${JS_AUTH_FAILED}|$(js_string "Authentication failed. Check your username and password.")|g" \
      -e "s|\${JS_AUTH_NETWORK}|$(js_string "Authentication request failed")|g" \
      -e "s|\${JS_AUTH_CHECKING}|$(js_string "Checking")|g" \
      "$file"
  fi
}

render_pages() {
  local browser_tmp upload_tmp shared_tmp

  browser_tmp="$(mktemp)"
  upload_tmp="$(mktemp)"
  shared_tmp="$(mktemp)"

  cp "$BROWSER_TEMPLATE" "$browser_tmp"
  cp "$UPLOAD_TEMPLATE" "$upload_tmp"

  cp "$SHARED_STYLES_TEMPLATE" "$shared_tmp"
  for target in "$browser_tmp" "$upload_tmp"; do
    sed -i -e "/\${SHARED_STYLES}/r $shared_tmp" -e "/\${SHARED_STYLES}/d" "$target"
  done

  fill_page_i18n "$browser_tmp"
  fill_page_i18n "$upload_tmp"

  render_template "$browser_tmp" "$SITE_DIR/file-browser.html"
  render_template "$upload_tmp" "$SITE_DIR/file-upload.html"

  rm -f "$browser_tmp" "$upload_tmp" "$shared_tmp"
}
