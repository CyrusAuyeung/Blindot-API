# smtp2brevo Mail Relay

`smtp2brevo` is a small authenticated, implicit-TLS SMTP server that converts Sub2API transactional mail into Brevo HTTPS API requests. It is useful when outbound SMTP ports are unavailable but HTTPS egress works.

## Network Design

```text
Sub2API -> SMTP_HOSTNAME:8025 -> smtp2brevo -> api.brevo.com:443
```

`SMTP_HOSTNAME` is registered as an alias on the private Compose network. The application therefore validates the expected TLS hostname without a fixed container IP, `extra_hosts`, or a pre-created external network.

The relay has no host port mapping. Do not add one on a public interface.

## Brevo Preparation

1. Verify the sending domain.
2. Publish and verify SPF, DKIM, and DMARC.
3. Verify the sender used by `FROM_EMAIL`.
4. Create a dedicated API key and store it only in `.smtp2brevo.env`.

## Configuration

```env
BREVO_API_KEY=CHANGE_ME
FROM_EMAIL=noreply@example.com
FROM_NAME=Blindot API
REPLY_TO=support@example.com
SMTP_PORT=8025
SMTP_AUTH_USER=sub2api
SMTP_AUTH_PASS=CHANGE_ME
SMTP_MAX_MESSAGE_BYTES=10485760
SMTP_MAX_RECIPIENTS=1
SMTP_MAX_CLIENTS=20
SMTP_SOCKET_TIMEOUT_MS=60000
BREVO_TIMEOUT_MS=15000
```

`SMTP_HOSTNAME` stays in the main `.env` because both Compose and the relay need it. Default TLS paths derive from that hostname.

## Security Properties

- Authentication is mandatory and supports `PLAIN` and `LOGIN` only inside implicit TLS.
- Credentials are compared without ordinary string equality.
- Message size, recipients, clients, socket duration, and Brevo request duration are bounded.
- Provider response bodies, recipients, subjects, and message content are not written to relay logs.
- The container filesystem is read-only, Linux capabilities are dropped, and only the selected hostname's certificate directories are mounted read-only.
- Shutdown is graceful for normal `SIGTERM` and `SIGINT` events.

The relay is intended for single-recipient Sub2API text/HTML transactional messages. Attachments are rejected instead of being silently dropped. Raising `SMTP_MAX_RECIPIENTS` should be a deliberate privacy review because every envelope recipient is submitted in the Brevo `to` list.

## Start And Verify

```bash
docker compose -f docker-compose.yml -f docker-compose.smtp.yml up -d --build smtp2brevo
docker compose -f docker-compose.yml -f docker-compose.smtp.yml ps smtp2brevo
docker compose -f docker-compose.yml -f docker-compose.smtp.yml logs --tail=100 smtp2brevo
```

The health check performs a local TLS handshake. It confirms that the listener and certificate loaded; it does not send an email or validate Brevo credentials.

The certificate is read at process startup. After a successful certificate renewal, intentionally recreate only `smtp2brevo` in a controlled window so the relay loads the renewed files, then repeat the health and delivery checks.

Complete verification requires a test message from the Sub2API dashboard and confirmation in Brevo delivery logs.

## Development Checks

```bash
cd smtp2brevo
npm ci --ignore-scripts
npm run check
npm test
npm audit --omit=dev
```
