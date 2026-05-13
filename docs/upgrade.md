# Upgrade Notes

Use pinned image tags for predictable Sub2API upgrades.

## Upgrade Sub2API

Edit docker-compose.yml and set the desired Sub2API image tag.

Then run:

    docker compose -f docker-compose.yml -f docker-compose.smtp.yml pull sub2api
    docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d sub2api smtp2brevo

## Check Status

    docker compose -f docker-compose.yml -f docker-compose.smtp.yml ps
    docker logs --tail=100 sub2api
    docker logs --tail=100 smtp2brevo

## Backup Before Upgrading

Back up configuration files and database data before upgrading production deployments.

At minimum, back up:

    .env
    .smtp2brevo.env
    docker-compose.yml
    docker-compose.smtp.yml
    PostgreSQL database dump

## Dangerous Commands

Do not run this on production unless you intentionally want to delete volumes and data:

    docker compose down -v

## Rollback

To roll back, restore the previous image tag in docker-compose.yml and recreate Sub2API:

    docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d sub2api smtp2brevo
