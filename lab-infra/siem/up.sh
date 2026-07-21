#!/usr/bin/env bash
# Bring up the OSS-500 Wazuh + OpenSearch SIEM (siem-*) via Docker Compose.
# HEAVIEST stack in the course — run it completely alone (see README).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

command -v docker >/dev/null || { echo "docker required"; exit 1; }

# --- credentials ---
[ -f .env ] || { echo "Copy .env.example -> .env and set strong passwords first."; exit 1; }

# --- kernel prereq for the indexer (siem-deploy) ---
if [ "$(uname)" = "Linux" ]; then
  cur=$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)
  if [ "$cur" -lt 262144 ]; then
    echo "ERROR: vm.max_map_count=$cur too low for the indexer."
    echo "  Run: sudo sysctl -w vm.max_map_count=262144   (persist in /etc/sysctl.conf)"
    exit 1
  fi
fi

# --- generate TLS certs once (siem-deploy) ---
if [ ! -f config/wazuh_indexer_ssl_certs/root-ca.pem ]; then
  echo "==> Generating TLS certificates"
  mkdir -p config/wazuh_indexer_ssl_certs
  docker compose -p oss500 -f certs-compose.yml run --rm generator
fi

echo "==> Starting Wazuh manager + indexer + dashboard (docker compose -p oss500)"
docker compose -p oss500 up -d

echo "==> Waiting for the stack to become healthy (indexer takes longest)..."
echo "    Watch:  docker compose -p oss500 ps"
echo "==> Done. Dashboard: https://localhost:5601  (self-signed; log in with .env creds)"
echo "    Onboard an agent:  docker compose -p oss500 -f agent-compose.yml up -d"
