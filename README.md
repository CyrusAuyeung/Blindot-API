# Blindot API

<p align="center">
  <a href="#中文"><img alt="中文" src="https://img.shields.io/badge/中文-默认-00A67E"></a>
  <a href="#english"><img alt="English" src="https://img.shields.io/badge/English-Available-1f6feb"></a>
</p>

<a id="中文"></a>

## 概览

Blindot API 是一套基于 Sub2API 构建的 AI API 中转站，用于统一接入、调度和管理上游模型能力。

本仓库提供 Blindot API 的公开部署编排与运维资料，包括 Docker Compose、PostgreSQL、Redis、smtp2brevo 邮件中转、升级流程和安全检查脚本。生产环境中的域名、密钥、数据库密码、邮件服务凭据和运行时参数均通过本地环境文件注入。

## 架构

API 请求链路：

```text
Client / WebUI
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

## 组件

- `Sub2API`：AI API 中转、用户管理、渠道管理、计费、风控和网关能力
- `PostgreSQL`：业务数据持久化
- `Redis`：缓存、队列和运行状态
- `smtp2brevo`：SMTP 到 Brevo HTTPS API 的本地邮件中转
- `Docker Compose`：服务编排和部署入口

## 目录结构

```text
docker-compose.yml          主服务编排
docker-compose.smtp.yml     邮件中转扩展编排
.env.example                Sub2API 环境变量示例
.smtp2brevo.env.example     smtp2brevo 环境变量示例
smtp2brevo/                 邮件中转服务源码
docs/                       部署、升级和安全说明
scripts/                    辅助检查脚本
```

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

## 邮件中转

当服务器无法直连传统 SMTP 出站端口时，可以启用 `smtp2brevo`。Sub2API 仍通过 SMTP 连接本地中转服务，中转服务再通过 Brevo HTTPS API 发信。

详见 [docs/smtp2brevo.md](docs/smtp2brevo.md)。

## 部署与升级

部署说明见 [docs/deployment.md](docs/deployment.md)。

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

安全说明见 [docs/security.md](docs/security.md)。

## 许可证与品牌

本仓库中的部署文件、文档和 `smtp2brevo` 代码使用 MIT License。第三方镜像、项目和依赖遵循其各自许可证。

`Blindot` 和 `Blindot API` 名称用于标识本项目和相关服务。MIT License 不授予任何商标权、品牌使用权或以 Blindot 名义运营服务的权利。

---

<a id="english"></a>

## Overview

Blindot API is an AI API relay gateway built on top of Sub2API. It provides a unified gateway layer for connecting, routing, and operating upstream AI model providers.

This repository contains the public deployment orchestration and operations material for Blindot API, including Docker Compose, PostgreSQL, Redis, the smtp2brevo mail relay, upgrade notes, and safety checks. Production-specific domains, credentials, database passwords, mail provider keys, and runtime values are injected through local environment files.

## Architecture

API request flow:

```text
Client / WebUI
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

## Components

- `Sub2API`: AI API relay, users, channels, billing, moderation, and gateway logic
- `PostgreSQL`: persistent application data
- `Redis`: cache, queues, and runtime state
- `smtp2brevo`: local SMTP-to-Brevo HTTPS API mail relay
- `Docker Compose`: service orchestration and deployment entry point

## Repository Layout

```text
docker-compose.yml          Main service stack
docker-compose.smtp.yml     Mail relay extension stack
.env.example                Example Sub2API environment file
.smtp2brevo.env.example     Example smtp2brevo environment file
smtp2brevo/                 Mail relay source code
docs/                       Deployment, upgrade, and security notes
scripts/                    Helper scripts
```

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

## Mail Relay

When a server cannot connect to traditional outbound SMTP ports, `smtp2brevo` can be enabled. Sub2API connects to the local relay through SMTP, and the relay sends email through the Brevo HTTPS API.

See [docs/smtp2brevo.md](docs/smtp2brevo.md).

## Deployment And Upgrade

See [docs/deployment.md](docs/deployment.md) for deployment notes.

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

See [docs/security.md](docs/security.md).

## License And Brand

Deployment files, documentation, and `smtp2brevo` code in this repository are licensed under the MIT License. Third-party images, projects, and dependencies retain their own licenses.

The `Blindot` and `Blindot API` names identify this project and related services. The MIT License does not grant trademark rights, brand usage rights, or the right to operate services under the Blindot name.
