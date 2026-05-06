#!/usr/bin/env bash

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
