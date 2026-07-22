#!/usr/bin/env sh
set -eu

compose_files="-f docker-compose.yml"
enable_smtp_relay=${ENABLE_SMTP_RELAY:-1}

case "$enable_smtp_relay" in
  1) compose_files="$compose_files -f docker-compose.smtp.yml" ;;
  0) ;;
  *)
    echo "ENABLE_SMTP_RELAY must be 0 or 1" >&2
    exit 1
    ;;
esac

read_env_value() {
  file=$1
  key=$2
  awk -v key="$key" '
    index($0, key "=") == 1 {
      value = substr($0, length(key) + 2)
      sub(/\r$/, "", value)
      first = substr(value, 1, 1)
      last = substr(value, length(value), 1)
      single_quote = sprintf("%c", 39)
      if ((first == "\"" && last == "\"") ||
          (first == single_quote && last == single_quote)) {
        value = substr(value, 2, length(value) - 2)
      }
    }
    END { print value }
  ' "$file"
}

require_file() {
  if [ ! -f "$1" ]; then
    echo "Missing required file: $1" >&2
    exit 1
  fi
}

require_value() {
  file=$1
  key=$2
  value=$(read_env_value "$file" "$key")

  case "$value" in
    ""|CHANGE_ME|change_this_*|*example.com*)
      echo "$key in $file must be set to a production value" >&2
      exit 1
      ;;
  esac
}

positive_integer() {
  file=$1
  key=$2
  default_value=$3
  value=$(read_env_value "$file" "$key")
  value=${value:-$default_value}

  case "$value" in
    0|*[!0-9]*)
      echo "$key in $file must be a positive integer" >&2
      exit 1
      ;;
  esac

  printf '%s' "$value"
}

require_file .env
require_file scripts/sub2api-runtime-entrypoint.sh
require_file scripts/reconcile-sub2api-image.sh
if [ "$enable_smtp_relay" = "1" ]; then
  require_file .smtp2brevo.env
fi

for script in scripts/sub2api-runtime-entrypoint.sh scripts/reconcile-sub2api-image.sh; do
  if [ ! -x "$script" ]; then
    echo "Required deployment script is not executable: $script" >&2
    exit 1
  fi
done

for key in BLINDOT_DEPLOY_CONFIG_VERSION BLINDOT_RUNTIME_LAYOUT_VERSION POSTGRES_PASSWORD REDIS_PASSWORD JWT_SECRET TOTP_ENCRYPTION_KEY ADMIN_EMAIL; do
  require_value .env "$key"
done

config_version=$(read_env_value .env BLINDOT_DEPLOY_CONFIG_VERSION)
if [ "$config_version" != "2" ]; then
  echo "BLINDOT_DEPLOY_CONFIG_VERSION must be 2 after completing docs/migration-v2.md" >&2
  exit 1
fi

runtime_layout_version=$(read_env_value .env BLINDOT_RUNTIME_LAYOUT_VERSION)
if [ "$runtime_layout_version" != "1" ]; then
  echo "BLINDOT_RUNTIME_LAYOUT_VERSION must be 1 after completing docs/runtime-image-sync.md" >&2
  exit 1
fi

if [ "$enable_smtp_relay" = "1" ]; then
  require_value .env SMTP_HOSTNAME
  for key in BREVO_API_KEY FROM_EMAIL SMTP_AUTH_PASS; do
    require_value .smtp2brevo.env "$key"
  done
fi

for key in SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS; do
  value=$(read_env_value .env "$key")
  case "$value" in
    true|TRUE|True|1)
      if [ "${ALLOW_UNSAFE_UPSTREAM_URLS:-0}" != "1" ]; then
        echo "$key must remain disabled; set ALLOW_UNSAFE_UPSTREAM_URLS=1 only for a reviewed trusted-network use case" >&2
        exit 1
      fi
      ;;
  esac
done

bind_host=$(read_env_value .env BIND_HOST)
bind_host=${bind_host:-127.0.0.1}
case "$bind_host" in
  127.0.0.1|::1|localhost) ;;
  *)
    if [ "${ALLOW_PUBLIC_BIND:-0}" != "1" ]; then
      echo "BIND_HOST must be loopback; set ALLOW_PUBLIC_BIND=1 only after a firewall review" >&2
      exit 1
    fi
    ;;
esac

sub2api_image=$(read_env_value .env SUB2API_IMAGE)
image_name=${sub2api_image##*/}
case "$image_name" in
  ""|latest|*:latest)
    echo "SUB2API_IMAGE must use an explicit reviewed version tag" >&2
    exit 1
    ;;
  *:*|*@sha256:*) ;;
  *)
    echo "SUB2API_IMAGE must use an explicit reviewed version tag or digest" >&2
    exit 1
    ;;
esac

database_max_open=$(positive_integer .env DATABASE_MAX_OPEN_CONNS 80)
database_max_idle=$(positive_integer .env DATABASE_MAX_IDLE_CONNS 20)
if [ "$database_max_idle" -gt "$database_max_open" ]; then
  echo "DATABASE_MAX_IDLE_CONNS must not exceed DATABASE_MAX_OPEN_CONNS" >&2
  exit 1
fi
if [ "$database_max_open" -gt 80 ] && [ "${ALLOW_LARGE_DB_POOL:-0}" != "1" ]; then
  echo "DATABASE_MAX_OPEN_CONNS exceeds the safe single-host baseline; set ALLOW_LARGE_DB_POOL=1 only after database capacity review" >&2
  exit 1
fi

redis_pool_size=$(positive_integer .env REDIS_POOL_SIZE 4096)
redis_min_idle=$(positive_integer .env REDIS_MIN_IDLE_CONNS 256)
redis_maxclients=$(positive_integer .env REDIS_MAXCLIENTS 10000)
if [ "$redis_min_idle" -gt "$redis_pool_size" ]; then
  echo "REDIS_MIN_IDLE_CONNS must not exceed REDIS_POOL_SIZE" >&2
  exit 1
fi
if [ "$redis_pool_size" -gt "$redis_maxclients" ]; then
  echo "REDIS_POOL_SIZE must not exceed REDIS_MAXCLIENTS" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 is required" >&2
  exit 1
fi

# Render without printing the configuration because it contains secrets.
# shellcheck disable=SC2086
docker compose $compose_files config --quiet

if [ "$enable_smtp_relay" = "1" ] && [ "${CHECK_TLS_CERTIFICATES:-1}" = "1" ]; then
  smtp_hostname=$(read_env_value .env SMTP_HOSTNAME)
  key_path=$(read_env_value .smtp2brevo.env SMTP_TLS_KEY_PATH)
  cert_path=$(read_env_value .smtp2brevo.env SMTP_TLS_CERT_PATH)
  key_path=${key_path:-/etc/letsencrypt/live/$smtp_hostname/privkey.pem}
  cert_path=${cert_path:-/etc/letsencrypt/live/$smtp_hostname/fullchain.pem}

  require_file "$key_path"
  require_file "$cert_path"
fi

echo "Deployment preflight passed."
