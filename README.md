# Blindot API

Public deployment template for a Sub2API-based AI API relay service.

This repository documents the sanitized deployment structure behind Blindot API.
It uses Sub2API as the core API relay gateway, with PostgreSQL, Redis, and an optional smtp2brevo mail relay.

No production secrets, database files, user data, logs, certificates, or private configuration are included.

## Components

- Sub2API
- PostgreSQL
- Redis
- smtp2brevo mail relay
- Docker Compose configuration
- Example environment files

## Architecture

API flow:

    Client or WebUI -> Sub2API -> Upstream AI providers

Email flow:

    Sub2API -> smtp2brevo -> Brevo HTTPS API -> User inbox

## Files

    docker-compose.yml          Main Sub2API stack
    docker-compose.smtp.yml     Optional smtp2brevo relay extension
    .env.example                Example Sub2API environment file
    .smtp2brevo.env.example     Example smtp2brevo environment file
    smtp2brevo/                 SMTP-to-Brevo relay source

## Security

Never commit real secrets or runtime data.

Do not commit:

    .env
    .smtp2brevo.env
    data/
    backup/
    backups/
    postgres_data/
    redis_data/
    *.pem
    *.key
    *.sql
    *.sql.gz
    *.tar.gz

## Quick Start

    cp .env.example .env
    cp .smtp2brevo.env.example .smtp2brevo.env
    docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d

## Update

    docker compose -f docker-compose.yml -f docker-compose.smtp.yml pull sub2api
    docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d sub2api smtp2brevo

## License

This repository is a deployment template. Check upstream projects for their own licenses.
