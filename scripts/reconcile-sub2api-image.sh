#!/usr/bin/env sh
set -eu

mode=stage
case "${1:-}" in
  "") ;;
  --apply) mode=apply ;;
  -h|--help)
    cat <<'EOF'
Usage: scripts/reconcile-sub2api-image.sh [--apply]

Without --apply, pull and pin the official image only when its binary exactly
matches the web-updated runtime binary. With --apply, use a temporary canary
and an atomic Nginx reload while recreating the primary container.
EOF
    exit 0
    ;;
  *) echo "unknown argument: $1" >&2; exit 2 ;;
esac

deploy_dir=${BLINDOT_DEPLOY_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
container_name=${SUB2API_CONTAINER_NAME:-sub2api}
image_repository=${SUB2API_IMAGE_REPOSITORY:-weishaw/sub2api}
runtime_binary=${SUB2API_RUNTIME_BINARY:-$deploy_dir/runtime/sub2api}
github_api=${SUB2API_RELEASE_API:-https://api.github.com/repos/Wei-Shaw/sub2api/releases/latest}
canary_name=${SUB2API_CANARY_NAME:-sub2api-image-canary}
canary_port=${SUB2API_CANARY_PORT:-28080}
primary_port=${SUB2API_PRIMARY_PORT:-8080}
nginx_site=${SUB2API_NGINX_SITE:-/etc/nginx/sites-enabled/api.blindot.org}
public_host=${SUB2API_PUBLIC_HOST:-api.blindot.org}
lock_file=${SUB2API_SYNC_LOCK_FILE:-/run/lock/blindot-sub2api-image-sync.lock}
compose_files=${SUB2API_COMPOSE_FILES:--f docker-compose.yml -f docker-compose.smtp.yml}

log() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

fail() {
  log "ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

read_env_value() {
  key=$1
  awk -v key="$key" '
    index($0, key "=") == 1 {
      value = substr($0, length(key) + 2)
      sub(/\r$/, "", value)
    }
    END { print value }
  ' .env
}

set_env_value() {
  key=$1
  value=$2
  temp_file=$(mktemp "$deploy_dir/.env.image-sync.XXXXXX")
  awk -v key="$key" -v value="$value" '
    BEGIN { replaced = 0 }
    index($0, key "=") == 1 {
      if (!replaced) {
        print key "=" value
        replaced = 1
      }
      next
    }
    { print }
    END {
      if (!replaced) print key "=" value
    }
  ' .env > "$temp_file"
  chmod --reference=.env "$temp_file"
  chown --reference=.env "$temp_file"
  cp -p .env .env.before-image-sync
  mv "$temp_file" .env
}

wait_for_container_health() {
  name=$1
  attempts=${2:-90}
  count=0
  status=
  while [ "$count" -lt "$attempts" ]; do
    status=$(docker inspect "$name" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)
    case "$status" in
      healthy|running) return 0 ;;
      exited|dead)
        docker logs --tail 120 "$name" >&2 || true
        return 1
        ;;
    esac
    count=$((count + 1))
    sleep 1
  done
  docker logs --tail 120 "$name" >&2 || true
  return 1
}

local_https_health() {
  curl -fsS --max-time 15 \
    --resolve "${public_host}:443:127.0.0.1" \
    "https://${public_host}/health" >/dev/null
}

is_sha256() {
  value=$1
  [ "${#value}" -eq 64 ] || return 1
  case "$value" in
    *[!0-9a-f]*) return 1 ;;
  esac
}

for command_name in awk chmod chown cp curl docker flock grep head mktemp mv rm sed sha256sum tr; do
  require_command "$command_name"
done

cd "$deploy_dir"
[ -f .env ] || fail "missing $deploy_dir/.env"
[ -f docker-compose.yml ] || fail "missing docker-compose.yml"
[ -s "$runtime_binary" ] || fail "runtime binary is missing: $runtime_binary"
[ ! -L "$runtime_binary" ] || fail "runtime binary must not be a symlink"
docker inspect "$container_name" >/dev/null 2>&1 || fail "container not found: $container_name"

mkdir -p "$(dirname "$lock_file")"
exec 9>"$lock_file"
if ! flock -n 9; then
  log "another image reconciliation is already running"
  exit 0
