# Nginx Reverse Proxy Example

This example targets Nginx 1.25.1 or newer and keeps Sub2API on the default loopback binding. Replace the example hostname and certificate paths.

Place the `map` block in the `http` context:

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}
```

Example virtual host:

```nginx
server {
    listen 80;
    server_name api.example.com;

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    http2 on;
    server_name api.example.com;
    server_tokens off;

    ssl_certificate /etc/letsencrypt/live/api.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.example.com/privkey.pem;

    client_max_body_size 256m;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;

        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

For older Nginx releases that do not support `http2 on`, use the HTTP/2 syntax supported by that packaged version.

## Validation

```bash
sudo nginx -t
curl --fail --silent --show-error http://127.0.0.1:8080/health
curl --fail --silent --show-error https://api.example.com/health
```

Keep `client_max_body_size` aligned with `SERVER_MAX_REQUEST_BODY_SIZE` and `GATEWAY_MAX_BODY_SIZE`. Long proxy timeouts and disabled response buffering support streamed model responses.

When a CDN or load balancer sits in front of Nginx, configure trusted proxy addresses before using forwarded client IPs for auditing or rate limiting. Do not trust arbitrary `X-Forwarded-For` input from the public internet.
