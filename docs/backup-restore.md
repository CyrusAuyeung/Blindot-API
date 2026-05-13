# Backup And Restore

## Backup Targets

Before upgrades or major configuration changes, back up:

```text
.env
.smtp2brevo.env
docker-compose.yml
docker-compose.smtp.yml
PostgreSQL database dump
```

## Example PostgreSQL Backup

Adjust container names, database name, and username to match your deployment.

```bash
DB_PASS="CHANGE_ME"

docker exec -e PGPASSWORD="$DB_PASS" postgres \
  pg_dump -U sub2api -d sub2api | gzip > sub2api-db-$(date +%F-%H%M%S).sql.gz
```

## Example File Backup

```bash
tar czf sub2api-config-$(date +%F-%H%M%S).tar.gz \
  .env \
  .smtp2brevo.env \
  docker-compose.yml \
  docker-compose.smtp.yml
```

## Restore Notes

A restore should normally happen in this order:

1. Stop the application service.
2. Restore configuration files.
3. Restore PostgreSQL data if needed.
4. Start PostgreSQL and Redis.
5. Start Sub2API and smtp2brevo.
6. Check logs and application health.

## Warnings

Do not run destructive volume commands unless data deletion is intended.

```bash
docker compose down -v
```
