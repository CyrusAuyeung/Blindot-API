# Nginx Reverse Proxy Example

This example shows a basic HTTPS reverse proxy in front of Sub2API.

Replace `api.example.com` and the upstream port with values that match your deployment.

```nginx
server {
    listen 80;
    server_name api.example.com;

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name api.example.com;

    ssl_certificate /etc/letsencrypt/live/api.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.example.com/privkey.pem;

    client_max_body_size 100m;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
    }
}
```

## Notes

- Keep internal service ports private where possible.
- Use HTTPS for the public entry point.
- Increase `client_max_body_size` if file upload or large requests are needed.
- Long `proxy_read_timeout` values are useful for streaming responses.
