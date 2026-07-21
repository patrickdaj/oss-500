#!/usr/bin/env bash
# Tear down Suricata + Zeek. -v removes the log volumes so nothing lingers.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

echo "==> Stopping and removing Suricata + Zeek + volumes"
docker compose -p oss500 down -v

echo "==> Done. Confirm:  docker compose -p oss500 ps"
