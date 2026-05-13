# Security Notes / 安全说明

[中文](#zh-cn) | [English](#english)

<a id="zh-cn"></a>

## 中文

这个仓库被设计为公开部署模板，不应该包含任何生产机密或运行时数据。

### 不应提交的内容

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

### 提交前检查

```bash
./scripts/check-public-safe.sh
```

### 推荐做法

- 真实密钥只保存在服务器本地
- 使用 `.env.example` 作为模板
- 使用 `.smtp2brevo.env.example` 作为邮件中转模板
- 数据库备份不要放进公开仓库
- TLS 私钥不要放进公开仓库
- 如果密钥曾经被公开，立即轮换

### 公开仓库和生产服务器的区别

公开仓库保存的是部署结构和模板。生产服务器保存的是真实运行数据和真实密钥。

这两者不应该混在一起。

---

<a id="english"></a>

## English

This repository is designed as a public deployment template. It should not contain production secrets or runtime data.

### Do Not Commit

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

### Check Before Commit

```bash
./scripts/check-public-safe.sh
```

### Recommendations

- Keep real secrets only on the server
- Use `.env.example` as a template
- Use `.smtp2brevo.env.example` as the mail relay template
- Do not put database backups in the public repository
- Do not put TLS private keys in the public repository
- Rotate any secret that has ever been exposed

### Public Repository vs Production Server

The public repository stores deployment structure and templates. The production server stores real runtime data and secrets.

Keep them separate.
