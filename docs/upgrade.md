# Upgrade And Rollback

A GitHub update does not update production. Promotion to a deployment host must be an explicit, reviewed operation. A Sub2API web-console update changes the persistent runtime executable but does not mutate its immutable Docker image.

## Before Upgrading

1. Read the Sub2API release and migration notes.
2. Record the current Git revision, image IDs, and health state.
3. Create and verify a PostgreSQL backup.
4. Review the repository diff and resolved Compose model without publishing secrets.
5. Run `sh scripts/preflight.sh`.

## Upgrade Sub2API

Set the reviewed image tag in the private `.env`:

```env
SUB2API_IMAGE=weishaw/sub2api:<reviewed-version>@sha256:<reviewed-digest>
```

Then change only the application service:

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml pull sub2api
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d --no-deps sub2api
```

Check container health, migrations, logs, login, and representative API requests before declaring success.

For deployments that allow web-console updates, use the persistent runtime mount and host-side reconciler described in [runtime-image-sync.md](runtime-image-sync.md). It only pins and recreates from an official image whose binary exactly matches the already approved runtime, and it keeps traffic on a validated canary during primary recreation.

## Upgrade smtp2brevo

```bash
cd smtp2brevo
npm ci --ignore-scripts
npm test
cd ..

docker compose -f docker-compose.yml -f docker-compose.smtp.yml build --pull smtp2brevo
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d --no-deps smtp2brevo
```

Send a test email after the health check passes.

## Database And Redis Images

Upgrade PostgreSQL and Redis separately from the application. A major PostgreSQL upgrade requires a tested logical restore or `pg_upgrade` plan; changing the image tag alone is not a migration strategy.

## Rollback

For a code-only failure with no incompatible data migration, restore the previous `SUB2API_IMAGE` value and recreate only Sub2API.

If the new version changed the schema incompatibly, an old image may not work with the new database. Restore the matching pre-upgrade database backup in an isolated recovery procedure. Confirm the rollback path from upstream release notes before the upgrade, not during the incident.

Do not use `docker compose down -v` during upgrades or rollback.
