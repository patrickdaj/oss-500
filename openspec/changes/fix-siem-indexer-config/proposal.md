## Why

The OSS-500 SIEM stack (`lab-infra/siem/`) does not run as shipped. Bringing it up with `docker compose -p oss500-siem up -d` makes the `wazuh.indexer` container **crash-loop** (13+ restarts) at boot:

```
OpenSearchSecurityException: Error while initializing transport SSL layer from PEM:
AccessControlException: access denied ("java.io.FilePermission"
"/etc/wazuh-indexer/certs/indexer.pem" "read")
```

Root cause: `lab-infra/siem/config/` ships only `certs.yml`, `ossec.conf`, and `custom-rules.xml` — it is **missing the indexer's `opensearch.yml` and `internal_users.yml`** that the upstream `wazuh-docker` single-node deployment (which this stack is "based on") mounts. Consequences:

- **No `opensearch.yml`** → the indexer falls back to package defaults that look for certs at `/etc/wazuh-indexer/certs/indexer.pem`, while `docker-compose.yml` mounts them at `/usr/share/wazuh-indexer/certs/wazuh.indexer.pem` (path **and** filename mismatch) → SSL transport init fails → crash loop.
- **No `internal_users.yml`** → the indexer's admin password can't be set from `.env` (`INDEXER_PASSWORD` is passed only to the manager and dashboard, which are *clients* of the indexer, never to the indexer itself), so even once it boots, the `.env` "set STRONG passwords" instruction can't take effect.

This was discovered by actually bringing the stack up while verifying `fix-lab-correctness-blockers` task 5.4 (the end-to-end alert check), which is blocked on this defect. The stack has never been runnable, so the `d4-siem-wazuh` lab's headline observable — a crafted brute-force producing a parsed alert — cannot be reached.

## What Changes

- Add the missing indexer security config: `lab-infra/siem/config/wazuh_indexer/opensearch.yml` (transport + HTTP SSL cert paths/filenames aligned to the certs `docker-compose.yml` actually mounts, plus the opensearch-security plugin settings) and `internal_users.yml` (bcrypt hashes for `admin` and `kibanaserver` matching the `.env` passwords).
- Add the dashboard config the dashboard tier needs to reach the indexer/API: `config/wazuh_dashboard/opensearch_dashboards.yml` (+ `wazuh.yml` if required).
- Mount these files in `docker-compose.yml` and ensure `securityadmin` initialization applies `internal_users.yml` so the `.env` admin/dashboard passwords are the real credentials.
- Make the `.env`-set indexer password actually authoritative (resolve the wiring gap), or document precisely which password the stack uses.
- Document the `vm.max_map_count >= 262144` requirement for the indexer on **Docker Desktop / macOS** (`up.sh` only checks it on Linux hosts, so the requirement is silently unmet in the Docker VM).
- Verify the full detect path end-to-end on a host with disk headroom and update the `d4-siem-wazuh` lab's `Validation status` note to `host-validated` for the alert observable.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `lab-infrastructure`: the reproducible local SIEM stack SHALL actually start — the indexer must boot healthy from the shipped config (not crash-loop), with its admin credentials set from `.env`, so the deploy–verify–destroy loop the capability promises is real for `lab-infra/siem/`.
- `hands-on-labs`: the `d4-siem-wazuh` lab's concrete verification (crafted brute-force → parsed alert document) SHALL be reachable and, once run on a host, marked `host-validated` rather than `host-pending`.

## Impact

- Affected specs: `lab-infrastructure` (SIEM stack must start), `hands-on-labs` (the SIEM alert observable becomes reachable).
- Affected files (at implementation time): new `lab-infra/siem/config/wazuh_indexer/opensearch.yml` + `internal_users.yml`, new `lab-infra/siem/config/wazuh_dashboard/opensearch_dashboards.yml` (+ `wazuh.yml`), edits to `lab-infra/siem/docker-compose.yml` (mounts + securityadmin), `lab-infra/siem/up.sh` (macOS `vm.max_map_count` note/handling), `lab-infra/siem/README.md`, and `labs/d4-siem-wazuh.md` (validation status).
- Unblocks `fix-lab-correctness-blockers` task 5.4 (the SIEM end-to-end verification is delegated to this change).
- Requires a host with adequate disk (the images are ~9 GB and the indexer needs room for indices) and RAM for the JVM indexer — this is the "run it completely alone" stack.
