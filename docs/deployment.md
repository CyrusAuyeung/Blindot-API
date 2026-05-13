# Deployment Guide / 部署说明

[中文](#zh-cn) | [English](#english)

<a id="zh-cn"></a>

## 中文

本文档说明如何基于本仓库部署一套 Sub2API 中转站。

### 1. 准备环境

服务器需要安装：

```bash
docker --version
docker compose version
```

建议同时准备：

- 一个域名
- 一个反向代理，例如 Nginx 或 Caddy
- HTTPS 证书
- 足够的磁盘空间用于 PostgreSQL 数据

### 2. 克隆仓库

```bash
git clone https://github.com/OWNER/REPO.git
cd REPO
```

将 `OWNER/REPO` 替换为你的仓库地址。

### 3. 创建环境变量

```bash
cp .env.example .env
cp .smtp2brevo.env.example .smtp2brevo.env
```

编辑 `.env`，至少设置：

```text
POSTGRES_PASSWORD
JWT_SECRET
TOTP_ENCRYPTION_KEY
ADMIN_EMAIL
ADMIN_PASSWORD
```

编辑 `.smtp2brevo.env`，至少设置：

```text
BREVO_API_KEY
FROM_EMAIL
FROM_NAME
REPLY_TO
SMTP_AUTH_PASS
```

### 4. 启动服务

只启动主服务：

```bash
docker compose up -d
```

启动主服务和邮件中转：

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d
```

### 5. 检查状态

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml ps
docker logs --tail=100 sub2api
docker logs --tail=100 smtp2brevo
```

### 6. 配置反向代理

将你的域名反向代理到 Sub2API 暴露的端口。生产环境建议只让反向代理暴露公网端口，不要直接暴露数据库、Redis 或内部邮件中转端口。

### 7. 邮件设置

如果使用 `smtp2brevo`，在 Sub2API 后台填写 SMTP 设置。典型配置：

```text
SMTP host: smtp.example.com
SMTP port: 8025
SMTP username: sub2api
SMTP password: SMTP_AUTH_PASS in .smtp2brevo.env
From email: noreply@example.com
From name: Sub2API
Use TLS: enabled if using a trusted certificate
```

### 8. 生产注意事项

- 不要使用弱密码
- 不要把 `.env` 上传到 GitHub
- 不要公开数据库端口
- 定期备份 PostgreSQL
- 升级前先备份
- 提交前运行 `./scripts/check-public-safe.sh`

---

<a id="english"></a>

## English

This document explains how to deploy a Sub2API relay service based on this repository.

### 1. Prepare the Server

The server should have Docker and Docker Compose installed:

```bash
docker --version
docker compose version
```

Recommended extras:

- A domain name
- A reverse proxy such as Nginx or Caddy
- HTTPS certificates
- Enough disk space for PostgreSQL data

### 2. Clone the Repository

```bash
git clone https://github.com/OWNER/REPO.git
cd REPO
```

Replace `OWNER/REPO` with your own repository.

### 3. Create Environment Files

```bash
cp .env.example .env
cp .smtp2brevo.env.example .smtp2brevo.env
```

Edit `.env` and set at least:

```text
POSTGRES_PASSWORD
JWT_SECRET
TOTP_ENCRYPTION_KEY
ADMIN_EMAIL
ADMIN_PASSWORD
```

Edit `.smtp2brevo.env` and set at least:

```text
BREVO_API_KEY
FROM_EMAIL
FROM_NAME
REPLY_TO
SMTP_AUTH_PASS
```

### 4. Start Services

Start the main stack only:

```bash
docker compose up -d
```

Start the main stack with the mail relay:

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d
```

### 5. Check Status

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml ps
docker logs --tail=100 sub2api
docker logs --tail=100 smtp2brevo
```

### 6. Configure Reverse Proxy

Proxy your domain to the Sub2API exposed port. In production, only expose the reverse proxy publicly. Do not expose PostgreSQL, Redis, or the internal mail relay.

### 7. Email Settings

If you use `smtp2brevo`, configure SMTP in the Sub2API dashboard. Typical settings:

```text
SMTP host: smtp.example.com
SMTP port: 8025
SMTP username: sub2api
SMTP password: SMTP_AUTH_PASS in .smtp2brevo.env
From email: noreply@example.com
From name: Sub2API
Use TLS: enabled if using a trusted certificate
```

### 8. Production Notes

- Do not use weak passwords
- Do not upload `.env` to GitHub
- Do not expose database ports publicly
- Back up PostgreSQL regularly
- Back up before upgrades
- Run `./scripts/check-public-safe.sh` before committing
