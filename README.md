# tfw-file-server

一个基于 Nginx 的轻量静态文件服务项目，包含：

- 自定义文件列表页 `web/file-browser.html`
- 自定义上传页 `web/file-upload.html`
- Nginx 配置 `nginx/file.conf`
- 全局管理命令 `bin/tfw`
- 安装脚本 `scripts/install.sh`

## 功能

- 公开目录列表 UI
- `/upload` Basic Auth 保护的上传入口
- `/uploads/` PUT 上传
- `tfw time`
- `tfw status`
- `tfw restart`
- `tfw passwd`

## 目录

```text
bin/        管理命令
nginx/      Nginx 配置
scripts/    安装脚本
templates/  示例模板
web/        页面文件
```

## 安装

```bash
cd /root/tfw-file-server
bash scripts/install.sh
```

安装后：

```bash
tfw status
```

## 注意

- 仓库里只放 `file-upload.htpasswd.example`，不会提交线上真实认证文件。
- 如果你要直接上线，记得检查 `nginx/file.conf` 里的域名、证书路径、数据目录。
