## 1. Add the missing indexer security config

- [ ] 1.1 Add `lab-infra/siem/config/wazuh_indexer/opensearch.yml` (modeled on wazuh-docker 4.9 single-node), with `plugins.security.ssl.transport`/`http` `pemcert_filepath`/`pemkey_filepath`/`pemtrustedcas_filepath` set to the filenames this repo actually mounts (`wazuh.indexer.pem`, `wazuh.indexer.key`, `root-ca.pem`), plus the security plugin config (authcz admin DN, nodes DN, `allow_default_init_securityindex`).
- [ ] 1.2 Add `lab-infra/siem/config/wazuh_indexer/internal_users.yml` with bcrypt hashes for `admin` and `kibanaserver` that correspond to the `.env` passwords (generate with the image's `plugins/opensearch-security/tools/hash.sh`); document that editing `.env` requires regenerating the hash + re-running securityadmin.

## 2. Add the dashboard config

- [ ] 2.1 Add `lab-infra/siem/config/wazuh_dashboard/opensearch_dashboards.yml` (indexer hosts, SSL, `.env`-driven `kibanaserver` creds) and, if the 4.9.2 dashboard image needs it, `wazuh.yml` (manager API host/creds). Confirm which are required empirically.

## 3. Wire the config into compose + init

- [ ] 3.1 Mount the new indexer and dashboard config files into the `wazuh.indexer` / `wazuh.dashboard` services in `lab-infra/siem/docker-compose.yml`.
- [ ] 3.2 Ensure `internal_users.yml` is applied via `securityadmin` on first boot (rely on `allow_default_init_securityindex` or add an explicit init step) so the `.env` admin/dashboard passwords are the real credentials.
- [ ] 3.3 Make the indexer admin password authoritative from `.env` (resolve the wiring gap so `INDEXER_PASSWORD` set by the learner actually works), or document precisely which password the stack uses and why.

## 4. macOS / Docker Desktop prerequisite

- [ ] 4.1 Document `vm.max_map_count >= 262144` for the indexer on Docker Desktop/macOS (up.sh only checks it on Linux), and where feasible add a preflight that sets it in the Docker VM (e.g. a privileged one-shot) before starting the indexer.

## 5. Verify end-to-end on a host with headroom

- [ ] 5.1 Bring the stack up: `./up.sh`; confirm `wazuh.indexer` is running (not restarting) and `curl -sk -u admin:$INDEXER_PASSWORD https://localhost:9200/_cluster/health` returns a status.
- [ ] 5.2 Onboard the agent (`docker compose -p oss500-siem -f agent-compose.yml up -d`); confirm it enrolls (status *active*).
- [ ] 5.3 Inject 6+ crafted sshd `Failed password ... from 203.0.113.7` lines into the agent's `/var/log/auth.log`; confirm rule 5710 fires and correlates to rule 100100.
- [ ] 5.4 Query `wazuh-alerts-*` via the indexer `_search` API and confirm an alert document with `rule.id` 100100 and parsed `data.srcip` = the crafted IP (this is the observable `fix-lab-correctness-blockers` 5.4 was blocked on).
- [ ] 5.5 Update the `d4-siem-wazuh` lab `Validation status` note for the alert observable from `host-pending` to `host-validated`, naming what was run; tear down cleanly (`down.sh`, no orphaned containers/volumes).

## 6. Validation

- [ ] 6.1 Run `openspec validate fix-siem-indexer-config --type change --strict` and confirm it passes.
- [ ] 6.2 Confirm no `tracker.yaml`/objective change and `npm run lint:links` still passes.
