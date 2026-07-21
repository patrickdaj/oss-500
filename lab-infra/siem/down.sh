#!/usr/bin/env bash
# Tear down the OSS-500 SIEM. The -v removes the heavy indexer/manager volumes so
# nothing survives overnight (the #1 laptop resource killer).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

echo "==> Stopping the agent (if running)"
docker compose -p oss500 -f agent-compose.yml down -v 2>/dev/null || true

echo "==> Stopping and removing the SIEM stack + volumes"
docker compose -p oss500 down -v

echo "==> Done. Confirm nothing left:  docker compose -p oss500 ps  ·  docker volume ls | grep oss500"
echo "    (Generated certs remain in config/wazuh_indexer_ssl_certs/ — gitignored; delete manually to fully reset.)"
