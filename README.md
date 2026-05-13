<div align="center">

# Blindot API

A public, sanitized deployment template for a Sub2API-based AI API relay service.

[![中文](https://img.shields.io/badge/Language-中文-2ea44f?style=for-the-badge)](#zh-cn)
[![English](https://img.shields.io/badge/Language-English-0969da?style=for-the-badge)](#english)

</div>

<a id="zh-cn"></a>

## 中文

Blindot API 是一套基于 Sub2API 的 AI API 中转站部署模板。这个仓库展示了一套可公开复用、已脱敏的 Docker Compose 部署结构，包含 Sub2API、PostgreSQL、Redis，以及可选的 `smtp2brevo` 邮件中转服务。

这个仓库不是生产服务器备份。它不包含真实环境变量、数据库、用户数据、日志、证书、私钥、API Key 或任何生产密钥。

### 这个仓库适合谁

如果你想部署一套类似的 AI API 中转站，可以参考本仓库：

- 用 Sub2API 作为 API 中转网关
- 用 PostgreSQL 保存业务数据
- 用 Redis 提供缓存和队列能力
- 用 Brevo API 解决 VPS 封锁 SMTP 端口导致的邮件发送问题
- 用 Docker Compose 管理整套服务
- 用 `.env.example` 和 `.smtp2brevo.env.example` 管理配置模板

### 架构

API 请求链路：

```text
Client / WebUI
  -> Sub2API
  -> Upstream AI providers
```

邮件发送链路：

```text
Sub2API
  -> smtp2brevo local SMTP relay
  -> Brevo HTTPS API
  -> User inbox
```

### 文件说明

```text
docker-compose.yml          主服务栈，包含 Sub2API、PostgreSQL、Redis
docker-compose.smtp.yml     可选邮件中转扩展，包含 smtp2brevo
.env.example                Sub2API 环境变量模板
.smtp2brevo.env.example     smtp2brevo 环境变量模板
smtp2brevo/                 SMTP 转 Brevo API 的中转服务源码
docs/deployment.md          部署说明
docs/smtp2brevo.md          邮件中转说明
docs/upgrade.md             升级说明
docs/security.md            公开仓库安全说明
scripts/check-public-safe.sh 公开前安全扫描脚本
```

### 快速开始

复制环境变量模板：

```bash
cp .env.example .env
cp .smtp2brevo.env.example .smtp2brevo.env
```

编辑 `.env` 和 `.smtp2brevo.env`，填入你自己的数据库密码、JWT 密钥、Brevo API Key、SMTP 中转密码等配置。

启动主服务：

```bash
docker compose up -d
```

启动主服务和邮件中转：

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d
```

### SMTP 中转说明

如果你的 VPS 服务商封锁了 25、465、587、2525 等 SMTP 出站端口，可以使用 `smtp2brevo`。

Sub2API 仍然配置为 SMTP 发信，但实际邮件由 `smtp2brevo` 调用 Brevo HTTPS API 发出。

典型配置：

```text
SMTP Host: smtp.example.com
SMTP Port: 8025
SMTP Username: sub2api
SMTP Password: SMTP_AUTH_PASS in .smtp2brevo.env
From Email: noreply@example.com
From Name: Sub2API
Use TLS: enabled when using a trusted certificate
```

详细说明见 [docs/smtp2brevo.md](docs/smtp2brevo.md)。

### 升级

建议使用固定镜像标签，不要长期依赖 `latest`。

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml pull sub2api
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d sub2api smtp2brevo
```

详细说明见 [docs/upgrade.md](docs/upgrade.md)。

### 安全边界

不要提交以下文件或目录：

```text
.env
.smtp2brevo.env
data/
backup/
backups/
postgres_data/
redis_data/
*.pem
*.key
*.sql
*.sql.gz
*.tar.gz
```

提交前建议运行：

```bash
./scripts/check-public-safe.sh
```

更多说明见 [docs/security.md](docs/security.md)。

---

<a id="english"></a>

## English

Blindot API is a deployment template for an AI API relay service based on Sub2API. This repository provides a public, sanitized Docker Compose deployment structure with Sub2API, PostgreSQL, Redis, and an optional `smtp2brevo` mail relay.

This repository is not a production server backup. It does not include real environment files, databases, user data, logs, certificates, private keys, API keys, or production secrets.

### Who This Is For

Use this repository as a reference if you want to deploy a similar AI API relay service with:

- Sub2API as the API relay gateway
- PostgreSQL for persistent data
- Redis for cache and queue features
- Brevo API based email delivery when outbound SMTP ports are blocked
- Docker Compose based service management
- Example environment files for safe configuration

### Architecture

API request flow:

```text
Client / WebUI
  -> Sub2API
  -> Upstream AI providers
```

Email flow:

```text
Sub2API
  -> smtp2brevo local SMTP relay
  -> Brevo HTTPS API
  -> User inbox
```

### Files

```text
docker-compose.yml          Main stack with Sub2API, PostgreSQL, and Redis
docker-compose.smtp.yml     Optional smtp2brevo mail relay extension
.env.example                Sub2API environment template
.smtp2brevo.env.example     smtp2brevo environment template
smtp2brevo/                 SMTP-to-Brevo relay source code
docs/deployment.md          Deployment guide
docs/smtp2brevo.md          Mail relay guide
docs/upgrade.md             Upgrade guide
docs/security.md            Public repository security guide
scripts/check-public-safe.sh Public safety check script
```

### Quick Start

Copy environment templates:

```bash
cp .env.example .env
cp .smtp2brevo.env.example .smtp2brevo.env
```

Edit `.env` and `.smtp2brevo.env` with your own database password, JWT secret, Brevo API key, relay password, and other settings.

Start the main stack:

```bash
docker compose up -d
```

Start the main stack with the mail relay:

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d
```

### SMTP Relay

If your VPS provider blocks outbound SMTP ports such as 25, 465, 587, or 2525, you can use `smtp2brevo`.

Sub2API still sends mail through SMTP, but `smtp2brevo` forwards the email through the Brevo HTTPS API.

Typical settings:

```text
SMTP Host: smtp.example.com
SMTP Port: 8025
SMTP Username: sub2api
SMTP Password: SMTP_AUTH_PASS in .smtp2brevo.env
From Email: noreply@example.com
From Name: Sub2API
Use TLS: enabled when using a trusted certificate
```

See [docs/smtp2brevo.md](docs/smtp2brevo.md) for details.

### Upgrade

Pinned image tags are recommended instead of relying on `latest`.

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml pull sub2api
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d sub2api smtp2brevo
```

See [docs/upgrade.md](docs/upgrade.md) for details.

### Security Boundary

Do not commit these files or directories:

```text
.env
.smtp2brevo.env
data/
backup/
backups/
postgres_data/
redis_data/
*.pem
*.key
*.sql
*.sql.gz
*.tar.gz
```

Before committing, run:

```bash
./scripts/check-public-safe.sh
```

See [docs/security.md](docs/security.md) for more details.

## License

This repository is a deployment template. Check upstream projects for their respective licenses.
