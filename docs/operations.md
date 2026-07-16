# Operations Runbook

## Repository-Only Validation

These commands are safe for reviewing a local checkout. They do not deploy anything:

```bash
sh scripts/check-public-safe.sh

cd smtp2brevo
npm ci --ignore-scripts
npm run check
npm test
cd ..

test ! -e .env && test ! -e .smtp2brevo.env || {
  echo "Refusing to overwrite existing private environment files" >&2
  exit 1
}
cleanup() { rm -f .env .smtp2brevo.env; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
cp .env.example .env
cp .smtp2brevo.env.example .smtp2brevo.env
docker compose -f docker-compose.yml -f docker-compose.smtp.yml config --quiet
```

The last block uses placeholder files only to validate Compose rendering. Do not overwrite real environment files on a deployment host.

## Production Preflight

On an intended deployment host, after private values and certificates are ready:

```bash
sh scripts/preflight.sh
```

The preflight validates required values and the pinned application image, rejects a public application bind and unsafe upstream URL modes by default, checks Compose rendering without printing resolved secrets, and checks the relay certificate files. It does not start, stop, or recreate containers.

For a deployment without smtp2brevo, run `ENABLE_SMTP_RELAY=0 sh scripts/preflight.sh`. Set `CHECK_TLS_CERTIFICATES=0` only when relay certificate validation is performed separately. `ALLOW_PUBLIC_BIND=1`, `ALLOW_UNSAFE_UPSTREAM_URLS=1`, and `ALLOW_LARGE_DB_POOL=1` are explicit review overrides, not persistent defaults.

## Read-Only Runtime Inspection

The following commands inspect state without changing services:

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml ps
docker compose -f docker-compose.yml -f docker-compose.smtp.yml logs --tail=100 sub2api
docker compose -f docker-compose.yml -f docker-compose.smtp.yml logs --tail=100 smtp2brevo
docker inspect --format '{{json .State.Health}}' sub2api
curl --fail --silent --show-error http://127.0.0.1:8080/health
```

Avoid publishing complete `docker compose config` output: it may contain resolved secrets.

## Intentional Deployment

The commands below change runtime state. Run them only after approval, backup, review, and preflight:

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml pull sub2api postgres redis
docker compose -f docker-compose.yml -f docker-compose.smtp.yml build --pull smtp2brevo
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d
```

Review health and logs immediately afterward. A repository update should first be tested in a separate checkout or staging directory; do not overwrite a working production directory with an unreviewed worktree.

## Routine Checks

- Confirm all services are healthy.
- Confirm `/health` succeeds through localhost and the public HTTPS endpoint.
- Review error-rate, provider, database, and mail-relay logs without copying personal data into issues.
- Confirm disk space, PostgreSQL backup freshness, and certificate renewal.
- Review pinned image updates and Dependabot pull requests.
- Test restoration periodically; a backup that has never been restored is unverified.

## Incident Priorities

1. Preserve evidence and current configuration.
2. Stop further exposure at the reverse proxy or firewall if necessary.
3. Rotate affected credentials.
4. Restore service from a known revision and verified backup.
5. Document the root cause and add a regression check before redeployment.
