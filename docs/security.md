# Security Notes

## Repository Rules

Keep production secrets and runtime data out of version control.

Do not commit:

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

## Before Committing

Run:

```bash
./scripts/check-public-safe.sh
```

## Secret Rotation

Rotate exposed secrets immediately:

- Database passwords
- JWT secrets
- TOTP encryption keys
- OAuth client secrets
- Brevo API keys
- SMTP relay passwords

## Deployment Hardening

Recommended production practices:

- Use strong generated secrets.
- Keep service ports private unless needed.
- Use a reverse proxy for public HTTPS traffic.
- Back up PostgreSQL regularly.
- Use pinned image versions for predictable upgrades.
- Review logs after every deployment.
