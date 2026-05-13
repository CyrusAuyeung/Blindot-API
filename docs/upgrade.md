# Upgrade Notes / 升级说明

[中文](#zh-cn) | [English](#english)

<a id="zh-cn"></a>

## 中文

建议使用固定镜像标签进行升级，避免长期依赖 `latest`。

### 升级 Sub2API

修改 `docker-compose.yml` 中的 Sub2API 镜像版本。

然后执行：

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml pull sub2api
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d sub2api smtp2brevo
```

### 检查状态

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml ps
docker logs --tail=100 sub2api
docker logs --tail=100 smtp2brevo
```

### 升级前备份

生产环境升级前至少备份：

```text
.env
.smtp2brevo.env
docker-compose.yml
docker-compose.smtp.yml
PostgreSQL database dump
```

### 回滚

将 `docker-compose.yml` 中的 Sub2API 镜像版本改回旧版本，然后执行：

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d sub2api smtp2brevo
```

### 危险命令

除非你明确知道自己要删除数据，否则不要在生产环境执行：

```bash
docker compose down -v
```

---

<a id="english"></a>

## English

Pinned image tags are recommended for predictable upgrades. Avoid relying on `latest` for long-term production deployments.

### Upgrade Sub2API

Edit the Sub2API image tag in `docker-compose.yml`.

Then run:

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml pull sub2api
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d sub2api smtp2brevo
```

### Check Status

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml ps
docker logs --tail=100 sub2api
docker logs --tail=100 smtp2brevo
```

### Backup Before Upgrading

For production deployments, back up at least:

```text
.env
.smtp2brevo.env
docker-compose.yml
docker-compose.smtp.yml
PostgreSQL database dump
```

### Rollback

Change the Sub2API image tag in `docker-compose.yml` back to the previous version, then run:

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d sub2api smtp2brevo
```

### Dangerous Command

Do not run this in production unless you intentionally want to delete data:

```bash
docker compose down -v
```
