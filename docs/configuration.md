# Configuration Reference

## Configuration Files

| File | Consumer | Purpose | Commit it? |
| --- | --- | --- | --- |
| `.env` | Docker Compose and Sub2API | Images, ports, database, Redis, application settings | No |
| `.smtp2brevo.env` | smtp2brevo only | Brevo, sender, SMTP authentication, limits | No |
| `.env.example` | Operators and CI | Sanitized main template | Yes |
| `.smtp2brevo.env.example` | Operators and CI | Sanitized relay template | Yes |

Compose automatically uses `.env` for interpolation, and `docker-compose.yml` also injects it into Sub2API through `env_file`. This is intentional: application settings documented in the template must reach the container.

`BLINDOT_DEPLOY_CONFIG_VERSION=2` is a compatibility gate for that behavior. Do not add it to an older private environment file until [migration-v2.md](migration-v2.md) has been completed.

## Main Deployment Settings

| Setting | Meaning | Production guidance |
| --- | --- | --- |
| `BLINDOT_RUNTIME_LAYOUT_VERSION` | Persistent executable migration gate | Set to `1` only after preserving an existing runtime |
| `SUB2API_IMAGE` | Core application image | Pin a tested patch tag and repository digest |
| `POSTGRES_IMAGE`, `REDIS_IMAGE` | Data-service images | Change major versions only with a migration plan |
| `BIND_HOST` | Host interface for Sub2API | Keep `127.0.0.1` behind a local proxy |
| `SERVER_PORT` | Host-side application port | Keep aligned with the reverse proxy |
| `JWT_SECRET` | Session-signing secret | Generate once, keep stable, back up securely |
| `TOTP_ENCRYPTION_KEY` | 2FA secret encryption | Generate once, keep stable, back up securely |
| `POSTGRES_PASSWORD` | Database credential | Strong, unique, and private |
| `REDIS_PASSWORD` | Redis credential | Strong and private even on an internal network |
| `SMTP_HOSTNAME` | Relay TLS name and Docker alias | Must match the relay certificate and app SMTP host |

`SERVER_HOST` and the container-side application port are fixed by Compose. `SERVER_PORT` controls only the host-side loopback mapping.

## Capacity Settings

The example values are a starting point, not universal sizing:

- `DATABASE_MAX_OPEN_CONNS` must stay below PostgreSQL capacity after accounting for every application replica and administrative headroom. The 80/20 open/idle defaults leave headroom under the PostgreSQL image's default connection limit for a single instance; preflight requires an explicit capacity-review override above that baseline.
- PostgreSQL server tuning stays at image defaults. Apply measured changes through a reviewed Compose override rather than carrying historical environment values forward.
- `POSTGRES_SHM_SIZE` must fit the actual host or container memory limit.
- `REDIS_POOL_SIZE`, `REDIS_MIN_IDLE_CONNS`, and `REDIS_MAXCLIENTS` should reflect measured concurrency rather than peak guesses.
- Docker stdout/stderr rotation is controlled by `DOCKER_LOG_MAX_SIZE` and `DOCKER_LOG_MAX_FILES`.

Change one group at a time and measure connection saturation, memory pressure, latency, and error rate.

## URL And SSRF Controls

For public multi-user deployments, review these explicitly:

```env
SECURITY_URL_ALLOWLIST_ENABLED=false
SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP=false
SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS=false
SECURITY_URL_ALLOWLIST_UPSTREAM_HOSTS=
```

Enabling a strict allowlist with explicit upstream hostnames gives the strongest control. If the product requires dynamic upstream URLs, keep insecure HTTP and private hosts disabled unless a documented trusted-network use case requires them.

## Relay Settings

Required private values are `BREVO_API_KEY`, `FROM_EMAIL`, and `SMTP_AUTH_PASS`. The relay also supports bounded message size, recipient count, client count, socket timeout, provider timeout, and explicit TLS file paths. See [smtp2brevo.md](smtp2brevo.md).

## Environment Syntax

Use one `KEY=value` entry per line. Docker Compose applies interpolation to unquoted and double-quoted values; single-quoted values are literal. Quote values containing characters such as `$` or `#` appropriately, then validate with:

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml config --quiet
```

Do not publish the full rendered configuration because it can contain resolved credentials.

## Runtime Data

`data/`, `runtime/`, `postgres_data/`, `redis_data/`, logs, certificates, dumps, and backup archives are runtime assets and must stay outside Git. `runtime/sub2api` is the executable used by the web updater; it must remain a regular executable file owned by the container runtime user. See [runtime-image-sync.md](runtime-image-sync.md) before migrating an existing container and [backup-restore.md](backup-restore.md) for consistent backup guidance.
