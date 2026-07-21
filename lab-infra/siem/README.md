# lab-infra/siem — Wazuh + OpenSearch SIEM (Docker Compose)

The full SIEM for Domain 4 (`siem-*`): the **Wazuh manager** (detection engine + agent server + REST API), the **Wazuh indexer** (an OpenSearch fork — the search/storage tier), and the **Wazuh dashboard** (an OpenSearch-Dashboards fork). Deployed as a Docker Compose appliance under project `oss500`. Backs the [d4-siem-wazuh](../../labs/d4-siem-wazuh.md) lab and integrates **Sigma** detection-as-code.

**SC-500 correspondence:** Microsoft Sentinel (manager + indexer/dashboard) · Sentinel data connectors / ASIM normalization (agents + decoders) · Sentinel analytics rules (Sigma) · KQL threat hunting (OpenSearch Query DSL) · Sentinel automation rules & playbooks / SOAR (Wazuh active response).

## ⚠ Heaviest stack in the course — run completely alone

The indexer is a JVM/Lucene search engine and is **memory-hungry**. **Budget ~4–6 GB RAM, give Docker ≥ 6 GB, and run nothing else** — tear down the observability stack and any kind workloads first. Do **not** run this the same day as the observability lab on the reference host.

Linux kernel requirement (the indexer will not start without it):
```bash
sudo sysctl -w vm.max_map_count=262144      # add to /etc/sysctl.conf to persist
```
`up.sh` checks this and stops with instructions if it's too low.

## Layout

| File | Purpose | Objective |
|---|---|---|
| `up.sh` / `down.sh` | `docker compose -p oss500` up/down (+ cert bootstrap) | `siem-deploy` |
| `.env.example` | Indexer/admin/API credential template → copy to `.env` (gitignored) | `siem-deploy` |
| `docker-compose.yml` | wazuh.manager + wazuh.indexer + wazuh.dashboard (single-node) | `siem-deploy` |
| `agent-compose.yml` | A Wazuh agent container to onboard/enroll | `siem-collect` |
| `config/wazuh_indexer/` , `certs-compose.yml` | Bootstrap TLS certs for the indexer/manager/dashboard | `siem-deploy` |
| `config/custom-rules.xml` | Native Wazuh detection rules (brute-force correlation) | `siem-detect` |
| `config/ossec.conf` | Manager config incl. **active response** (`firewall-drop`) | `siem-response` |
| `sigma/ssh-bruteforce.yml` | Portable Sigma rule (converts to OpenSearch DSL / KQL) | `siem-detect` |

## Usage

```bash
cp .env.example .env          # set strong INDEXER_PASSWORD, API_PASSWORD, DASHBOARD creds
./up.sh                       # generates certs, then docker compose -p oss500 up -d
# dashboard: https://localhost:5601  (self-signed; log in with your .env creds)
# ...do labs/d4-siem-wazuh.md: onboard agent, Sigma->query, hunt with DSL, active response...
./down.sh                     # docker compose -p oss500 down -v  (removes heavy volumes)
```

## Ports

| Port | Service |
|---|---|
| `1514/tcp` | agent event channel (manager) |
| `1515/tcp` | agent enrollment |
| `55000/tcp` | Wazuh manager REST API |
| `9200/tcp` | Wazuh indexer (OpenSearch API) |
| `5601/tcp` | Wazuh dashboard (HTTPS) |

## Secrets hygiene

Only `.env.example` is committed; the real `.env` and generated `config/wazuh_indexer_ssl_certs/` are gitignored. **Change every default credential** — shipping Wazuh/OpenSearch defaults is a classic finding (`siem-deploy` hardening). All containers run under the `oss500` compose project; find them with `docker compose -p oss500 ps`.

## Images

`wazuh/wazuh-manager`, `wazuh/wazuh-indexer`, `wazuh/wazuh-dashboard` (the `wazuh/wazuh-docker` single-node deployment), pinned in `docker-compose.yml`.