fi

release_json=$(curl -fsSL --max-time 30 \
  -H 'Accept: application/vnd.github+json' \
  -H 'User-Agent: Blindot-API-image-reconciler' \
  "$github_api") || fail "failed to query the latest Sub2API release"
target_tag=$(
  printf '%s\n' "$release_json" |
    tr ',' '\n' |
    sed -n 's/^[[:space:]{]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' |
    head -n 1
)
target_version=${target_tag#v}
case "$target_version" in
  ''|*[!0-9.]*) fail "invalid release tag returned by GitHub: $target_tag" ;;
esac

current_image_id=$(docker inspect "$container_name" --format '{{.Image}}')
target_tagged_image=${image_repository}:${target_version}
configured_image=$(read_env_value SUB2API_IMAGE)

if docker image inspect "$target_tagged_image" >/dev/null 2>&1; then
  target_image_id=$(docker image inspect "$target_tagged_image" --format '{{.Id}}')
else
  target_image_id=
fi

case "$configured_image" in
  "${target_tagged_image}"|"${target_tagged_image}@"*) configured_matches=1 ;;
  *) configured_matches=0 ;;
esac

if [ "$configured_matches" -eq 1 ] && [ -n "$target_image_id" ] && [ "$current_image_id" = "$target_image_id" ]; then
  log "container image is already aligned with Sub2API ${target_version}"
  exit 0
fi

log "checking official image ${target_tagged_image}"
docker pull "$target_tagged_image" >/dev/null
target_image_id=$(docker image inspect "$target_tagged_image" --format '{{.Id}}')
repo_digest=$(
  docker image inspect "$target_tagged_image" --format '{{range .RepoDigests}}{{println .}}{{end}}' |
    awk -v prefix="${image_repository}@" 'index($0, prefix) == 1 { print; exit }'
)
case "$repo_digest" in
  *@sha256:*) ;;
  *) fail "official image has no immutable repository digest" ;;
