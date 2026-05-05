# Temp-File-Web

`Temp-File-Web` 是一个可复用的 Nginx 临时文件站点部署模板。它可以在新机器上快速部署公开文件浏览、认证上传、可选 HTTPS 证书、运行配置和日常运维命令。

文档以中文为主。下方所有功能入口都可以点击，页面会滚动到对应章节。

## 功能导航

| 功能 | 说明 | 跳转 |
| --- | --- | --- |
| 快速开始 | 最短路径完成安装 | [查看](#quick-start) |
| 功能总览 | 服务端、安装器、运维能力 | [查看](#features) |
| 访问入口 | 根目录、上传页、JSON 索引、上传目录 | [查看](#routes) |
| 安装方式 | 交互式、一键默认、全参数安装 | [查看](#install) |
| 上传认证 | 登录、会话 Cookie、PUT 上传、轮换密码 | [查看](#upload-auth) |
| HTTPS 证书 | acme.sh 签发、HTTP 回退、手动补证书 | [查看](#https-acme) |
| 运维命令 | `tfw info/status/logs/passwd/restart` | [查看](#tfw-cli) |
| 升级卸载 | `upgrade`、`uninstall` 和保留数据策略 | [查看](#upgrade-uninstall) |
| 目录结构 | 仓库结构和安装后路径 | [查看](#paths) |
| 安全默认值 | TLS、响应头、权限、上传限制 | [查看](#security) |
| 迁移部署 | 复制到新设备部署 | [查看](#migration) |
| 常见问题 | 证书、端口、权限、配置丢失 | [查看](#troubleshooting) |

<a id="quick-start"></a>

## 快速开始

使用域名并自动申请 HTTPS 证书：

```bash
cd /root/Temp-File-Web
DOMAIN=files.example.com INSTALL_MODE=default LANGUAGE=zh bash scripts/install.sh install
```

使用 IP 和 HTTP 端口直接上线：

```bash
cd /root/Temp-File-Web
IP=192.0.2.10 \
ACCESS_HOST=192.0.2.10 \
HTTP_PORT=8080 \
INSTALL_ACME=0 \
INSTALL_MODE=default \
LANGUAGE=zh \
bash scripts/install.sh install
```

安装后先检查：

```bash
tfw info
tfw urls
tfw status
```

如果安装输出里显示了随机上传密码，请及时保存到你的密码管理工具。之后可以用 `tfw passwd` 轮换。

<a id="features"></a>

## 功能总览

服务端功能：

- 自定义公开文件列表页。
- `/upload` 提供上传页面。
- `/_upload_api/` 支持认证后的 `PUT` 上传。
- `/uploads/` 公开展示上传文件。
- `/_listing/` 提供 Nginx JSON autoindex 数据。
- 支持 HTTP 模式，也支持有证书后切换到 HTTPS。
- HTTPS 模式下 HTTP 自动跳转到 HTTPS。
- 内置 ACME challenge 路由。
- 每个站点独立 access/error 日志。

安装器功能：

- 首次安装可选择中文或英文。
- 支持 `install`、`upgrade`、`uninstall`。
- 支持交互式安装和一键默认安装。
- 自动创建站点目录、数据目录、上传目录、认证文件和运行配置。
- 自动渲染 Nginx 配置和前端页面模板。
- 可自动安装依赖和 `acme.sh`。
- 证书申请失败时自动回退到可用 HTTP 站点。

运维功能：

- `tfw info` 查看安装配置和本地文件状态。
- `tfw urls` 查看访问地址。
- `tfw cert` 查看证书路径和 acme.sh 状态。
- `tfw status` 执行 Nginx、HTTP、目录和空间检查。
- `tfw logs` 查看 access/error 日志。
- `tfw passwd` 轮换上传用户名和密码。
- `tfw restart` 检查并重启或重载 Nginx。

<a id="routes"></a>

## 访问入口

安装完成后常用入口如下：

| 路径 | 作用 |
| --- | --- |
| `/` | 自定义文件浏览首页 |
| `/upload` | 上传页面，先登录再上传 |
| `/uploads/` | 上传文件公开目录 |
| `/_listing/` | 根目录 JSON 文件索引 |
| `/_listing/uploads/` | 上传目录 JSON 文件索引 |
| `/.well-known/acme-challenge/` | ACME HTTP challenge |

文件浏览页会读取 `/_listing/` 的 JSON 数据并渲染自定义 UI。文件本身仍然保持 Nginx 静态直链访问。

上传页不会直接暴露 Basic Auth 弹窗。前端先调用 `/_session_login` 校验账号密码，服务端设置会话 Cookie，随后前端向 `/_upload_api/<filename>` 发起 `PUT` 上传。

<a id="install"></a>

## 安装方式

安装脚本入口：

```bash
bash scripts/install.sh [install|upgrade|uninstall]
```

交互式安装：

```bash
cd /root/Temp-File-Web
bash scripts/install.sh install
```

首次运行会选择语言和安装模式。交互式安装会询问域名、访问主机、HTTP/HTTPS 端口、站点标题、Nginx 用户、数据目录、站点资源目录、是否启用 ACME、上传账号、上传密码和上传大小上限。

一键默认安装：

```bash
DOMAIN=files.example.com INSTALL_MODE=default LANGUAGE=zh bash scripts/install.sh install
```

全参数非交互安装：

```bash
DOMAIN=files.example.com \
ACCESS_HOST=files.example.com \
SITE_TITLE="Team Files" \
LANGUAGE=zh \
INSTALL_MODE=default \
TFW_USER=www-data \
DATA_DIR=/srv/team-files/data \
SITE_BASE_DIR=/etc/tfw/sites \
ACME_WEBROOT=/var/www/_acme-challenge \
ACME_EMAIL=admin@example.com \
AUTH_USER=uploader \
AUTH_PASSWORD='strong-password' \
MAX_UPLOAD_SIZE=4g \
bash scripts/install.sh install
```

默认值：

| 变量 | 默认值 |
| --- | --- |
| `SITE_TITLE` | `Temp File Web` |
| `DATA_DIR` | `/srv/tfw/data` |
| `SITE_BASE_DIR` | `/etc/tfw/sites` |
| `ACME_WEBROOT` | `/var/www/_acme-challenge` |
| `AUTH_USER` | `uploader` |
| `MAX_UPLOAD_SIZE` | `2g` |
| 有域名时 `HTTP_PORT` / `HTTPS_PORT` | `80` / `443` |
| 无域名时 `HTTP_PORT` / `HTTPS_PORT` | `8080` / `8443` |

依赖安装：

```bash
AUTO_INSTALL_DEPS=0 bash scripts/install.sh install
```

默认会尝试通过 `apt-get`、`dnf` 或 `yum` 安装缺失依赖。关闭自动依赖安装后，需要你先手动安装 `nginx`、`curl`、`openssl`、`sed`、`awk`、`grep`、`find` 等工具。

<a id="upload-auth"></a>

## 上传认证

安装器会生成 Basic Auth 文件：

```text
/etc/tfw/sites/<site_id>/file-upload.htpasswd
```

上传认证流程：

1. 浏览器打开 `/upload`。
2. 输入上传用户名和密码。
3. 页面请求 `/_session_login`。
4. Nginx 使用 `auth_basic_user_file` 校验密码。
5. 校验通过后设置 `tfw_upload_auth` Cookie。
6. 页面向 `/_upload_api/<filename>` 发起 `PUT` 上传。
7. 文件落到 `${UPLOAD_DIR}`，默认是 `/srv/tfw/data/uploads`。

轮换上传密码：

```bash
tfw passwd
```

指定用户和密码：

```bash
tfw passwd uploader 'new-strong-password'
```

如果不传密码，`tfw passwd` 会生成随机密码。命令会备份旧认证文件，写入新哈希，并做本地格式校验。

<a id="https-acme"></a>

## HTTPS 证书

启用 ACME 的限制：

- `DOMAIN` 必须填写。
- `HTTP_PORT` 必须是 `80`。
- 域名必须解析到当前机器。
- 80 端口必须能被公网访问。

证书流程：

1. 安装 `acme.sh`，如果本机还没有。
2. 写入 ACME challenge 临时 Nginx 配置。
3. 重载 Nginx，让 `/.well-known/acme-challenge/` 可访问。
4. 执行 `acme.sh --issue -d <domain> -w <webroot>`。
5. 把证书安装到站点目录。
6. 渲染正式 HTTPS 配置。
7. 删除 ACME 临时配置并重载 Nginx。

证书落地位置：

```text
/etc/tfw/sites/<site_id>/certs/fullchain.cer
/etc/tfw/sites/<site_id>/certs/<site_id>.key
```

跳过证书直接使用 HTTP：

```bash
INSTALL_ACME=0 ACCESS_HOST=192.0.2.10 HTTP_PORT=8080 bash scripts/install.sh install
```

如果 ACME 失败，安装器不会让整个站点不可用，而是回退到 HTTP 配置。之后手动补齐证书文件，再执行升级即可切回 HTTPS：

```bash
bash scripts/install.sh upgrade
```

<a id="tfw-cli"></a>

## 运维命令

`tfw` 默认读取：

```text
/etc/tfw/tfw.conf
```

临时指定配置：

```bash
TFW_CONFIG=/path/to/tfw.conf tfw info
```

命令列表：

| 命令 | 作用 |
| --- | --- |
| `tfw time` | 显示本地时间、UTC 时间和主机名 |
| `tfw info` | 显示运行配置、目录、证书、日志和 URL |
| `tfw urls` | 显示根页面、上传页、上传目录和 listing API |
| `tfw cert` | 显示 acme.sh、证书和私钥路径 |
| `tfw status` | 检查 Nginx、HTTP 状态码、目录数量和磁盘空间 |
| `tfw test` | 执行 `nginx -t` |
| `tfw ls root` | 列出数据根目录 |
| `tfw ls uploads` | 列出上传目录 |
| `tfw logs access 100` | 查看 access log 后 100 行 |
| `tfw logs error 100` | 查看 error log 后 100 行 |
| `tfw restart` | 检查并重启或重载 Nginx |
| `tfw passwd` | 轮换上传认证密码 |

安装后建议检查：

```bash
tfw info
tfw urls
tfw cert
tfw status
```

<a id="upgrade-uninstall"></a>

## 升级卸载

升级已安装站点：

```bash
bash scripts/install.sh upgrade
```

升级会读取现有 `/etc/tfw/tfw.conf`，重新渲染前端页面、Nginx 配置和 `tfw` 命令。如果已有证书，会写入 HTTPS 配置；如果没有证书，会保持 HTTP 或 ACME challenge 配置。

卸载站点：

```bash
bash scripts/install.sh uninstall
```

默认卸载会删除：

- `/usr/local/bin/tfw`
- Nginx 站点配置
- `/etc/tfw/tfw.conf`
- 安装生成的页面文件
- 上传认证文件

默认会保留：

- 数据目录
- 证书目录

明确删除数据和证书：

```bash
UNINSTALL_KEEP_DATA=0 UNINSTALL_KEEP_CERTS=0 bash scripts/install.sh uninstall
```

`upgrade` 和 `uninstall` 都依赖已有 `/etc/tfw/tfw.conf`。如果运行配置已经丢失，脚本无法可靠判断真实安装路径。

<a id="paths"></a>

## 目录结构

仓库结构：

```text
bin/        tfw 运维命令
nginx/      Nginx 站点模板
scripts/    安装、升级、卸载脚本
templates/  运行配置和 nginx.conf 参考模板
web/        文件浏览页和上传页模板
```

关键文件：

| 文件 | 作用 |
| --- | --- |
| `bin/tfw` | 安装后的运维命令来源 |
| `scripts/install.sh` | 安装、升级、卸载入口 |
| `nginx/site-common.conf.template` | HTTP/HTTPS 共用站点逻辑 |
| `nginx/site-http.conf.template` | HTTP 站点模板 |
| `nginx/site-https.conf.template` | HTTPS 站点模板 |
| `nginx/site-acme.conf.template` | ACME 临时站点模板 |
| `templates/tfw.conf.template` | 运行配置模板 |
| `templates/nginx-main.conf.template` | 主 `nginx.conf` 参考模板 |
| `web/file-browser.html.template` | 文件浏览页模板 |
| `web/file-upload.html.template` | 上传页模板 |

默认安装结果：

| 路径 | 说明 |
| --- | --- |
| `/etc/tfw/tfw.conf` | 运行配置 |
| `/usr/local/bin/tfw` | 运维命令 |
| `/etc/nginx/conf.d/temp-file-web.conf` | Nginx 站点配置 |
| `/etc/nginx/conf.d/temp-file-web-acme.conf` | ACME 临时配置 |
| `/etc/tfw/sites/<site_id>/` | 站点资源目录 |
| `/etc/tfw/sites/<site_id>/file-browser.html` | 文件浏览页面 |
| `/etc/tfw/sites/<site_id>/file-upload.html` | 上传页面 |
| `/etc/tfw/sites/<site_id>/file-upload.htpasswd` | 上传认证文件 |
| `/etc/tfw/sites/<site_id>/certs/` | 证书目录 |
| `/srv/tfw/data` | 数据根目录 |
| `/srv/tfw/data/uploads` | 上传目录 |
| `/var/www/_acme-challenge` | ACME webroot |

<a id="security"></a>

## 安全默认值

默认安全设置：

- HTTPS 模式只启用 `TLSv1.2` 和 `TLSv1.3`。
- 启用 `Strict-Transport-Security`。
- 启用 `X-Content-Type-Options: nosniff`。
- 启用 `X-Frame-Options: SAMEORIGIN`。
- 启用 `Referrer-Policy: strict-origin-when-cross-origin`。
- 启用 `Permissions-Policy` 禁用地理位置、麦克风、摄像头。
- `server_tokens off`。
- 上传认证文件使用 `umask 077` 写入，并设置为 `0640`。
- 证书目录权限为 `0700`。
- 上传写入只开放在 `/_upload_api/`，落盘到 `/uploads/` 对应目录。
- 上传接口只允许 `PUT` 和 `OPTIONS`。
- 文件公开目录只允许 `GET`、`HEAD`、`OPTIONS`。
- ACME challenge 只暴露 `/.well-known/acme-challenge/`。

注意：上传完成后的文件默认公开可访问。如果你需要私有下载，需要调整 Nginx 模板，不应只依赖上传页认证。

<a id="migration"></a>

## 迁移部署

迁移到新机器：

1. 把仓库复制到目标机器。
2. 确认 Nginx、端口、防火墙和域名解析可用。
3. 执行 `bash scripts/install.sh install`。
4. 选择语言和安装模式。
5. 输入访问主机、端口、域名和上传账号。
6. 使用 `tfw info` 和 `tfw status` 验证。

如果迁移已有数据，建议先停止旧站点，再复制数据目录和证书目录。复制完成后执行 `bash scripts/install.sh upgrade` 重新渲染配置。

<a id="troubleshooting"></a>

## 常见问题

ACME 申请失败：

- 检查 `DOMAIN` 是否解析到当前机器。
- 检查 80 端口是否被防火墙或云安全组放行。
- 检查是否设置了非 80 的 `HTTP_PORT`。
- 先用 `INSTALL_ACME=0` 部署 HTTP 站点，再排查证书问题。

上传失败：

- 使用 `tfw status` 检查站点是否可访问。
- 使用 `tfw passwd` 重新生成认证文件。
- 检查 Nginx 运行用户是否能写入上传目录。
- 检查 `MAX_UPLOAD_SIZE` 是否小于上传文件。

页面能打开但目录为空：

- 检查 `/srv/tfw/data` 或自定义 `DATA_DIR` 是否有文件。
- 检查 `/_listing/` 是否返回 JSON。
- 使用 `tfw ls root` 和 `tfw ls uploads` 查看本地目录。

升级或卸载失败：

- 确认 `/etc/tfw/tfw.conf` 仍然存在。
- 如果运行配置丢失，需要根据真实路径手动恢复配置后再执行脚本。
- 不确定真实路径时，不要直接删除数据目录或证书目录。

Nginx 启动失败：

- 执行 `nginx -t` 或 `tfw test` 查看具体错误。
- 检查端口是否冲突。
- 检查证书文件路径是否存在。
- 检查 `/etc/nginx/conf.d/` 里是否有其他站点配置冲突。
