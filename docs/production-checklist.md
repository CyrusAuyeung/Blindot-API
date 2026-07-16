# Production Checklist

## Release And Configuration

- [ ] Deployment uses a reviewed Git revision with a clean worktree.
- [ ] `SUB2API_IMAGE` is an explicit reviewed version.
- [ ] `.env` and `.smtp2brevo.env` contain no example placeholders and use mode `0600`.
- [ ] `sh scripts/preflight.sh` passes.
- [ ] The rendered Compose configuration was validated without publishing it.

## Network And HTTPS

- [ ] `BIND_HOST=127.0.0.1` unless a documented firewall design requires otherwise.
- [ ] Only required public ports are reachable.
- [ ] PostgreSQL, Redis, and smtp2brevo are not publicly exposed.
- [ ] API HTTPS certificate is valid and renews automatically.
- [ ] `SMTP_HOSTNAME` matches a valid relay certificate.
- [ ] Reverse-proxy request-size and streaming timeout settings match the application.
- [ ] CDN or proxy client-IP trust is explicitly configured.

## Secrets And Access

- [ ] Database, Redis, JWT, TOTP, admin, SMTP, and provider credentials are strong and independent.
- [ ] Administrator MFA and recovery procedures are configured.
- [ ] Deployment host, SSH, Docker, and backup access follow least privilege.
- [ ] Credential rotation owners and procedures are documented.

## Data And Recovery

- [ ] A fresh PostgreSQL logical backup exists outside the host.
- [ ] Backup encryption, access control, retention, and integrity checks are in place.
- [ ] A restore has been tested against the current release.
- [ ] Disk-space and certificate-expiry monitoring is configured.
- [ ] Rollback compatibility and migration notes were reviewed.

## Application

- [ ] `/health` succeeds locally and through public HTTPS.
- [ ] Login and representative API requests succeed.
- [ ] Registration, quota, billing, moderation, and risk-control policies were reviewed.
- [ ] Insecure HTTP and private-host URL access are disabled unless explicitly required.
- [ ] Application, reverse-proxy, CDN, and database log retention protects user privacy.

## Mail

- [ ] Sending domain and sender are verified.
- [ ] SPF, DKIM, and DMARC pass.
- [ ] Verification and password-reset emails succeed.
- [ ] smtp2brevo is healthy and has no public port mapping.
- [ ] Relay limits and Brevo timeout are appropriate for transactional mail.

## Repository

- [ ] `sh scripts/check-public-safe.sh` passes.
- [ ] Relay syntax checks, tests, and dependency audit pass.
- [ ] GitHub Actions validation passes.
- [ ] The final diff contains no private domain, address, credential, certificate, dump, or runtime data.
