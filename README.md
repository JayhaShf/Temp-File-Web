# Temp-File-Web

`Temp-File-Web` 是一个可复用的 Nginx 临时文件站点部署模板。一条命令即可在新机器上部署公开文件浏览、认证上传、可选 HTTPS 证书和日常运维工具。

文档以中文为主。

## 功能导航

| 功能 | 说明 |
| --- | --- |
| 快速开始 | 最短路径完成安装 |
| 功能总览 | 服务端、安装器、运维能力 |
| 访问入口 | 根目录、上传页、JSON 索引 |
| 安装方式 | 交互式、一键默认、全参数安装 |
| 上传认证 | 登录、会话 Cookie、上传、删除、轮换密码 |
| HTTPS 证书 | acme.sh 签发、HTTP 回退、手动补证书 |
| 运维命令 | 全部 `tfw` 子命令 |
| 升级 / 更新 / 卸载 | `tfw update`、`tfw uninstall`、`install.sh upgrade` |
| Docker 部署 | Dockerfile + docker-compose |
| 目录结构 | 仓库结构和安装后路径 |
| 安全默认值 | TLS、响应头、权限、上传限制 |
| 迁移部署 | 复制到新设备部署 |
| 常见问题 | 证书、端口、权限、配置丢失 |

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
IP=192.0.2.10 ACCESS_HOST=192.0.2.10 HTTP_PORT=8080 INSTALL_ACME=0 INSTALL_MODE=default LANGUAGE=zh bash scripts/install.sh install  # 192.0.2.10 为示例 IP，请替换为实际地址
```

安装后检查：

```bash
tfw info
tfw urls
tfw status
```

安装输出中会显示随机上传密码，请及时保存。之后可用 `tfw passwd` 轮换。

<a id="features"></a>

## 功能总览

**服务端功能：**

- 自定义文件浏览首页，暗色主题，响应式布局。
- `/upload` 页面内登录上传，支持多文件、进度条。
- `/_upload_api/` 支持认证后的 `PUT` 上传和 `DELETE` 删除。
- 上传文件默认落到根目录，登录后可在首页管理删除。
- `/_listing/` 提供 Nginx JSON autoindex 数据供前端消费。
- 支持 HTTP / HTTPS 双模式，HTTPS 模式下 HTTP 自动跳转。
- 内置 ACME challenge 路由。
- 每个站点独立 access / error 日志。

**安装器功能：**

- 安装前预检：端口冲突、磁盘空间、Nginx 用户存在性、DNS 解析、模板完整性。
- 首次安装可选择中文或英文，交互式或一键默认。
- 支持 `install`、`upgrade`、`uninstall`。
- 自动创建目录结构、渲染 Nginx 配置和前端页面。
- 自动安装系统依赖和 `acme.sh`。
- ACME 证书申请失败自动回退到 HTTP 站点。

**运维功能（`tfw` 命令）：**

| 命令 | 作用 |
| --- | --- |
| `tfw time` | 显示本地时间、UTC 时间和主机名 |
| `tfw info` | 显示运行配置、路径、文件状态和 URL |
| `tfw urls` | 显示所有公开访问地址 |
| `tfw cert` | 查看、设置、验证和重载证书路径配置 |
| `tfw status` | Nginx 进程、HTTP 状态码、目录数量、磁盘空间 |
| `tfw health` | `tfw status` 的别名 |
| `tfw auth [user] [pass]` | 检查认证端点与密码校验 |
| `tfw config` | 输出当前运行配置内容 |
| `tfw doctor` | 检查所有关键路径和权限 |
| `tfw test` | 执行 `nginx -t` |
| `tfw ls [root\|/path]` | 列出目录内容 |
| `tfw logs [access\|error\|all] [行数]` | 查看日志 |
| `tfw restart` | 检查并重载 Nginx |
| `tfw passwd [user] [pass]` | 轮换上传认证密码 |
| `tfw session [show\|rotate]` | 查看或轮换会话 token |
| `tfw update [--check\|--pull]` | 升级 / 检查更新 / 拉取最新代码升级 |
| `tfw uninstall` | 交互式卸载站点 |

<a id="routes"></a>

## 访问入口

| 路径 | 作用 |
| --- | --- |
| `/` | 自定义文件浏览首页，登录后显示管理面板和删除操作 |
| `/upload` | 上传页面，支持 `next` 参数，登录后可跳回来源页面 |
| `/_listing/` | 根目录 JSON 文件索引 |
| `/.well-known/acme-challenge/` | ACME HTTP challenge |

文件浏览页通过 `/_listing/` JSON 渲染自定义 UI，文件本体保持 Nginx 静态直连。

上传认证采用页面内表单 + 会话 Cookie 机制：前端调用 `/_session_login` 校验账号密码，服务端设置 `tfw_upload_auth` Cookie（Max-Age 24 小时，HttpOnly，SameSite Strict），随后前端向 `/_upload_api/<filename>` 发起 `PUT` 上传。

打开首页 `/` 时页面检查会话状态：已登录则显示管理面板和删除按钮，未登录则显示只读浏览和登录入口。删除通过 `/_upload_api/<filename>` 的 `DELETE` 请求完成。

<a id="install"></a>

## 安装方式

安装脚本入口：

```bash
bash scripts/install.sh [install|upgrade|uninstall]
```

**交互式安装：**

```bash
cd /root/Temp-File-Web
bash scripts/install.sh install
```

选择语言和安装模式后，依次询问域名、访问主机、端口、站点标题、Nginx 用户、数据目录、ACME 开关、上传账号密码和上传大小上限。

**一键默认安装：**

```bash
DOMAIN=files.example.com INSTALL_MODE=default LANGUAGE=zh bash scripts/install.sh install
```

**全参数非交互安装：**

```bash
DOMAIN=files.example.com \
ACCESS_HOST=files.example.com \
SITE_TITLE="Team Files" \
LANGUAGE=zh \
INSTALL_MODE=default \
TFW_USER=www-data \
DATA_DIR=/srv/team-files/data \
ACME_WEBROOT=/var/www/_acme-challenge \
ACME_EMAIL=admin@example.com \
AUTH_USER=uploader \
AUTH_PASSWORD='strong-password' \
MAX_UPLOAD_SIZE=4g \
UPLOAD_DIR=/srv/team-files/data \
bash scripts/install.sh install
```

**安装预检：**

安装前自动检查端口冲突、磁盘空间、Nginx 用户、DNS 解析和模板完整性。发现问题会中止安装。可通过 `SKIP_PREFLIGHT=1` 跳过。

**默认值：**

| 变量 | 默认值 |
| --- | --- |
| `SITE_TITLE` | `Temp File Web` |
| `PROJECT_URL` | `https://github.com/JayhaShf/Temp-File-Web` |
| `DATA_DIR` | `/srv/tfw/data` |
| `UPLOAD_DIR` | 同 `DATA_DIR`（上传到根目录） |
| `SITE_BASE_DIR` | `/etc/tfw/sites` |
| `ACME_WEBROOT` | `/var/www/_acme-challenge` |
| `AUTH_USER` | `uploader` |
| `AUTH_SESSION_MAX_AGE` | `86400`（24 小时） |
| `MAX_UPLOAD_SIZE` | `2g` |
| 有域名 `HTTP_PORT` / `HTTPS_PORT` | `80` / `443` |
| 无域名 `HTTP_PORT` / `HTTPS_PORT` | `8080` / `8443` |

