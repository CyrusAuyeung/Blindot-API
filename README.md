# Blindot API

<p align="center">
  <a href="#中文"><img alt="中文" src="https://img.shields.io/badge/中文-默认-00A67E"></a>
  <a href="#english"><img alt="English" src="https://img.shields.io/badge/English-Available-1f6feb"></a>
</p>

<a id="中文"></a>

## 概览

Blindot API 是一套基于 Sub2API 构建的 AI API 中转站，用于统一接入、调度和管理上游模型能力。

本仓库提供 Blindot API 的公开部署编排与运维资料，覆盖 Docker Compose、PostgreSQL、Redis、smtp2brevo 邮件中转、Nginx 反向代理、升级、备份恢复和安全检查。生产环境中的域名、密钥、数据库密码、邮件服务凭据和运行时参数均通过本地环境文件注入。

## 中转站能力

Blindot API 面向需要统一模型入口的用户和应用，提供一套 OpenAI/Anthropic/Gemini 兼容风格的 API 中转层。通过一个 API 密钥即可接入多个上游模型渠道，并由网关负责路由、负载均衡、可用性检测、用量统计和余额计费。

核心能力包括：

- 统一 API 入口与密钥管理
- 多上游账号与多渠道调度
- 自动切换、健康检测和可用率统计
- 用户、分组、渠道、订阅和计费管理
- 内容风控、请求审计和运行监控
- 邮箱验证码、余额提醒和通知能力

## 模型支持

Blindot API 可通过 Sub2API 接入多个模型供应商和模型族。公开站点当前展示的模型族包括：

- Claude
- GPT / OpenAI
- Gemini
- Antigravity

当前 OpenAI 侧示例模型包括：

- `gpt-5.2`
- `gpt-5.3-codex`
- `gpt-5.4-mini`
- `gpt-5.4`
- `gpt-5.5`
- `gpt-image-1`
- `gpt-image-2`
- `gpt-image-1.5`

实际可用模型取决于部署时配置的上游渠道、账号权限、模型映射、分组策略和运行状态。

## 架构

API 请求链路：

```text
Client / WebUI
  -> Reverse Proxy
  -> Blindot API (Sub2API)
  -> Upstream AI providers
```

邮件发送链路：

```text
Sub2API
  -> smtp2brevo local relay
  -> Brevo HTTPS API
  -> User inbox
```

服务组件：

```text
Docker Compose
  ├─ sub2api
  ├─ postgres
  ├─ redis
  └─ smtp2brevo
```

## 组件

- `Sub2API`：AI API 中转、用户管理、渠道管理、计费、风控和网关能力
- `PostgreSQL`：业务数据持久化
- `Redis`：缓存、队列和运行状态
- `smtp2brevo`：SMTP 到 Brevo HTTPS API 的本地邮件中转
- `Docker Compose`：服务编排和部署入口
- `Nginx / reverse proxy`：推荐的公网 HTTPS 入口

## 目录结构

```text
docker-compose.yml              主服务编排
docker-compose.smtp.yml         邮件中转扩展编排
.env.example                    Sub2API 环境变量示例
.smtp2brevo.env.example         smtp2brevo 环境变量示例
smtp2brevo/                     邮件中转服务源码
docs/deployment.md              部署说明
docs/configuration.md           配置说明
docs/smtp2brevo.md              邮件中转说明
docs/nginx.md                   反向代理示例
docs/backup-restore.md          备份与恢复说明
docs/upgrade.md                 升级说明
docs/security.md                安全说明
docs/production-checklist.md    上线前检查清单
scripts/check-public-safe.sh     公开仓库安全检查脚本
```

## 前置要求

- Linux 服务器
- Docker Engine
- Docker Compose v2
- 一个可解析到服务器的域名
- HTTPS 反向代理，例如 Nginx + Certbot
- 可用的邮件服务商 API Key，例如 Brevo

## 快速开始

复制环境变量示例：

```bash
cp .env.example .env
cp .smtp2brevo.env.example .smtp2brevo.env
```

