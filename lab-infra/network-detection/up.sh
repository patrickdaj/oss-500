#!/usr/bin/env bash
# Bring up Suricata (IDS) + Zeek (NSM) on the same traffic source (nid-*).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

command -v docker >/dev/null || { echo "docker required"; exit 1; }
mkdir -p pcaps

echo "==> Starting Suricata + Zeek (docker compose -p oss500-netdet)"
docker compose -p oss500-netdet up -d

echo "==> Pulling the Emerging Threats Open ruleset (the detection content)"
docker compose -p oss500-netdet exec suricata suricata-update || \
  echo "    (suricata-update may need a moment after first start; re-run if it errors)"

cat <<'EOF'
==> Done.
  Fire an alert (from a host on the monitored network):
    curl -s http://testmynids.org/uid/index.html
  See Suricata alerts:
    docker compose -p oss500-netdet exec suricata grep '"event_type":"alert"' /var/log/suricata/eve.json
  See Zeek behavioral logs:
    docker compose -p oss500-netdet exec zeek ls /usr/local/zeek/logs/current/
EOF
