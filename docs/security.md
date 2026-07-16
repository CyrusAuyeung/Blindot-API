# Security Notes

## Exposure Boundary

- Keep `BIND_HOST=127.0.0.1` when a reverse proxy runs on the same host.
- Expose only required public ports, normally 80 and 443.
- Do not publish PostgreSQL, Redis, or smtp2brevo ports.
- Restrict SSH, Docker socket access, and deployment-directory permissions.
- Treat the reverse proxy or CDN as part of the trust boundary and configure forwarded IP handling deliberately.

## Secrets And Runtime Data

Never commit real environment files, runtime `config.yaml`, certificates, database dumps, runtime directories, or backup archives. Use mode `0600` for private configuration and keep encrypted backups outside the host.

Before committing:

```bash
sh scripts/check-public-safe.sh
```

The script checks candidate file names, ignore rules, several common credential formats, and the Git history available in the checkout. CI fetches full history for this check. It is a guardrail, not proof that content is safe, and it does not rewrite history. Review every diff manually.

If a secret enters Git, rotate it immediately before attempting history cleanup. Assume forks, caches, CI logs, and clones may retain it.

## Application Controls

- Keep stable, independent values for `JWT_SECRET` and `TOTP_ENCRYPTION_KEY`.
- Use strong unique PostgreSQL, Redis, admin, SMTP, and provider credentials.
- Keep insecure HTTP and private-host URL access disabled unless a documented trusted use case requires them.
- Prefer an explicit upstream-host allowlist for public multi-user deployments when operationally feasible.
- Review registration, payment, moderation, quota, and administrative policies before public access.

## Mail Relay

The relay requires implicit TLS and authentication, has bounded inputs and timeouts, and avoids message metadata in logs. Keep the Brevo API key dedicated and minimally scoped where the provider supports it. Certificate private keys remain read-only inside the container.

## Supply Chain

- Keep the Sub2API application on an explicit reviewed patch tag.
- Review base-image and dependency updates before merging Dependabot pull requests.
- Use `npm ci` with the committed lockfile for relay builds.
- Run `npm audit --omit=dev`, relay tests, Compose validation, and the public-safety check in CI.
- Treat third-party container images as external software and follow their advisories and release notes.

## Logs And Privacy

Container logs are rotated. The relay does not log recipients, subjects, bodies, credentials, or Brevo response bodies. Apply equivalent retention and access controls to Sub2API, reverse-proxy, CDN, and database logs because they may contain user identifiers or request metadata.

See the private reporting process in [../SECURITY.md](../SECURITY.md).
