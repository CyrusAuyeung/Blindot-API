# Configuration Notes

This document summarizes the main configuration files used by the deployment.

## `.env`

The `.env` file configures Sub2API, PostgreSQL, Redis, runtime behavior, authentication, and optional integrations.

Important values usually include:

```text
POSTGRES_PASSWORD
JWT_SECRET
TOTP_ENCRYPTION_KEY
ADMIN_EMAIL
ADMIN_PASSWORD
SERVER_HOST
SERVER_PORT
SERVER_MODE
TZ
```

Use generated values for secrets. Avoid short, reused, or human-readable passwords.

## `.smtp2brevo.env`

The `.smtp2brevo.env` file configures the SMTP-to-Brevo relay.

Example:

```env
BREVO_API_KEY=CHANGE_ME
FROM_EMAIL=noreply@example.com
FROM_NAME=Sub2API
REPLY_TO=support@example.com
SMTP_PORT=8025
SMTP_AUTH_USER=sub2api
SMTP_AUTH_PASS=CHANGE_ME
```

## Docker Compose Files

`docker-compose.yml` defines the main services:

```text
sub2api
postgres
redis
```

`docker-compose.smtp.yml` extends the stack with:

```text
smtp2brevo
```

Use both files together when the mail relay is part of the deployment:

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d
```

## Image Tags

Use pinned image tags for production deployments when possible. This makes upgrades and rollbacks predictable.

## Runtime Data

Runtime data should not be committed to version control. Keep database files, Redis dumps, logs, and backup archives outside the public repository.