**依赖安装：**

```bash
AUTO_INSTALL_DEPS=0 bash scripts/install.sh install
```

默认通过 `apt-get`、`dnf` 或 `yum` 自动安装 `nginx`、`curl`、`openssl`、`gettext-base` 等依赖。关闭后需自行安装。

<a id="upload-auth"></a>

## 上传认证

认证文件位置：

```text
/etc/tfw/sites/<site_id>/file-upload.htpasswd
```

**上传流程：**

1. 打开 `/upload`，输入上传用户名和密码。
2. 前端调用 `/_session_login`，通过 `Authorization: Basic` 头发送凭证。
3. Nginx `auth_request` 内部校验 `htpasswd` 文件。
4. 校验通过后设置 `tfw_upload_auth` Cookie，有效期 24 小时。
5. 页面向 `/_upload_api/<filename>` 发起 `PUT` 上传，文件落到 `${UPLOAD_DIR}`。

**删除流程：**

1. 打开首页 `/`，点击"登录管理"进入 `/upload?next=/`。
2. 登录后自动回到首页，文件项显示删除按钮。
3. 点击删除并确认，前端向 `/_upload_api/<filename>` 发起 `DELETE`。

上传和删除只对 `${UPLOAD_DIR}` 根目录中的文件生效，不会在子目录上显示操作按钮。

**轮换密码：**

```bash
tfw passwd                          # 交互式随机生成
tfw passwd uploader 'new-pass'      # 指定用户和密码
```

**轮换会话 token：**

```bash
tfw session rotate                  # 重新生成 token，所有已登录立即失效
tfw session show                    # 查看当前 token
```

