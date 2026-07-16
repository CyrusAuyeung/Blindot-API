# Architecture And Repository Boundary

## What This Repository Contains

This repository is the public deployment and operations layer for Blindot API. It contains:

- Docker Compose definitions for Sub2API, PostgreSQL, Redis, and smtp2brevo
- The small smtp2brevo relay implementation
- Environment-variable templates, validation scripts, and operational documentation
- CI checks that validate the repository without deploying it

The Sub2API application source is not part of this repository. It is consumed as the versioned container image selected by `SUB2API_IMAGE`.

## What Changes Production

A local edit, commit, pull request, or push to this repository does not by itself change the running service. Production changes only when an operator intentionally transfers or pulls a reviewed revision into a deployment directory and runs deployment commands there. This repository intentionally contains no automatic production-deployment workflow.

Keep these states separate:

```text
Git repository                 Deployment host
---------------------------    ---------------------------------
Compose and relay source       Checked-out/released revision
Example environment files      Private .env files
Documentation and CI           Certificates and reverse proxy
No runtime data                data/, postgres_data/, redis_data/
```

## Request And Data Flow

```text
Client
  -> CDN / reverse proxy / HTTPS
  -> 127.0.0.1:${SERVER_PORT}
  -> Sub2API
     -> PostgreSQL (persistent business data)
     -> Redis (cache, queues, runtime state)
     -> Upstream model providers
```

Only the reverse proxy should normally accept public traffic. PostgreSQL and Redis have no host port mapping. Sub2API binds to loopback by default through `BIND_HOST=127.0.0.1`.

## Mail Flow

```text
Sub2API
  -> implicit TLS SMTP on the private Compose network
  -> smtp2brevo
  -> Brevo HTTPS API
  -> recipient mailbox
```

`SMTP_HOSTNAME` is both the certificate hostname and a Docker network alias. This removes the need for a fixed container IP or an externally pre-created Docker network.

## Configuration Flow

The main `.env` has two roles:

1. Docker Compose uses it for interpolation, such as image tags and host bindings.
2. Compose injects it into Sub2API through `env_file`, so documented application settings actually reach the container.

The private `.smtp2brevo.env` is injected only into the relay. Neither file belongs in Git.

Version 2 adds `BLINDOT_DEPLOY_CONFIG_VERSION=2` as an explicit compatibility gate. An older deployment environment cannot render the new stack until an operator has reviewed the migration guide.

## Persistence

The stack uses bind-mounted directories so a deployment remains inspectable and portable:

- `data/` for Sub2API application data
- `postgres_data/` for PostgreSQL
- `redis_data/` for Redis persistence

These directories are deliberately ignored by Git. PostgreSQL should be backed up with `pg_dump`; copying a live database directory is not a substitute for a consistent database backup.

## Compatibility Principles

- The Sub2API patch version is explicit and changed deliberately.
- Database and Redis major versions are explicit.
- Container names and persistent directory locations remain stable for existing single-host deployments.
- Internal service discovery uses Compose service names and network aliases, not private IP addresses.
- CI validates configuration and images but never connects to or deploys production.
