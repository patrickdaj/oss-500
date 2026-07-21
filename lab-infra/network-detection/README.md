# lab-infra/network-detection — Suricata + Zeek (Docker Compose)

Network security monitoring for Domain 4 (`nid-*`): **Suricata** (signature IDS/IPS — alerts/blocks on known-bad) and **Zeek** (network-analysis framework — rich protocol logs for behavioral hunting). Both read the same traffic (a mirror interface or a replayed PCAP). Docker Compose appliance under project `oss500`. Backs the [d4-network-detection](../../labs/d4-network-detection.md) lab.

**SC-500 correspondence:** Azure Firewall Premium IDPS / network threat detection (Suricata) · network security monitoring — NSG/VNet flow logs + Traffic Analytics, the behavioral telemetry Defender/Sentinel hunt over (Zeek).

## Footprint

Light (~1 GB) relative to the SIEM/observability stacks. If you want Suricata's `eve.json` and Zeek logs to flow into Wazuh/OpenSearch (`siem-hunt`), do that as a follow-on and mind total RAM — don't run this and the SIEM together without headroom.

## Layout

| File | Purpose | Objective |
|---|---|---|
| `up.sh` / `down.sh` | `docker compose -p oss500` up/down | — |
| `docker-compose.yml` | `suricata` + `zeek` containers on the same traffic source | `nid-suricata`, `nid-zeek` |
| `suricata/suricata.yaml` | Suricata config (AF-PACKET IDS; commented IPS/NFQUEUE alternative) | `nid-suricata` |
| `suricata/rules/local.rules` | Custom detection signature (the rule you fire) | `nid-suricata` |
| `zeek/local.zeek` | Zeek site policy (enable JSON logs, load protocol analyzers) | `nid-zeek` |
| `pcaps/` | Drop a test PCAP here to replay (see note) | both |

## Usage

```bash
./up.sh
# Update signatures + fire an alert:
docker compose -p oss500 exec suricata suricata-update
docker compose -p oss500 exec suricata suricata -r /pcaps/test.pcap -l /var/log/suricata
docker compose -p oss500 exec suricata grep '"event_type":"alert"' /var/log/suricata/eve.json
# Behavioral logs:
docker compose -p oss500 exec zeek ls /usr/local/zeek/logs/current/
./down.sh
```

### Test traffic

No malicious binary is shipped. Two safe options the lab uses:
- **Benign test indicator**: from a host on the monitored network, `curl -s http://testmynids.org/uid/index.html` — a Emerging-Threats test signature (and the custom `local.rules` rule) fires on it. Nothing malicious happens.
- **Replay a PCAP**: place any capture at `pcaps/test.pcap` and replay with `suricata -r` / `zeek -r`. Capture your own with `tcpdump -w pcaps/test.pcap` while running the curl above.

## Modes (exam-critical)

`suricata.yaml` runs **IDS mode** (AF-PACKET, passive — *alerts only*). The commented `nfqueue`/inline block shows **IPS mode** (in-path, `drop`/`reject` actually block, but Suricata becomes a failure point). A mirror/tap can never block; only inline can.

## Images

`jasonish/suricata` (OISF community image) and `zeek/zeek`. Everything runs under the `oss500` compose project.
