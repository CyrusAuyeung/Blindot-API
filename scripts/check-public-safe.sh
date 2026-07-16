#!/usr/bin/env sh
set -eu

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

echo "Checking tracked file names..."

candidate_files=$(git ls-files --cached --others --exclude-standard)

tracked_env_files=$(
  printf '%s\n' "$candidate_files" |
    grep -E '(^|/)\.env($|\.)|(^|/)\.smtp2brevo\.env($|\.)|(^|/)[^/]+\.env($|\.)|(^|/)\.envrc$|^config\.ya?ml$' |
    grep -vE '(^|/)\.env\.example$|(^|/)\.smtp2brevo\.env\.example$' || true
)

if [ -n "$tracked_env_files" ]; then
  echo "Tracked environment or environment-backup file found:" >&2
  echo "$tracked_env_files" >&2
  exit 1
fi

tracked_private_files=$(
  printf '%s\n' "$candidate_files" |
    grep -E '(^|/)(data|backup|backups|postgres_data|redis_data|\.direnv)/|(^|/)(id_rsa|id_ed25519)$|\.(pem|key|p12|pfx|jks|sql|dump|db|sqlite|sqlite3|tar\.gz|sql\.gz)$' || true
)

if [ -n "$tracked_private_files" ]; then
  echo "Tracked runtime data, key, or backup file found:" >&2
  echo "$tracked_private_files" >&2
  exit 1
fi

echo "Checking ignore rules for local secrets..."

for path in .env production.env production.env.backup .env.before-upgrade .envrc .smtp2brevo.env .smtp2brevo.env.backup config.yaml config.yml private.key certificate.pem identity.p12 backup.dump runtime.sqlite3; do
  if ! git check-ignore -q --no-index "$path"; then
    echo "Expected secret path is not ignored: $path" >&2
    exit 1
  fi
done

echo "Scanning tracked text for common credential formats..."

credential_pattern='BEGIN (RSA |OPENSSH |EC |DSA |PGP )?PRIVATE KEY|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xkeysib-[A-Za-z0-9_-]{16,}|sk-[A-Za-z0-9_-]{32,}|AKIA[0-9A-Z]{16}'

if git grep --untracked -n -I -E "$credential_pattern" \
  -- . ':!scripts/check-public-safe.sh'; then
  echo "Potential credential found in tracked content." >&2
  exit 1
fi

echo "Scanning available Git history..."

history_credential_commits=$(
  git log --all --extended-regexp -G"$credential_pattern" \
    --format='%H' -- . ':(exclude)scripts/check-public-safe.sh' |
    sort -u || true
)

if [ -n "$history_credential_commits" ]; then
  echo "Potential credential pattern found in Git history commits:" >&2
  echo "$history_credential_commits" >&2
  exit 1
fi

history_private_files=$(
  git log --all --name-only --pretty=format: |
    grep -E '(^|/)\.env($|\.)|(^|/)\.smtp2brevo\.env($|\.)|(^|/)[^/]+\.env($|\.)|(^|/)\.envrc$|^config\.ya?ml$|(^|/)(data|backup|backups|postgres_data|redis_data|\.direnv)/|(^|/)(id_rsa|id_ed25519)$|\.(pem|key|p12|pfx|jks|sql|dump|db|sqlite|sqlite3|tar\.gz|sql\.gz)$' |
    grep -vE '(^|/)\.env\.example$|(^|/)\.smtp2brevo\.env\.example$' |
    sort -u || true
)

if [ -n "$history_private_files" ]; then
  echo "Potential private file found in Git history:" >&2
  echo "$history_private_files" >&2
  exit 1
fi

echo "Public repository safety check passed."
