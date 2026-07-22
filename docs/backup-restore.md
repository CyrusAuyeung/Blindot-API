# Backup And Restore

## Backup Scope

A recoverable deployment normally needs:

- PostgreSQL logical dump
- `.env` and `.smtp2brevo.env`
- The exact Git revision and image tags
- Reverse-proxy configuration and certificate recovery procedure
- `data/` if it contains application-managed files not stored in PostgreSQL
- `runtime/sub2api` or enough release metadata and hashes to reproduce it
- Redis persistence only if the deployment relies on Redis state that cannot be rebuilt

Store backups outside the repository and outside the deployment host. Encrypt them, restrict access, and define retention.

## PostgreSQL Backup

Run from the deployment directory. The command expands database values inside the container and does not put the password on the command line:

```bash
umask 077
backup_dir="backup-$(date +%F-%H%M%S)"
mkdir "$backup_dir"

docker compose -f docker-compose.yml -f docker-compose.smtp.yml \
  exec -T postgres sh -c \
  'exec pg_dump --format=custom --no-owner --no-privileges -U "$POSTGRES_USER" "$POSTGRES_DB"' \
  > "$backup_dir/sub2api.dump"

cp .env .smtp2brevo.env "$backup_dir/"
git rev-parse HEAD > "$backup_dir/git-revision.txt"
(
  cd "$backup_dir"
  sha256sum .env .smtp2brevo.env sub2api.dump git-revision.txt > SHA256SUMS
)
```

Validate that the dump is readable:

```bash
pg_restore --list "$backup_dir/sub2api.dump" >/dev/null
```

If `pg_restore` is not installed on the host, run the validation with a compatible PostgreSQL client container or on the restore system.

## File And Redis Data

Do not treat a live copy of `postgres_data/` as a consistent database backup. Use `pg_dump` unless a tested PostgreSQL physical-backup procedure is in place.

For `data/` and `redis_data/`, use a filesystem snapshot or a short maintenance window if consistency matters. Redis is not a substitute for PostgreSQL; decide explicitly whether its state must be restored or can be rebuilt.

## Restore Procedure

Test restores in an isolated directory or host first:

1. Check the recorded Git revision and image versions.
2. Restore private configuration with mode `0600`.
3. Start only PostgreSQL and Redis.
4. Restore the dump into an empty target database with a compatible `pg_restore` client.
5. Restore required application files.
6. Start Sub2API and smtp2brevo.
7. Verify health, authentication, representative API calls, mail, and data counts.
8. Open public traffic only after verification.

Database replacement and `pg_restore --clean` are destructive. Use them only against a confirmed restore target with an independently verified backup.

## Dangerous Commands

Never use these as routine troubleshooting commands:

```bash
docker compose down -v
rm -rf data postgres_data redis_data
```

The current stack uses bind-mounted data directories, so removing containers does not by itself validate or erase those directories. Always inspect the resolved target before any deletion.
