# Temp-File-Web

`Temp-File-Web` is now a reusable deployment template for a lightweight Nginx-based file server.

It is designed for deploying on new machines without hardcoded domain assumptions, and includes:

- Template-driven Nginx configuration
- Bilingual first-run installer: Chinese or English
- Two install flows: interactive or one-click defaults
- `acme.sh` certificate issuance and install
- Custom file index page and upload page
- `tfw` maintenance CLI that reads the installed runtime config
- Safer defaults for TLS, headers, paths and auth file permissions

下文以中文为主，方便直接部署。

## 目标

这个项目现在不再是“只适配当前一台机器”的仓库，而是一个可复用模板：

- 换机器时不需要手改一堆硬编码路径
- 首次安装时可选择中文或英文
- 可选择交互式安装或一键默认安装
- 可直接接入 `acme.sh` 自动申请证书（需要域名）
- 证书不是必选项，可先以 HTTP 方式快速上线
- 安装后生成运行配置，`tfw` 会按实际部署参数工作

## 功能

服务侧能力：

- 自定义公开文件列表页
- `/upload` Basic Auth 保护的上传页面
- `/uploads/` 支持认证后 `PUT` 上传
- `/_listing/` 提供 JSON 文件索引
- HTTP 自动跳转到 HTTPS
- 无证书时可直接使用 HTTP 站点
- 内置 ACME challenge 路由
- TLS 与常见安全头默认启用
- 每个站点独立 access/error 日志文件

安装侧能力：

- 首次运行安装脚本时可选 `中文` 或 `English`
- 安装器支持：
  - `install`
  - `upgrade`
  - `uninstall`
- 安装模式可选：
  - `交互式安装`
  - `一键默认安装`
- 自动创建站点目录、上传目录、认证文件和运行配置
- 自动安装 `tfw`
- 可调用 `acme.sh` 完成签发与证书落地

运维侧能力：

- `tfw info`
- `tfw urls`
- `tfw cert`
- `tfw status`
- `tfw test`
- `tfw ls`
- `tfw logs`
- `tfw restart`
- `tfw passwd`

## 项目结构

```text
bin/        管理命令
nginx/      Nginx 模板
scripts/    安装脚本
templates/  运行配置模板
web/        页面模板
```

关键文件：

- [bin/tfw](/root/Temp-File-Web/bin/tfw)
  安装后的运维命令。默认读取 `/etc/tfw/tfw.conf`。
- [scripts/install.sh](/root/Temp-File-Web/scripts/install.sh)
  模板安装器。
- [site-https.conf.template](/root/Temp-File-Web/nginx/site-https.conf.template)
  正式 HTTPS 站点模板。
- [site-http.conf.template](/root/Temp-File-Web/nginx/site-http.conf.template)
  无证书时的 HTTP 站点模板。
- [site-acme.conf.template](/root/Temp-File-Web/nginx/site-acme.conf.template)
  证书签发阶段用的 ACME 临时站点模板。
- [site-common.conf.template](/root/Temp-File-Web/nginx/site-common.conf.template)
  HTTP 与 HTTPS 共用的站点逻辑片段。
- [templates/tfw.conf.template](/root/Temp-File-Web/templates/tfw.conf.template)
  安装后生成的运行配置模板。
- [web/file-browser.html.template](/root/Temp-File-Web/web/file-browser.html.template)
  文件浏览页面模板。
- [web/file-upload.html.template](/root/Temp-File-Web/web/file-upload.html.template)
  上传页面模板。
- [nginx-main.conf.template](/root/Temp-File-Web/templates/nginx-main.conf.template)
  主 `nginx.conf` 参考模板。

## 默认安装结果

安装完成后，项目默认会生成这些结果：

- 站点运行配置：`/etc/tfw/tfw.conf`
- `tfw` 命令：`/usr/local/bin/tfw`
- Nginx 站点配置：`/etc/nginx/conf.d/temp-file-web.conf`
- ACME challenge 临时配置：`/etc/nginx/conf.d/temp-file-web-acme.conf`（仅启用 ACME 且尚未切到正式 HTTPS 时）
- 站点资源目录：`/etc/tfw/sites/<site_id>/`
- 认证文件：`/etc/tfw/sites/<site_id>/file-upload.htpasswd`
- 页面文件：
  - `/etc/tfw/sites/<site_id>/file-browser.html`
  - `/etc/tfw/sites/<site_id>/file-upload.html`
- 证书文件：
  - `/etc/tfw/sites/<site_id>/certs/fullchain.cer`
  - `/etc/tfw/sites/<site_id>/certs/<site_id>.key`
- 数据目录：`/srv/tfw/data`
- 上传目录：`/srv/tfw/data/uploads`
- ACME webroot：`/var/www/_acme-challenge`

## 安全默认值

模板项目默认做了这些强化：

