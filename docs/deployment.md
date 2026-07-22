# Deployment Guide

> Commands in this guide change a deployment host. Repository edits and CI checks do not deploy production automatically.

## 1. Requirements

- Linux host with Docker Engine and Docker Compose v2
- A reverse proxy and a public HTTPS certificate for the API hostname
- A certificate for `SMTP_HOSTNAME` when smtp2brevo is enabled
- A verified Brevo sender and API key
- Enough memory and disk for PostgreSQL, Redis, logs, and backups

## 2. Prepare A Release Directory

Use a clean, reviewed Git revision rather than an arbitrary working tree:

```bash
mkdir -p data runtime postgres_data redis_data
cp .env.example .env
cp .smtp2brevo.env.example .smtp2brevo.env
chmod 600 .env .smtp2brevo.env
```

Generate independent secrets, for example with `openssl rand -hex 32`. Replace every placeholder in both environment files. Never copy production values back into the example files.

For an existing deployment, do not simply add the configuration version to an old file. Complete [migration-v2.md](migration-v2.md) first.

## 3. Prepare DNS And Certificates

The API hostname should terminate HTTPS at the reverse proxy. `BIND_HOST` defaults to `127.0.0.1`, so the application is reachable by the local proxy but not directly from the public network.

When smtp2brevo is enabled, the certificate for `SMTP_HOSTNAME` must exist at:

```text
/etc/letsencrypt/live/<SMTP_HOSTNAME>/privkey.pem
/etc/letsencrypt/live/<SMTP_HOSTNAME>/fullchain.pem
```

The relay mounts only that hostname's `live/` and `archive/` certificate directories read-only, which preserves standard Certbot symlinks without exposing unrelated host keys. Custom container paths can be set with `SMTP_TLS_KEY_PATH` and `SMTP_TLS_CERT_PATH`, together with a matching read-only volume override.

## 4. Run Preflight

```bash
sh scripts/preflight.sh
```

Preflight checks required values, the pinned application image, loopback binding, upstream URL safety modes, Compose rendering, and relay certificate files. It does not start or alter containers.

## 5. Start The Stack

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml pull sub2api postgres redis
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d --build
```

For a deployment without the relay, run `ENABLE_SMTP_RELAY=0 sh scripts/preflight.sh`, use only `docker-compose.yml`, and manage outbound mail separately.

## 6. Verify Health

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml ps
docker compose -f docker-compose.yml -f docker-compose.smtp.yml logs --tail=100 sub2api
docker compose -f docker-compose.yml -f docker-compose.smtp.yml logs --tail=100 smtp2brevo
curl --fail --silent --show-error http://127.0.0.1:8080/health
```

Also verify the public HTTPS health endpoint through the reverse proxy. Do not continue a cutover when a required container is unhealthy.

For an existing container that has already used the web updater, preserve its running executable before adopting the `runtime/` mount. Follow [runtime-image-sync.md](runtime-image-sync.md); starting the new Compose definition with an empty runtime directory would otherwise seed it from the selected image.

## 7. Configure Application Mail

Configure Sub2API with the same values used by the relay:

```text
SMTP host: value of SMTP_HOSTNAME
SMTP port: 8025
SMTP username: value of SMTP_AUTH_USER
SMTP password: value of SMTP_AUTH_PASS
Security: implicit TLS / SSL
From address: value of FROM_EMAIL
```

Send both a verification email and a password-reset email before enabling public registration.

## 8. Complete The Public Edge

Configure the reverse proxy, request-size limit, streaming timeouts, CDN behavior, and firewall. Only required public ports, normally 80 and 443, should be reachable from the internet. PostgreSQL, Redis, and smtp2brevo have no host port mapping.

See [nginx.md](nginx.md), [production-checklist.md](production-checklist.md), and [operations.md](operations.md).