<a id="https-acme"></a>

## HTTPS 证书

启用条件：`DOMAIN` 已填写、`HTTP_PORT` 为 `80`、域名解析到当前机器、80 端口公网可达。

流程：安装 acme.sh → 写入 ACME challenge 配置 → 签发证书 → 安装到站点目录 → 写入 HTTPS 配置 → 删除 ACME 临时配置。

证书落地：

```text
/etc/tfw/sites/<site_id>/certs/fullchain.cer
/etc/tfw/sites/<site_id>/certs/<site_id>.key
```

跳过证书直接用 HTTP：

```bash
INSTALL_ACME=0 ACCESS_HOST=192.0.2.10 HTTP_PORT=8080 bash scripts/install.sh install  # 替换为实际 IP
```

ACME 失败自动回退到 HTTP，后续手动补齐证书再 upgrade 切回 HTTPS：

```bash
bash scripts/install.sh upgrade
```

证书路径也可以在安装后用 `tfw cert` 管理：

```bash
tfw cert                                   # 查看当前证书配置
tfw cert set --cert /path/fullchain.cer \
             --key /path/private.key      # 同时更新证书和私钥
tfw cert validate                          # 校验证书路径和 nginx 配置
tfw cert reload                            # 校验后重载 nginx
```

`tfw cert set` 会先更新 `/etc/tfw/tfw.conf` 和 Nginx 站点配置，再执行 `nginx -t`；如果校验失败，会自动回滚到更新前的配置。

<a id="tfw-cli"></a>

## 运维命令

`tfw` 默认读取 `/etc/tfw/tfw.conf`。可临时指定：

```bash
TFW_CONFIG=/path/to/tfw.conf tfw info
```

安装后建议执行：

```bash
tfw info && tfw urls && tfw cert && tfw status
```

<a id="upgrade-uninstall"></a>

## 升级 / 更新 / 卸载

**从项目目录升级：**

```bash
bash scripts/install.sh upgrade
```

升级读取现有运行配置，用新版模板重新渲染页面、Nginx 配置和 `tfw` 命令。已有证书则写入 HTTPS，否则保持 HTTP。

**tfw 自更新：**

```bash
tfw update                  # 用当前源码执行升级
tfw update --check          # 检查远程更新
tfw update --pull           # git pull 最新代码后升级
```

`tfw update --pull` 在检测到本地修改时会给出警告并要求确认，避免覆盖未提交的改动。

**交互式卸载：**

```bash
tfw uninstall
```

根据提示选择：是否继续 → 是否保留数据目录 → 是否保留证书目录。默认保留数据和证书。也可直接调用：

```bash
UNINSTALL_KEEP_DATA=0 UNINSTALL_KEEP_CERTS=0 bash scripts/install.sh uninstall
```

<a id="docker"></a>

## Docker 部署

```bash
docker compose up -d
```

或单独构建：

```bash
docker build -t tfw .
docker run -d -p 80:80 -p 443:443 \
  -e DOMAIN=files.example.com \
  -e LANGUAGE=zh \
  -e AUTH_USER=uploader \
  -e AUTH_PASSWORD='strong-password' \
  -v tfw-data:/srv/tfw/data \
  -v tfw-config:/etc/tfw \
  tfw
```

容器基于 `nginx:alpine`，启动时会先渲染配置，再前台运行 nginx。当前镜像不会忽略安装失败；如果配置渲染或安装步骤出错，容器会直接退出。ACME 证书申请在容器内仍需要 80 端口可达。

<a id="paths"></a>

## 目录结构

仓库结构：

```text
bin/            tfw 运维命令
nginx/          Nginx 站点模板（HTTP、HTTPS、ACME、common、auth-map）
scripts/        安装/升级/卸载入口
scripts/lib/    模块化函数库（common、i18n、prompt、template、validate、deps、acme、auth）
templates/      运行配置和 nginx.conf 参考
web/            文件浏览页、上传页、共享样式模板
```

关键模板文件：

| 文件 | 作用 |
| --- | --- |
| `bin/tfw` | 安装后的运维命令 |
| `scripts/install.sh` | 安装、升级、卸载入口 |
| `scripts/lib/template.sh` | envsubst 模板渲染、页面 i18n |
| `scripts/lib/validate.sh` | 输入校验和安装预检 |
| `nginx/site-common.conf.template` | HTTP/HTTPS 共用站点逻辑 |
| `nginx/site-auth-map.conf.template` | 会话 token 的 `map` 映射 |
| `web/shared-styles.css.template` | 文件浏览和上传页共享 CSS |
| `templates/tfw.conf.template` | 运行配置模板 |

