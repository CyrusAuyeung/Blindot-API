# Deployment Guide

## 1. Prepare Environment Files

```bash
cp .env.example .env
cp .smtp2brevo.env.example .smtp2brevo.env
```

Edit both files before starting services.

Common production values include:

- PostgreSQL password
- JWT secret
- TOTP encryption key
- Initial admin account settings
- Mail provider API key
- Mail relay authentication password
- Runtime mode and public service settings

## 2. Start Services

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d
```

## 3. Check Runtime Status

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml ps
docker logs --tail=100 sub2api
docker logs --tail=100 smtp2brevo
```

## 4. Configure SMTP In Sub2API

If smtp2brevo is enabled, configure Sub2API SMTP settings according to your relay hostname and certificate setup.

Typical values:

```text
SMTP host: smtp.example.com
SMTP port: 8025
SMTP username: sub2api
SMTP password: value of SMTP_AUTH_PASS
From email: noreply@example.com
From name: Sub2API
TLS: enabled when using a trusted certificate
```

## 5. Production Notes

- Keep `.env` and `.smtp2brevo.env` outside version control.
- Back up PostgreSQL before upgrades.
- Do not expose internal service ports unless required.
- Use pinned image versions for predictable upgrades.
- Review service logs after every deployment.
