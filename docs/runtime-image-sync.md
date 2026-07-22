# Runtime And Container Image Reconciliation

## Why Two Versions Can Appear

A Docker image is immutable. The Sub2API web updater replaces the running
executable, but it cannot rewrite the parent image. Without a persistent runtime
mount, the updated executable also disappears when the container is recreated.

This deployment launches Sub2API from `runtime/sub2api`, which is bind-mounted
at `/app/runtime/sub2api`. On the first start, the runtime entrypoint copies the
image's `/app/sub2api` into that directory. Later web-console updates therefore
survive container recreation.

The image reconciler deliberately keeps the two operations separate:

```text
web-console update
  -> runtime/sub2api changes
  -> timer reads the latest official GitHub release
  -> pull the matching official Docker image
  -> require identical runtime/image SHA-256 hashes
  -> pin the image by tag and repository digest
  -> validate a loopback canary
  -> move Nginx to the canary
  -> recreate and validate the primary container
  -> move Nginx back to the primary
```

The reconciler never initiates an application update. The web update is the
operator approval gate. If the official image is missing, its binary differs,
or any validation fails before cutover, the current primary keeps serving.

## Safety Properties

- The application container is not given the Docker socket or host privileges.
- Only `weishaw/sub2api` release images are considered by default.
- The runtime and image binaries must have exactly the same SHA-256 hash.
- `.env` receives an immutable `tag@sha256:digest` reference.
- Compose is rendered successfully before Nginx is changed.
- The canary listens only on `127.0.0.1:28080`.
- Nginx configuration is syntax-checked and atomically reloaded.
- A failure after cutover keeps the verified canary available for recovery.

This protects availability, not database compatibility. Continue to review
release notes and create a verified PostgreSQL backup before approving an update
that may contain schema changes.

## Migrate An Existing Container

Run these commands from the reviewed deployment directory. They change runtime
state and require the normal backup and maintenance approval.

First preserve the executable that the current container is actually running:

```bash
install -d -m 0755 runtime
docker cp sub2api:/app/sub2api runtime/sub2api.import
install -o 1000 -g 1000 -m 0755 \
  runtime/sub2api.import runtime/sub2api
rm runtime/sub2api.import
sha256sum runtime/sub2api
```

Install the new Compose mount and scripts, then validate their syntax:

```bash
sh -n scripts/sub2api-runtime-entrypoint.sh
sh -n scripts/reconcile-sub2api-image.sh
```

Only after `runtime/sub2api` has been preserved, add this migration gate to the
private `.env`:

```env
BLINDOT_RUNTIME_LAYOUT_VERSION=1
```

Compose intentionally refuses to render without that confirmation, preventing
an empty runtime directory from silently seeding an older configured image.
Now run the full deployment preflight:

```bash
sh scripts/preflight.sh
```

The private `.env` should pin a reviewed image by tag and digest. The reconciler
will write the exact current release reference only after its hash check passes.
Its staging mode pulls, verifies, and updates `.env` without recreating a
container:

```bash
sudo scripts/reconcile-sub2api-image.sh
```

Apply the first reconciliation only after the database backup is verified:

```bash
sudo scripts/reconcile-sub2api-image.sh --apply
```

Verify local and public health, the container image ID, application logs, login,
and representative API requests before enabling the timer.

## Enable Reconciliation After Web Updates

The supplied systemd timer checks ten minutes after the previous run, with a
small randomized delay:

```bash
sudo install -m 0644 \
  deploy/systemd/blindot-sub2api-image-sync.service \
  deploy/systemd/blindot-sub2api-image-sync.timer \
  /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now blindot-sub2api-image-sync.timer
sudo systemctl start blindot-sub2api-image-sync.service
```

The unit assumes the deployment directory is `/root/sub2api-deploy`, Nginx has
exactly one `proxy_pass http://127.0.0.1:8080;` in
`/etc/nginx/sites-enabled/api.blindot.org`, and both Compose files are enabled.
Use a reviewed systemd drop-in and the documented `SUB2API_*` environment
overrides for a different layout.

Inspect it without changing the application:

```bash
systemctl status blindot-sub2api-image-sync.timer
systemctl list-timers blindot-sub2api-image-sync.timer
journalctl -u blindot-sub2api-image-sync.service -n 100 --no-pager
```

## Failure Recovery

Before Nginx cutover, failure leaves the primary untouched. After cutover, the
script reasserts the canary route and leaves `sub2api-image-canary` running. Do
not remove that container until the primary is healthy and public traffic has
been moved back.

After fixing the primary, verify it directly, replace the single canary upstream
with the primary upstream, and reload Nginx:

```bash
curl --fail --silent --show-error http://127.0.0.1:8080/health
sudo sed -i \
  's#proxy_pass http://127.0.0.1:28080;#proxy_pass http://127.0.0.1:8080;#' \
  /etc/nginx/sites-enabled/api.blindot.org
sudo nginx -t
sudo systemctl reload nginx
curl --fail --silent --show-error https://api.blindot.org/health
docker rm -f sub2api-image-canary
```

`.env.before-image-sync` retains the immediately preceding private environment
file with the same permissions. It contains secrets, is ignored by Git, and must
be protected like `.env`.
