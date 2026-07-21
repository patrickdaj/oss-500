# Lab d4: SIEM & incident response with Wazuh + OpenSearch

Deploy a full SIEM, onboard an endpoint, engineer a detection (Sigma → OpenSearch), hunt the resulting events with the Query DSL, then close the loop with an automated active response that firewall-blocks the attacker.

**Objectives covered**

| id | Objective |
|---|---|
| `siem-deploy` | Deploy a SIEM and its search backend |
| `siem-collect` | Collect and normalize security telemetry from agents and sources |
| `siem-detect` | Engineer detections with portable detection-as-code rules |
| `siem-hunt` | Hunt threats and correlate events with a query language |
| `siem-response` | Automate incident response with active-response actions |

**SC-500 correspondence**: Microsoft Sentinel (Wazuh manager + OpenSearch indexer/dashboard), Sentinel data connectors / ASIM normalization (Wazuh agents + decoders), Sentinel analytics rules (Sigma), KQL threat hunting (OpenSearch Query DSL), Sentinel automation rules & playbooks / SOAR (Wazuh active response).

**Prerequisites**
- Docker + Docker Compose. **No kind cluster needed** for the core lab (the SIEM is a Compose appliance).
- [`lab-infra/siem`](../lab-infra/siem/) prepared (`cd lab-infra/siem && cp .env.example .env` and set strong `INDEXER_PASSWORD`/`API_PASSWORD`, then `./up.sh`).
- Notes read: [siem-incident-response.md](../domains/4-posture-monitoring/siem-incident-response.md).
- Linux `vm.max_map_count=262144` set (the indexer requires it — `up.sh` checks and instructs).

**Estimated time**: 3–4 h · $0 (local)

> **Resource note:** Wazuh indexer (OpenSearch/JVM) + manager + dashboard is **the single heaviest stack in the course**. **Run it completely alone** — tear down the observability stack and any kind workloads first. Budget ~4–6 GB RAM and give Docker ≥ 6 GB. Do not run this the same day as the observability lab.

## Steps

### Part A — Deploy the SIEM (`siem-deploy`)
1. `cd lab-infra/siem && ./up.sh`. It runs `docker compose -p oss500 up -d` for `wazuh.manager`, `wazuh.indexer`, `wazuh.dashboard` and generates the internal TLS certs on first run.
2. Wait for health: `docker compose -p oss500 ps` all `healthy`; the indexer takes the longest.
3. Open the dashboard at `https://localhost:5601` (self-signed cert warning is expected). Log in with the admin user and the password you set in `.env` — **not** a default (proving the "change default creds" hardening).
4. Note the two tiers: the **manager** (detection engine, `:55000` API, agent ports `1514`/`1515`) and the **indexer** (search/storage, the OpenSearch fork). Confirm you can reach the manager API: `curl -sk -u "wazuh-wui:<API_PASSWORD>" https://localhost:55000/security/user/authenticate`.

### Part B — Collect & normalize telemetry (`siem-collect`)
5. Onboard an agent. Simplest path: run the Wazuh agent as a container against the manager, or install it on the host — `docker compose -p oss500 -f agent-compose.yml up -d` (points `MANAGER_IP` at the manager). Confirm enrollment in the dashboard **Agents** view (status *active*).
6. Generate raw telemetry: on the agent, simulate SSH brute force — `for i in $(seq 1 8); do ssh -o BatchMode=yes baduser@localhost true 2>/dev/null; done` (or append crafted `Failed password` lines to a monitored log).
7. See normalization at work: the agent ships `auth.log`; a Wazuh **decoder** extracts `srcip`/`srcuser`; rules `5710`/`5712`/`5551` fire. In the dashboard **Threat Hunting / Discover**, open an alert document and note the *parsed* fields (`data.srcip`, `rule.id`, `rule.mitre.id`) — raw text became a normalized schema.