esac
target_image=${target_tagged_image}@${repo_digest#*@}

runtime_hash=$(sha256sum "$runtime_binary" | awk '{print $1}')
image_hash=$(docker run --rm --entrypoint sha256sum "$target_tagged_image" /app/sub2api | awk '{print $1}')
is_sha256 "$runtime_hash" || fail "failed to calculate the runtime binary hash"
is_sha256 "$image_hash" || fail "failed to calculate the image binary hash"

if [ "$runtime_hash" != "$image_hash" ]; then
  log "runtime binary does not match ${target_tagged_image}; waiting for an operator-approved web update"
  exit 0
fi

if [ "$configured_image" != "$target_image" ]; then
  set_env_value SUB2API_IMAGE "$target_image"
  log "staged SUB2API_IMAGE=${target_image}"
fi

if [ "$mode" != apply ]; then
  exit 0
fi

for command_name in nginx sed systemctl; do
  require_command "$command_name"
done
[ -f "$nginx_site" ] || fail "Nginx site not found: $nginx_site"

# Validate the exact Compose model before touching the reverse proxy.
# shellcheck disable=SC2086
docker compose $compose_files config --quiet

if [ "$current_image_id" = "$target_image_id" ]; then
  log "running container already uses the matching official image"
  exit 0
fi

primary_proxy="proxy_pass http://127.0.0.1:${primary_port};"
canary_proxy="proxy_pass http://127.0.0.1:${canary_port};"
primary_count=$(grep -F -c "$primary_proxy" "$nginx_site" || true)
canary_count=$(grep -F -c "$canary_proxy" "$nginx_site" || true)
[ "$canary_count" -eq 0 ] || fail "Nginx already points at the canary; manual recovery is required"
[ "$primary_count" -eq 1 ] || fail "expected exactly one primary proxy_pass in $nginx_site"

network_name=$(
  docker inspect "$container_name" --format '{{range $name, $network := .NetworkSettings.Networks}}{{println $name}}{{end}}' |
    awk 'NF { print; exit }'
)
data_source=$(docker inspect "$container_name" --format '{{range .Mounts}}{{if eq .Destination "/app/data"}}{{.Source}}{{end}}{{end}}')
[ -n "$network_name" ] || fail "could not determine the Sub2API Docker network"
[ -d "$data_source" ] || fail "could not determine the Sub2API data mount"

canary_env=$(mktemp)
nginx_backup=$(mktemp)
nginx_on_canary=0
cleanup() {
  status=$?
  trap - EXIT HUP INT TERM
  set +e
  rm -f "$canary_env"
  if [ "$nginx_on_canary" -eq 0 ]; then
    docker rm -f "$canary_name" >/dev/null 2>&1 || true
    rm -f "$nginx_backup"
  else
    # Reassert the known-good canary route even when failure happened while
    # attempting to restore the primary configuration.
    fallback_temp=$(mktemp "$(dirname "$nginx_site")/.blindot-nginx-recovery.XXXXXX")
    sed "s#${primary_proxy}#${canary_proxy}#" "$nginx_backup" > "$fallback_temp"
    chmod --reference="$nginx_site" "$fallback_temp"
    chown --reference="$nginx_site" "$fallback_temp"
    mv "$fallback_temp" "$nginx_site"
    if nginx -t && systemctl reload nginx && local_https_health; then
      log "Nginx remains on verified canary ${canary_name}:${canary_port}; backup: ${nginx_backup}" >&2
    else
      log "ERROR: automatic canary recovery failed; inspect Nginx and ${canary_name} immediately" >&2
    fi
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

chmod 0600 "$canary_env"
docker inspect "$container_name" --format '{{range .Config.Env}}{{println .}}{{end}}' > "$canary_env"
cp -p "$nginx_site" "$nginx_backup"
docker rm -f "$canary_name" >/dev/null 2>&1 || true

log "starting canary ${canary_name} on 127.0.0.1:${canary_port}"
docker run -d \
  --name "$canary_name" \
  --init \
  --ulimit nofile=100000:100000 \
  --env-file "$canary_env" \
  --network "$network_name" \
  -p "127.0.0.1:${canary_port}:8080" \
  -v "${data_source}:/app/data:rw" \
  "$target_image" >/dev/null

wait_for_container_health "$canary_name" 120 || fail "canary did not become healthy"
curl -fsS --max-time 10 "http://127.0.0.1:${canary_port}/health" >/dev/null || fail "canary health endpoint failed"

nginx_temp=$(mktemp "$(dirname "$nginx_site")/.blindot-nginx.XXXXXX")
sed "s#${primary_proxy}#${canary_proxy}#" "$nginx_site" > "$nginx_temp"
chmod --reference="$nginx_site" "$nginx_temp"
chown --reference="$nginx_site" "$nginx_temp"
mv "$nginx_temp" "$nginx_site"
nginx_on_canary=1
if ! nginx -t; then
  cp -p "$nginx_backup" "$nginx_site"
  nginx_on_canary=0
  nginx -t || true
  fail "Nginx rejected the canary configuration"
fi
systemctl reload nginx
local_https_health || fail "public HTTPS health failed after switching to canary"

log "recreating primary container from ${target_image}"
# shellcheck disable=SC2086
docker compose $compose_files up -d --no-deps sub2api
wait_for_container_health "$container_name" 120 || fail "primary container did not become healthy"
curl -fsS --max-time 10 "http://127.0.0.1:${primary_port}/health" >/dev/null || fail "primary health endpoint failed"
primary_image_id=$(docker inspect "$container_name" --format '{{.Image}}')
[ "$primary_image_id" = "$target_image_id" ] || fail "primary container did not use the pinned official image"
primary_hash=$(docker exec "$container_name" sha256sum /app/runtime/sub2api | awk '{print $1}')
[ "$primary_hash" = "$image_hash" ] || fail "primary runtime hash differs from the official image"

cp -p "$nginx_backup" "$nginx_site"
nginx -t || fail "Nginx rejected the restored primary configuration"
systemctl reload nginx
local_https_health || fail "public HTTPS health failed after switching back to primary"
nginx_on_canary=0

docker rm -f "$canary_name" >/dev/null 2>&1 || true
rm -f "$nginx_backup"
log "Sub2API runtime and container image are aligned at ${target_version}"
