# Production Checklist

Use this checklist before exposing the service publicly.

## DNS And HTTPS

- [ ] Public domain points to the server.
- [ ] HTTPS certificate is installed and renews automatically.
- [ ] Reverse proxy forwards requests to Sub2API.
- [ ] Internal service ports are not publicly exposed unless required.

## Secrets

- [ ] `POSTGRES_PASSWORD` is strong and unique.
- [ ] `JWT_SECRET` is set and stable.
- [ ] `TOTP_ENCRYPTION_KEY` is set and stable if 2FA is used.
- [ ] Mail provider API key is stored only in local environment files.
- [ ] `.env` and `.smtp2brevo.env` are not committed.

## Data

- [ ] PostgreSQL backup procedure is tested.
- [ ] Backup files are stored outside the public repository.
- [ ] Restore procedure is documented for the deployment.

## Mail

- [ ] Sending domain is verified with the mail provider.
- [ ] SPF, DKIM, and DMARC are configured.
- [ ] Test email succeeds from the application dashboard.
- [ ] Password reset email succeeds.

## Application

- [ ] Admin account is secured.
- [ ] Registration policy is configured.
- [ ] Payment settings are verified if payment is enabled.
- [ ] Moderation or risk-control settings are configured if public users are allowed.
- [ ] Logs are reviewed after startup.

## Repository

- [ ] `./scripts/check-public-safe.sh` passes.
- [ ] No production domain, IP, API key, private key, or database dump is committed.
