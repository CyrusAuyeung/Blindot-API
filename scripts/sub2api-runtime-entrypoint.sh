#!/usr/bin/env sh
set -eu

image_binary=${SUB2API_IMAGE_BINARY:-/app/sub2api}
runtime_dir=${SUB2API_RUNTIME_DIR:-/app/runtime}
runtime_binary=${runtime_dir}/sub2api
runtime_uid=${SUB2API_RUNTIME_UID:-1000}
runtime_gid=${SUB2API_RUNTIME_GID:-1000}

if [ "$(id -u)" -ne 0 ]; then
  echo "blindot runtime entrypoint must start as root" >&2
  exit 1
fi

if [ ! -f "$image_binary" ] || [ ! -x "$image_binary" ]; then
  echo "image binary is missing or not executable: $image_binary" >&2
  exit 1
fi

mkdir -p "$runtime_dir"
if [ -L "$runtime_binary" ] || { [ -e "$runtime_binary" ] && [ ! -f "$runtime_binary" ]; }; then
  echo "runtime binary must be a regular file: $runtime_binary" >&2
  exit 1
fi

if [ ! -s "$runtime_binary" ]; then
  seed_path=${runtime_dir}/.sub2api.seed.$$
  trap 'rm -f "$seed_path"' EXIT HUP INT TERM
  cp "$image_binary" "$seed_path"
  chmod 0755 "$seed_path"
  chown "${runtime_uid}:${runtime_gid}" "$seed_path"
  mv "$seed_path" "$runtime_binary"
  trap - EXIT HUP INT TERM
fi

chown "${runtime_uid}:${runtime_gid}" "$runtime_dir" "$runtime_binary"
chmod 0755 "$runtime_binary"

# The upstream entrypoint fixes /app/data permissions and drops privileges.
exec /app/docker-entrypoint.sh "$@"