编辑 `.env` 与 `.smtp2brevo.env`，填入部署所需的域名、数据库密码、JWT 密钥、邮件服务密钥和运行参数。

启动完整服务：

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d
```

查看状态：

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml ps
```

查看日志：

```bash
docker logs --tail=100 sub2api
docker logs --tail=100 smtp2brevo
```

## 部署流程

推荐按以下顺序部署：

1. 准备 `.env` 与 `.smtp2brevo.env`
2. 启动 PostgreSQL、Redis、Sub2API 和 smtp2brevo
3. 配置反向代理和 HTTPS
4. 在 Sub2API 后台配置 SMTP
5. 发送测试邮件
6. 配置支付、风控、注册和用户策略
7. 上线前运行安全检查和备份流程

详细步骤见 [docs/deployment.md](docs/deployment.md)。

## 邮件中转

当服务器无法直连传统 SMTP 出站端口时，可以启用 `smtp2brevo`。Sub2API 仍通过 SMTP 连接本地中转服务，中转服务再通过 Brevo HTTPS API 发信。

详见 [docs/smtp2brevo.md](docs/smtp2brevo.md)。

## 反向代理

建议只把反向代理暴露到公网，内部服务端口通过 Docker 网络或本机端口访问。

Nginx 示例见 [docs/nginx.md](docs/nginx.md)。

## 备份与恢复

生产环境升级前应至少备份：

- `.env`
- `.smtp2brevo.env`
- `docker-compose.yml`
- `docker-compose.smtp.yml`
- PostgreSQL 数据库 dump

详见 [docs/backup-restore.md](docs/backup-restore.md)。

## 升级

升级 Sub2API：

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml pull sub2api
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d sub2api smtp2brevo
```

更多升级和回滚说明见 [docs/upgrade.md](docs/upgrade.md)。

## 安全检查

提交前运行：

```bash
./scripts/check-public-safe.sh
```

安全说明见 [docs/security.md](docs/security.md)。上线前检查见 [docs/production-checklist.md](docs/production-checklist.md)。

## 许可证与品牌

本仓库中的部署文件、文档和 `smtp2brevo` 代码使用 MIT License。第三方镜像、项目和依赖遵循其各自许可证。

`Blindot` 和 `Blindot API` 名称用于标识本项目和相关服务。MIT License 不授予任何商标权、品牌使用权或以 Blindot 名义运营服务的权利。

---

<a id="english"></a>

## Overview

Blindot API is an AI API relay gateway built on top of Sub2API. It provides a unified gateway layer for connecting, routing, and operating upstream AI model providers.

This repository contains the public deployment orchestration and operations material for Blindot API, including Docker Compose, PostgreSQL, Redis, the smtp2brevo mail relay, Nginx reverse proxy examples, upgrade notes, backup and restore notes, and safety checks. Production-specific domains, credentials, database passwords, mail provider keys, and runtime values are injected through local environment files.

## Relay Capabilities

Blindot API is designed for users and applications that need a unified model gateway. It provides an API relay layer with OpenAI/Anthropic/Gemini-compatible usage patterns. A single API key can access multiple upstream model channels while the gateway handles routing, load balancing, health checks, usage statistics, and balance billing.

Core capabilities include:

- Unified API entry point and key management
- Multi-account and multi-channel upstream routing
- Automatic failover, health checks, and availability metrics
- User, group, channel, subscription, and billing management
- Content moderation, request auditing, and runtime monitoring
- Email verification, balance reminders, and notification delivery

## Model Support

Blindot API can connect to multiple model providers and model families through Sub2API. Model families currently shown on the public site include:

- Claude
- GPT / OpenAI
- Gemini
- Antigravity

Current OpenAI-side example models include:

- `gpt-5.2`
- `gpt-5.3-codex`
- `gpt-5.4-mini`
- `gpt-5.4`
- `gpt-5.5`
- `gpt-image-1`
- `gpt-image-2`
- `gpt-image-1.5`

Actual model availability depends on upstream channels, account permissions, model mappings, group policies, and runtime health.

## Architecture

API request flow:

```text
Client / WebUI
  -> Reverse Proxy
  -> Blindot API (Sub2API)
  -> Upstream AI providers