### Part C — Detection-as-code with Sigma (`siem-detect`)
8. Read the sample Sigma rule [`sigma/ssh-bruteforce.yml`](../lab-infra/siem/sigma/ssh-bruteforce.yml): `logsource` (`product: linux`, `service: sshd`), a `detection` selection on failed logins, `condition`, `level: high`, and `tags: [attack.t1110]` (MITRE brute force).
9. Convert it to an OpenSearch query with the `sigma` CLI: `pip install sigma-cli pysigma-backend-opensearch` then `sigma convert -t opensearch -p ecs_windows ../lab-infra/siem/sigma/ssh-bruteforce.yml` (use the linux pipeline) — observe the *same YAML* becomes a backend query. (Conceptually, `-t kusto` would emit the Sentinel KQL analytics rule.)
10. Operationalize it: save the converted query as an OpenSearch **monitor/alert** (or map it to the equivalent native Wazuh rule in [`custom-rules.xml`](../lab-infra/siem/config/custom-rules.xml)) and confirm it flags the brute-force events. The point: one portable detection, deployed to this backend.

### Part D — Threat hunting with OpenSearch Query DSL (`siem-hunt`)
11. In the dashboard **Dev Tools** (or `curl` the `_search` API), run a hunt against the alerts index:
    ```json
    GET wazuh-alerts-*/_search
    {
      "query": { "bool": { "filter": [
        { "term":  { "rule.id": "5710" } },
        { "range": { "@timestamp": { "gte": "now-1h" } } }
      ]}},
      "aggs": { "top_src": { "terms": { "field": "data.srcip", "size": 10 } } }
    }
    ```
12. Read the aggregation: the `top_src` buckets are your noisiest brute-force sources — the hypothesis ("someone is brute-forcing SSH") confirmed by data, not by waiting for a page. This `bool`+`filter`+`terms` shape ≈ KQL `where ... | summarize count() by srcip`.
13. Pivot: take the top `srcip` and search it across *all* indices (`must` on that IP, drop the rule filter) to see everything that host did — the correlation step of an investigation.

### Part E — Automated response (`siem-response`)
14. Review active response in [`config/ossec.conf`](../lab-infra/siem/config/ossec.conf): a `<command name="firewall-drop">` and an `<active-response>` block bound to the brute-force `rule_id` at `level >= 10`, with a `<timeout>` (auto-revert). Comment references `siem-response`.
15. Trigger it: repeat the brute force from Part B until the high-level correlated rule fires. On the agent, confirm the source IP is now dropped: `sudo iptables -L -n | grep <srcip>` (or check the agent's active-response log `/var/ossec/logs/active-responses.log`).
16. Watch it self-revert: after the timeout, the rule is removed automatically — `iptables -L -n` no longer lists the IP. Detection → decision (level) → action (drop) → recovery (timeout), the full IR loop.

## Verification
- **Deploy**: all three containers `healthy`; dashboard reachable over TLS with **non-default** credentials; manager API authenticates.
- **Collect**: the agent shows *active*, and a brute-force alert document in the indexer has **parsed fields** (`data.srcip`, `rule.mitre.id`) — normalization proven.
- **Detect**: the Sigma YAML converts to a backend query and the corresponding rule/monitor **flags the brute-force events** (a Sigma rule matching an event in Wazuh/OpenSearch — the observable proof).
- **Hunt**: the OpenSearch DSL aggregation returns the attacking `srcip` in the `top_src` buckets.
- **Respond**: the attacker IP appears in the agent's `iptables` DROP rules after the alert, then **disappears after the timeout** — active response provably contained and reverted.

## Teardown
- `docker compose -p oss500 -f agent-compose.yml down` (agent), then `cd lab-infra/siem && ./down.sh` (`docker compose -p oss500 down -v` — the `-v` removes the heavy indexer volumes).

## What the exam asks
- A SIEM has a **detection engine** (Wazuh manager / Sentinel analytics) and a **search store** (OpenSearch indexer / Log Analytics). "Can't search old events" = store; "no alert" = detection engine.
- **Normalization precedes detection** — decoders/ASIM parse raw logs into fields before any rule can match. Un-parsed logs are why a rule "doesn't fire."
- **Sigma is a portable format**, not an engine — it must be *converted* to OpenSearch DSL / KQL / SPL to run. Detections map to MITRE ATT&CK.
- **Hunting is proactive** (hypothesis → query with aggregations), distinct from a rule that fires on its own. DSL `terms` ≈ KQL `summarize by`.
- **Active response = conditional SOAR automation** keyed to rule level/ID, time-bounded and self-reverting. It can be weaponized (spoofed source → self-DoS), so gate on high-confidence rules and allow-list critical hosts. Alert firing ≠ IP blocked — response is a separate configured stage.