- TLS 仅启用 `TLSv1.2` 和 `TLSv1.3`
- 默认开启：
  - `Strict-Transport-Security`
  - `X-Content-Type-Options`
  - `X-Frame-Options`
  - `Referrer-Policy`
  - `Permissions-Policy`
- `server_tokens off`
- 上传认证文件通过 `umask 077` 写入
- 证书目录权限默认 `0700`
- 上传目录限制在 `/uploads/`
- 仅 `PUT` 对上传目录开放认证写入
- ACME challenge 仅暴露 `/.well-known/acme-challenge/`

## 依赖

安装脚本默认会尝试安装缺失依赖，当前支持：

- `apt-get`
- `dnf`
- `yum`

核心依赖包括：

- `nginx`
- `curl`
- `openssl`
- 常用系统工具：`sed` `awk` `grep` `find`

如果你不希望自动装依赖，可以先手动安装，再执行：

```bash
AUTO_INSTALL_DEPS=0 bash scripts/install.sh
```

## 安装方式

### 1. 交互式安装

```bash
cd /root/Temp-File-Web
bash scripts/install.sh install
```

首次运行时安装器会先让你选择：

1. 中文或英文
2. 交互式安装或一键默认安装

如果选择交互式安装，会逐项询问：

- 域名
- 访问主机名或 IP
- HTTP 端口
- HTTPS 端口
- 站点标题
- Nginx 运行用户
- 数据目录
- 站点资源目录根路径
- 是否启用 acme.sh 自动签发证书
- 上传用户名
- 上传密码
- 单文件上传上限

只有当你选择启用 acme.sh 时，安装器才会继续询问：

- ACME webroot
- 证书邮箱

交互式安装里，这些字段现在支持直接回车处理：

- 域名：可留空；如果要启用 ACME，则必须填写
- 访问主机名或 IP：必填；留空时默认使用 `IP`
- HTTP 端口、HTTPS 端口：有域名时默认 `80`、`443`；无域名时默认 `8080`、`8443`
- 站点标题、Nginx 用户、数据目录、站点资源目录、上传用户名、上传上限：留空时使用默认值
- ACME webroot：仅在启用 acme.sh 时出现，留空时使用默认值
- 证书邮箱：留空时跳过，不强制写默认邮箱
- 上传密码：留空时自动随机生成；如果手动输入，则会要求二次确认

如果设置了 `INSTALL_ACME=0`：

- 交互模式不会再询问是否启用 acme、`ACME webroot` 和证书邮箱
- 安装器会直接跳过证书申请流程
- 会直接写入可用的 HTTP 站点配置，方便先上线使用
- 如果你之后手动放入证书文件，再重新执行安装或升级，安装器会切到正式 HTTPS 配置

### 2. 一键默认安装

一键默认安装不再强制要求域名。

使用域名并启用 ACME：

```bash
DOMAIN=files.example.com INSTALL_MODE=default LANGUAGE=zh bash scripts/install.sh install
```

使用 IP 和端口直接访问：

```bash
IP=192.0.2.10 \
ACCESS_HOST=192.0.2.10 \
HTTP_PORT=8080 \
INSTALL_ACME=0 \
INSTALL_MODE=default \
LANGUAGE=zh \
bash scripts/install.sh install
```

默认值大致如下：

- `SITE_TITLE=Temp File Web`
- `DATA_DIR=/srv/tfw/data`
- `SITE_BASE_DIR=/etc/tfw/sites`
- `ACME_WEBROOT=/var/www/_acme-challenge`
- `AUTH_USER=uploader`
- `MAX_UPLOAD_SIZE=2g`
- 无域名时默认：
  - `HTTP_PORT=8080`
  - `HTTPS_PORT=8443`
- 有域名时默认：
  - `HTTP_PORT=80`
  - `HTTPS_PORT=443`

### 3. 非交互全参数安装

适合批量部署或自动化：

```bash
DOMAIN=files.example.com \
ACCESS_HOST=files.example.com \
SITE_TITLE="Team Files" \
LANGUAGE=en \
INSTALL_MODE=default \
TFW_USER=www-data \
DATA_DIR=/srv/team-files/data \
SITE_BASE_DIR=/etc/tfw/sites \
ACME_WEBROOT=/var/www/_acme-challenge \
ACME_EMAIL=admin@example.com \
AUTH_USER=uploader \
AUTH_PASSWORD='strong-password' \
MAX_UPLOAD_SIZE=4g \
bash scripts/install.sh
```

ACME 使用限制：

- `DOMAIN` 必填
- `HTTP_PORT` 必须为 `80`

## 升级

当你已经安装过一套站点后，可以直接基于现有 `/etc/tfw/tfw.conf` 升级模板文件和 `tfw` 命令：

```bash
bash scripts/install.sh upgrade
```

升级动作会：