```

Email flow:

```text
Sub2API
  -> smtp2brevo local relay
  -> Brevo HTTPS API
  -> User inbox
```

Service components:

```text
Docker Compose
  ├─ sub2api
  ├─ postgres
  ├─ redis
  └─ smtp2brevo
```

## Components

- `Sub2API`: AI API relay, users, channels, billing, moderation, and gateway logic
- `PostgreSQL`: persistent application data
- `Redis`: cache, queues, and runtime state
- `smtp2brevo`: local SMTP-to-Brevo HTTPS API mail relay
- `Docker Compose`: service orchestration and deployment entry point
- `Nginx / reverse proxy`: recommended public HTTPS entry point

## Repository Layout

```text
docker-compose.yml              Main service stack
docker-compose.smtp.yml         Mail relay extension stack
.env.example                    Example Sub2API environment file
.smtp2brevo.env.example         Example smtp2brevo environment file
smtp2brevo/                     Mail relay source code
docs/deployment.md              Deployment guide
docs/configuration.md           Configuration notes
docs/smtp2brevo.md              Mail relay notes
docs/nginx.md                   Reverse proxy example
docs/backup-restore.md          Backup and restore notes
docs/upgrade.md                 Upgrade notes
docs/security.md                Security notes
docs/production-checklist.md    Production checklist
scripts/check-public-safe.sh     Public repository safety check
```

## Requirements

- Linux server
- Docker Engine
- Docker Compose v2
- A domain pointing to the server
- HTTPS reverse proxy, for example Nginx + Certbot
- Mail provider API key, for example Brevo

## Quick Start

Copy example environment files:

```bash
cp .env.example .env
cp .smtp2brevo.env.example .smtp2brevo.env
```

Edit `.env` and `.smtp2brevo.env` with your own domain, database password, JWT secret, mail provider key, and runtime settings.

Start the full stack:

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d
```

Check status:

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml ps
```

Check logs:

```bash
docker logs --tail=100 sub2api
docker logs --tail=100 smtp2brevo
```

## Deployment Flow

Recommended deployment order:

1. Prepare `.env` and `.smtp2brevo.env`
2. Start PostgreSQL, Redis, Sub2API, and smtp2brevo
3. Configure reverse proxy and HTTPS
4. Configure SMTP in the Sub2API dashboard
5. Send a test email
6. Configure payment, moderation, registration, and user policies
7. Run safety checks and backup procedures before production use

See [docs/deployment.md](docs/deployment.md).

## Mail Relay

When a server cannot connect to traditional outbound SMTP ports, `smtp2brevo` can be enabled. Sub2API connects to the local relay through SMTP, and the relay sends email through the Brevo HTTPS API.

See [docs/smtp2brevo.md](docs/smtp2brevo.md).

## Reverse Proxy

The public internet should normally reach only the reverse proxy. Internal service ports should stay inside Docker networks or localhost bindings.

See [docs/nginx.md](docs/nginx.md).

## Backup And Restore

Before production upgrades, back up at least:

- `.env`
- `.smtp2brevo.env`
- `docker-compose.yml`
- `docker-compose.smtp.yml`
- PostgreSQL database dump

See [docs/backup-restore.md](docs/backup-restore.md).

## Upgrade

Upgrade Sub2API:

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml pull sub2api
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d sub2api smtp2brevo
```

See [docs/upgrade.md](docs/upgrade.md) for upgrade and rollback notes.

## Safety Check

Run before committing:

```bash
./scripts/check-public-safe.sh
```

See [docs/security.md](docs/security.md). See [docs/production-checklist.md](docs/production-checklist.md) before production use.

## License And Brand

Deployment files, documentation, and `smtp2brevo` code in this repository are licensed under the MIT License. Third-party images, projects, and dependencies retain their own licenses.

The `Blindot` and `Blindot API` names identify this project and related services. The MIT License does not grant trademark rights, brand usage rights, or the right to operate services under the Blindot name.
