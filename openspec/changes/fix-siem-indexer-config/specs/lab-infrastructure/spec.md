## ADDED Requirements

### Requirement: The SIEM indexer boots healthy from shipped config with credentials set from .env
The `lab-infra/siem/` stack SHALL start cleanly from the files it ships: `docker compose -p oss500-siem up -d` MUST bring the `wazuh.indexer` container to a healthy, non-restarting state, not a crash loop. To that end the repo SHALL include the indexer security configuration the stack requires — at minimum `config/wazuh_indexer/opensearch.yml` (whose SSL transport and HTTP certificate paths and filenames match the certificates `docker-compose.yml` mounts into the container) and `config/wazuh_indexer/internal_users.yml` (whose `admin` and `kibanaserver` password hashes correspond to the `.env` values) — mounted into the indexer, with `securityadmin` initialization applying the internal users so the `.env`-configured admin password is the credential the manager and dashboard authenticate with. The macOS/Docker-Desktop `vm.max_map_count >= 262144` requirement SHALL be documented and, where possible, handled, since `up.sh`'s existing check only runs on Linux hosts.

#### Scenario: Indexer starts without crash-looping
- **WHEN** a learner runs the documented SIEM bring-up (`./up.sh` / `docker compose -p oss500-siem up -d`) on a host with adequate disk and memory
- **THEN** the `wazuh.indexer` container reaches a running, non-restarting state and answers on `:9200`, rather than restarting repeatedly on an SSL/`FilePermission` initialization error

#### Scenario: The .env admin password is the real indexer credential
- **WHEN** the stack is up and the manager/dashboard authenticate to the indexer, or a learner queries `https://localhost:9200` as `admin`
- **THEN** the password that works is the one set in `.env` (`INDEXER_PASSWORD`), because `internal_users.yml` was applied via `securityadmin` — not an undocumented image default

#### Scenario: Cert paths in config match the mounted certs
- **WHEN** the indexer reads its `opensearch.yml`
- **THEN** the SSL certificate/key paths and filenames it references resolve to the certificate files `docker-compose.yml` actually mounts, so transport and HTTP SSL initialize successfully
