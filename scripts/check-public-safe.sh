#!/usr/bin/env sh
set -eu

echo "Checking for forbidden files..."

for path in .env .smtp2brevo.env data backup backups postgres_data redis_data; do
  if [ -e "$path" ]; then
    echo "Forbidden path found: $path"
    exit 1
  fi
done

echo "Checking for private key files..."

if find . -type f \( -name "*.pem" -o -name "*.key" -o -name "*.sql" -o -name "*.sql.gz" -o -name "*.tar.gz" \) | grep -q .; then
  echo "Forbidden file type found."
  find . -type f \( -name "*.pem" -o -name "*.key" -o -name "*.sql" -o -name "*.sql.gz" -o -name "*.tar.gz" \)
  exit 1
fi

echo "Scanning for private identifiers and common secret patterns..."

if grep -RInE "blindot|104\\.248|Cyrus|Ouyang|noreply@blindot|support@blindot|BEGIN .*PRIVATE KEY|sk-|ghp_|xkeysib-" . --exclude-dir=.git --exclude=check-public-safe.sh; then
  echo "Potential private data or secret found."
  exit 1
fi

echo "Public safety check passed."
