# smtp2brevo

smtp2brevo is a small SMTP-to-Brevo relay for Sub2API deployments.

It is useful when a VPS provider blocks outbound SMTP ports such as 25, 465, 587, or 2525.

## Flow

    Sub2API -> smtp2brevo -> Brevo HTTPS API -> recipient inbox

## Required Brevo Setup

1. Verify your sending domain in Brevo.
2. Configure SPF, DKIM, and DMARC.
3. Add and verify a sender email address.
4. Generate a Brevo API key.

## Environment

Create the relay environment file:

    cp .smtp2brevo.env.example .smtp2brevo.env

Example variables:

    BREVO_API_KEY=CHANGE_ME
    FROM_EMAIL=noreply@example.com
    FROM_NAME=Sub2API
    REPLY_TO=support@example.com
    SMTP_PORT=8025
    SMTP_AUTH_USER=sub2api
    SMTP_AUTH_PASS=CHANGE_ME

## TLS

If Sub2API requires SMTP authentication, use TLS with a trusted certificate.

A common setup is:

1. Create a DNS record such as smtp.example.com.
2. Issue a Lets Encrypt certificate for that hostname.
3. Mount the certificate into the smtp2brevo container.
4. Make Sub2API resolve that hostname to the relay container inside Docker.

## Security

- Do not expose port 8025 to the public internet.
- Keep .smtp2brevo.env private.
- Rotate SMTP_AUTH_PASS if it is leaked.
- Rotate BREVO_API_KEY if it is leaked.
