## Context

`lab-infra/siem/` is described as "Based on wazuh/wazuh-docker (single-node)" but ships a reduced `config/` (only `certs.yml`, `ossec.conf`, `custom-rules.xml`). The upstream single-node deployment also mounts `config/wazuh_indexer/wazuh.indexer.yml` (→ `opensearch.yml`), `config/wazuh_indexer/internal_users.yml`, and `config/wazuh_dashboard/*.yml`. Those were dropped here, so the indexer boots on package defaults whose cert paths (`/etc/wazuh-indexer/certs/indexer.pem`) don't match the mounted certs (`/usr/share/wazuh-indexer/certs/wazuh.indexer.pem`), and the admin password has no source. Net: the indexer crash-loops on SSL init and the stack is unusable. This was confirmed live (13+ restarts, exact `FilePermission` error) while trying to verify `fix-lab-correctness-blockers` 5.4.

## Goals / Non-Goals

**Goals:**
- Make `lab-infra/siem/` start from its own shipped files, with the indexer healthy and its admin credential set from `.env`.
- Verify the `d4-siem-wazuh` alert observable end-to-end on a host and mark it `host-validated`.
- Keep the lab's teaching surface (custom rule 100100, active response, Sigma section) unchanged — this fixes the substrate, not the pedagogy.

**Non-Goals:**
- No move to a multi-node indexer or a different SIEM. Single-node Wazuh stays.
- No re-architecting the manager/dashboard beyond the config needed to authenticate against a working indexer.
- Not pinning a new Wazuh version — keep `WAZUH_VERSION` (4.9.2) unless a version-specific config incompatibility forces it.

## Decisions

**Decision 1 — Restore the upstream single-node indexer config, aligned to the mounted cert names.** Add `config/wazuh_indexer/opensearch.yml` modeled on the wazuh-docker 4.9 single-node `wazuh.indexer.yml`, but with `plugins.security.ssl.transport.pemcert_filepath` / `pemkey_filepath` / `pemtrustedcas_filepath` and the http equivalents set to the **filenames this repo mounts** (`wazuh.indexer.pem`, `wazuh.indexer.key`, `root-ca.pem`) under the mount dir the compose uses. Rationale: least-surprise, matches the "based on wazuh-docker" lineage; the only real edit vs upstream is reconciling the cert filenames the OSS-500 certs-generator produces. Alternative considered: rename the mounted certs to the upstream defaults (`indexer.pem`) in `docker-compose.yml` instead of editing paths in `opensearch.yml`. Either works; editing `opensearch.yml` keeps the generator/`certs.yml` untouched.

**Decision 2 — Ship `internal_users.yml` with hashes matching `.env`, applied via securityadmin.** Provide `internal_users.yml` with bcrypt hashes for `admin` and `kibanaserver`. Because the hash must match the `.env` password, document/automate hash generation (the indexer image ships `plugins/opensearch-security/tools/hash.sh`), or ship hashes for the `.env.example` defaults and instruct regeneration when the learner changes them. Rationale: this is the piece that makes "set STRONG passwords" real. Trade-off: a hash baked to the example password means a learner who edits `.env` must regenerate the hash and re-run securityadmin — call this out explicitly rather than letting it silently mismatch.

**Decision 3 — Verify with the existing rule chain, no new detection content.** The crafted-log path (rule 5710 ×6 → 100100) already exists; this change only needs the stack to run so that path can be exercised and the alert queried via `_search`. Keep the verification identical to what `d4-siem-wazuh` already documents.

**Decision 4 — Treat macOS `vm.max_map_count` as a first-class prerequisite.** `up.sh` checks it only on Linux; on Docker Desktop the indexer runs in a Linux VM that also needs `>= 262144`. Add a documented step (and, where feasible, a preflight that sets it in the Docker VM) so the indexer doesn't fail mmap on macOS.

## Risks / Trade-offs

- [Config drift vs the pinned Wazuh image version] → Model `opensearch.yml`/`internal_users.yml` on the 4.9.x upstream single-node files and keep them in lockstep with `WAZUH_VERSION`; note the coupling in a comment.
- [Password-hash vs `.env` mismatch after a learner edits `.env`] → Document the `hash.sh` regeneration + securityadmin re-apply step; consider a helper in `up.sh`.
- [Disk/RAM: the stack is ~9 GB of images + JVM indexer] → This is the "run it alone" stack; the lab already says so. Verification must be done on a host with headroom (a constrained host is what blocked 5.4 originally).
- [macOS bind-mount permissions] → The indexer reads the mounted certs fine (verified); the failure was config paths, not OS perms — but keep an eye on cert file perms if switching mount styles.

## Migration Plan

Additive config + compose-mount change; no destructive migration. Order: (1) add indexer config files with cert paths matching mounts; (2) add dashboard config; (3) mount them + wire securityadmin in `docker-compose.yml`; (4) bring up, confirm indexer healthy and `.env` admin password authenticates on `:9200`; (5) onboard agent, fire the crafted brute-force, query `wazuh-alerts-*` for rule 100100 + `data.srcip`; (6) update `d4-siem-wazuh` validation status; (7) tear down. Rollback = revert the added config + compose mounts.

## Open Questions

- Ship `internal_users.yml` hashes for the `.env.example` default passwords (simplest first-run) vs. require the learner to generate them — resolve based on how much first-run friction is acceptable.
- Whether the dashboard also needs `wazuh.yml` (API host wiring) in addition to `opensearch_dashboards.yml` for the 4.9.2 image — confirm empirically during implementation.
