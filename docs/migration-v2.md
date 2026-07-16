# Migration To Deployment Configuration V2

This guide is for a future, intentional production adoption of the normalized repository. Completing repository work, opening a pull request, or merging it does not perform this migration.

## Why There Is A Version Gate

Version 2 changes configuration plumbing: the complete main `.env` is injected into Sub2API. Older deployments often contain documented values that Compose never passed to the application, so silently accepting an old file could activate dormant behavior.

The stack therefore requires:

```env
BLINDOT_DEPLOY_CONFIG_VERSION=2
```

Add that value only after every step below has been reviewed. Without it, Compose refuses to render the Sub2API service.

## Behavior Changes To Review

- Sub2API receives all values from the main `.env`, not only a small hard-coded subset.
- New deployments bind Sub2API to loopback by default.
- smtp2brevo uses a Docker DNS alias instead of a fixed container IP and `extra_hosts` entry.
- The Compose project owns its bridge network; an externally declared fixed network is no longer required.
- PostgreSQL keeps the official image's server defaults. Historical `POSTGRES_MAX_CONNECTIONS`, `POSTGRES_SHARED_BUFFERS`, `POSTGRES_EFFECTIVE_CACHE_SIZE`, and `POSTGRES_MAINTENANCE_WORK_MEM` values are deliberately not applied.
- The application database pool starts at 80 open and 20 idle connections for a single instance.
- Redis authentication and `REDIS_MAXCLIENTS` are applied by an explicit container command.
- Container logs are bounded by Docker log rotation.
- smtp2brevo uses a lockfile, supported Node.js LTS runtime, health check, bounded inputs, and a read-only container filesystem.

## Preparation

1. Record the current Git or file revision, image IDs, Compose output, container health, and network ownership.
2. Make a verified PostgreSQL backup and a protected copy of both private environment files.
3. Use a separate clean checkout to review v2. Do not point that checkout at production bind-mounted data.
4. Read the Sub2API image release notes and confirm database migration compatibility.

Do not publish rendered Compose output or environment diffs containing credentials.

## Rebuild The Environment File

Start with the new `.env.example` and transfer reviewed values one key at a time. Do not append the new key to an old file and assume compatibility.

Pay special attention to:

- Preserve the existing PostgreSQL password, database name, JWT secret, and TOTP encryption key.
- Set `BIND_HOST=127.0.0.1` when the reverse proxy is local.
- Keep insecure HTTP and private-host upstream access disabled unless an approved trusted-network dependency requires them.
- Review every logging, gateway scheduling, aggregation, retention, OAuth, and operations variable because it will now reach Sub2API.
- Use `DATABASE_MAX_OPEN_CONNS=80` and `DATABASE_MAX_IDLE_CONNS=20` as the initial single-instance values unless measured capacity justifies another setting.
- Remove historical PostgreSQL server-tuning keys; use a reviewed Compose override if tuning is later required.
- Decide whether Redis authentication can be introduced in the same maintenance window, and keep the application and server password identical.
- Confirm `SMTP_HOSTNAME` matches the certificate and the application SMTP setting.

Set `BLINDOT_DEPLOY_CONFIG_VERSION=2` last.

## Validate Without Deploying

```bash
sh scripts/check-public-safe.sh
sh scripts/preflight.sh
```

Also review the service and network model without printing secrets:

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml config --quiet
```

Confirm that the existing network is Compose-owned by the intended `COMPOSE_PROJECT_NAME`. If it was created manually or belongs to another project, plan the network transition before any `up` command.

## Intentional Cutover

Schedule a maintenance window. A full `docker compose up -d --build` may recreate containers to apply environment, port-binding, security, network-alias, and logging changes. Follow [backup-restore.md](backup-restore.md), [deployment.md](deployment.md), and [operations.md](operations.md).

After cutover, verify:

- Container health and PostgreSQL/Redis connectivity
- Local and public `/health`
- Authentication and existing TOTP accounts
- Representative model requests and streaming
- Scheduling, aggregation, billing, and retention behavior
- Verification and password-reset email
- Direct origin port is not publicly reachable

## Rollback

Keep the prior Compose files and private environment files together with the pre-migration database backup. If v2 activated an incompatible application behavior or schema migration, restoring only the old Compose file may be insufficient; use the matching database backup and image revision in an isolated recovery procedure.