安装后路径：

| 路径 | 说明 |
| --- | --- |
| `/etc/tfw/tfw.conf` | 运行配置 |
| `/usr/local/bin/tfw` | 运维命令 |
| `/etc/nginx/conf.d/temp-file-web.conf` | Nginx 站点配置 |
| `/etc/nginx/conf.d/temp-file-web-map.conf` | Nginx auth map 配置 |
| `/etc/nginx/conf.d/temp-file-web-acme.conf` | ACME 临时配置 |
| `/etc/tfw/sites/<site_id>/file-browser.html` | 文件浏览页 |
| `/etc/tfw/sites/<site_id>/file-upload.html` | 上传页 |
| `/etc/tfw/sites/<site_id>/file-upload.htpasswd` | 上传认证文件 |
| `/etc/tfw/sites/<site_id>/certs/` | 证书目录 |
| `/srv/tfw/data` | 数据根目录（也是默认上传目录） |
| `/var/www/_acme-challenge` | ACME webroot |

<a id="security"></a>

## 安全默认值

- HTTPS 模式只启用 `TLSv1.2` 和 `TLSv1.3`。
- 启用 `Strict-Transport-Security`。
- `X-Content-Type-Options: nosniff`、`X-Frame-Options: SAMEORIGIN`、`Referrer-Policy: strict-origin-when-cross-origin`。
- `Permissions-Policy` 禁用地理位置、麦克风、摄像头。
- `server_tokens off`。
- 上传认证文件 `umask 077` 写入、`0640` 权限。
- 证书目录 `0700` 权限。
- 上传接口仅开放 `PUT`、`DELETE`、`OPTIONS`，作用范围限 `${UPLOAD_DIR}`。
- 公开目录仅 `GET`、`HEAD`、`OPTIONS`。
- 会话 Cookie：Max-Age 24 小时、HttpOnly、SameSite Strict（HTTPS 下加 Secure）。
- ACME challenge 只暴露 `/.well-known/acme-challenge/`。
- 会话 token 通过 `nginx map` 指令校验，避免 `if ($cookie_xxx = "value")` 反模式。

注意：上传完成的文件默认公开可访问。如需私有下载，需调整 Nginx 模板。

<a id="migration"></a>

## 迁移部署

1. 将仓库复制到目标机器。
2. 确认 Nginx、端口、防火墙和域名可用。
3. 执行 `bash scripts/install.sh install`。
4. 选择语言和安装模式。
5. 配置访问主机、端口、域名、上传账号。
6. 用 `tfw info` 和 `tfw status` 验证。

迁移已有数据时，先停止旧站点，复制数据目录和证书目录到新机器，再执行 `bash scripts/install.sh upgrade`。

<a id="troubleshooting"></a>

## 常见问题

**ACME 证书申请失败：**

- 确认 `DOMAIN` 解析到当前机器。
- 确认 80 端口被防火墙或云安全组放行。
- 确认 `HTTP_PORT` 为 80。
- 可先用 `INSTALL_ACME=0` 部署 HTTP 站点，再排查证书问题。

**上传失败：**

- `tfw status` 检查站点是否可访问。
- `tfw passwd` 重新生成认证文件。
- 检查 Nginx 运行用户能否写入 `${UPLOAD_DIR}`。
- 检查 `MAX_UPLOAD_SIZE` 是否小于上传文件。

**删除按钮不显示或删除失败：**

- 先打开 `/upload` 登录，再访问首页 `/`。
- 删除按钮只在上传根目录的文件项上显示。
- 执行 `bash scripts/install.sh upgrade` 确保配置为最新版本。
- `tfw passwd` 重新生成认证文件后重试。
- 检查 Nginx 运行用户能否删除上传目录中的文件。

**页面能打开但目录为空：**

- 检查 `${DATA_DIR}` 是否有文件。
- 检查 `/_listing/` 是否返回 JSON。
- `tfw ls root` 查看本地文件。

**升级或卸载失败：**

- 确认 `/etc/tfw/tfw.conf` 仍存在且包含 `TFW_PROJECT_DIR`。
- 如运行配置丢失，按真实路径手动恢复后再执行脚本。

**Nginx 启动失败：**

- `tfw test` 或 `nginx -t` 查看错误详情。
- 检查端口是否冲突。
- 检查证书路径是否存在。
- 检查 `/etc/nginx/conf.d/` 中是否有其他站点配置冲突。

**云服务器端口不通：**

- 检查云安全组是否放行了 HTTP_PORT / HTTPS_PORT 入站规则。