- 读取现有运行配置
- 重新渲染前端页面模板
- 重新写入 `tfw` 运行配置
- 重新安装 `/usr/local/bin/tfw`
- 如果已有证书，则重写正式 HTTPS 站点配置
- 如果启用了 ACME 但还没有证书，则保留 ACME challenge 配置
- 如果未启用 ACME 且还没有证书，则会保留 HTTP 站点配置

适合这些场景：

- 你更新了仓库里的页面模板
- 你调整了 Nginx 模板
- 你升级了 `tfw` 命令本身

## 卸载

卸载命令：

```bash
bash scripts/install.sh uninstall
```

默认行为：

- 删除 `tfw` 命令
- 删除站点配置
- 删除运行配置
- 删除安装生成的页面和认证文件
- 默认保留数据目录
- 默认保留证书目录

如果你明确要删数据或证书，可以这样执行：

```bash
UNINSTALL_KEEP_DATA=0 UNINSTALL_KEEP_CERTS=0 bash scripts/install.sh uninstall
```

这样设计是为了避免误删上传内容和已签发证书。

## acme.sh 证书流程

安装脚本会按这个顺序工作：

1. 安装 `acme.sh`（如果本机没有）
2. 先写入 ACME challenge 专用 HTTP 配置
3. 重载 Nginx，让 `/.well-known/acme-challenge/` 可访问
4. 使用 `acme.sh --issue -w <webroot>` 申请证书
5. 用 `acme.sh --install-cert` 把证书落地到站点目录
6. 如果证书申请成功，生成正式 HTTPS 配置并再次重载 Nginx
7. 如果证书申请失败，自动回落到可用的 HTTP 站点配置

如果你暂时不想签证书，可以跳过：

```bash
INSTALL_ACME=0 ACCESS_HOST=192.0.2.10 HTTP_PORT=8080 bash scripts/install.sh
```

这种情况下安装器会直接写入可用的 HTTP 站点配置。你需要后续自己把证书文件放到站点 `certs` 目录，再重新执行安装或升级，切换到 HTTPS。

## 安装后检查

安装完成后先执行：

```bash
tfw info
tfw urls
tfw cert
tfw status
```

重点看：

- 配置文件是否存在
- 页面文件是否存在
- 认证文件是否存在
- 证书文件是否存在
- 根页面、上传目录、listing API 是否返回预期状态码
- 当前站点模式是 HTTP 还是 HTTPS

## `tfw` 命令

```bash
tfw help
tfw info
tfw urls
tfw cert
tfw status
tfw test
tfw ls root
tfw ls uploads
tfw logs access 100
tfw logs error 100
tfw restart
tfw passwd
```

说明：

- `tfw info`
  显示安装后配置、目录、页面、证书、日志和站点 URL。
- `tfw cert`
  显示 `acme.sh`、证书和私钥路径。
- `tfw status`
  同时做 `nginx -t`、进程检查、HTTP 返回码检查、目录文件数量与空间检查。
- `tfw passwd`
  轮换上传认证密码；本地写入校验通过后立即生效，并附带输出远端访问探测结果。
- `tfw` 默认读取 `/etc/tfw/tfw.conf`。
  如果你要临时切换到别的配置文件，可以这样执行：

```bash
TFW_CONFIG=/path/to/tfw.conf tfw info
```

## 迁移到其他设备

这个项目现在适合复制到其他设备直接部署，但请注意：

1. 如果你要启用 ACME，目标机器必须已经完成域名解析。
2. 你选择的 HTTP/HTTPS 端口必须可达。
3. Nginx 需要可正常启动。
4. 若要自动申请证书，`acme.sh` 必须能通过 HTTP challenge 验证域名。

迁移步骤通常是：

1. 把仓库复制到目标机器
2. 执行 `bash scripts/install.sh`
3. 选择语言和安装模式
4. 输入目标访问主机、端口，以及可选域名
5. 等待配置、证书、页面和认证文件全部生成
6. 使用 `tfw info` 和 `tfw status` 验证

## 注意事项

- 当前安装器默认面向单站点安装。
- 如果一台机器上部署多个站点，建议为每个站点单独规划 `SITE_ID`、资源目录和端口。
- `tfw` 读取的是本机安装后的运行配置，不再依赖仓库里的硬编码值。
- 如果你要定制首页文案或 UI，建议修改模板文件而不是改安装后产物。
- [nginx-main.conf.template](/root/Temp-File-Web/templates/nginx-main.conf.template) 只是参考模板，安装器不会默认覆盖系统主配置。
- `INSTALL_ACME=0` 时安装器会优先生成 HTTP 站点配置；只有你手动补齐证书后，才会切到正式 HTTPS 站点配置。
- `upgrade` 和 `uninstall` 依赖已有 `/etc/tfw/tfw.conf`，如果运行配置已经丢失，这两个动作无法自动继续。

## 后续建议

如果还要继续强化，我建议下一步做这三件事：

- 给安装器增加卸载/升级子命令
- 增加多站点模式
- 增加 `systemd` 定时任务检查或证书续期状态检查
