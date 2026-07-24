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
- Tools for this lab: `sigma` (sigma-cli, rule→query conversion) — install per [`../TOOLS.md`](../TOOLS.md).
- Linux `vm.max_map_count=262144` set (the indexer requires it — `up.sh` checks and instructs).

**Estimated time**: 3–4 h · $0 (local)

> **Resource note:** Wazuh indexer (OpenSearch/JVM) + manager + dashboard is **the single heaviest stack in the course**. **Run it completely alone** — tear down the observability stack and any kind workloads first. Budget ~4–6 GB RAM and give Docker ≥ 6 GB. Do not run this the same day as the observability lab.

## Challenge

Deploy a full SIEM (detection engine + search backend), onboard an endpoint, and close a five-stage loop — deploy, collect & normalize, detect, hunt, respond — reaching five concrete observables. Build each stage yourself in the guided section below; check your work against the reference solution after.

1. **Deploy** — all three containers (`wazuh.manager`, `wazuh.indexer`, `wazuh.dashboard`) `healthy`; the dashboard is reachable over TLS with **non-default** credentials; the manager API authenticates.
2. **Collect** — an onboarded agent shows *active*, and a brute-force alert document in the indexer carries **parsed fields** (`data.srcip`, `rule.mitre.id`) — proof raw log text became a normalized schema.
3. **Detect** — a Sigma rule you convert with the `sigma` CLI becomes a backend query that **flags the brute-force events** in Wazuh/OpenSearch — one portable detection, operationalized.
4. **Hunt** — an OpenSearch Query DSL aggregation *you write* returns the attacking `srcip` in the `top_src` buckets — the hypothesis ("someone is brute-forcing SSH") confirmed by data.
5. **Respond** — after the correlated high-level alert fires, the attacker IP appears in the agent's `iptables` DROP rules, then **disappears after the timeout** — active response provably contained and auto-reverted.

No finished decoder mapping, Sigma→DSL conversion, hunt query, or active-response wiring is given here — write/run each yourself below, then compare against the reference solution.

## Build it (guided)

### Part A — Deploy the SIEM (`siem-deploy`)
1. `cd lab-infra/siem && ./up.sh`. It runs `docker compose -p oss500-siem up -d` for `wazuh.manager`, `wazuh.indexer`, `wazuh.dashboard` and generates the internal TLS certs on first run.
2. Wait for health: `docker compose -p oss500-siem ps` all `healthy`; the indexer takes the longest.
3. Open the dashboard at `https://localhost:5601` (self-signed cert warning is expected). Log in with the admin user and the password you set in `.env`. Your turn: make sure that's a strong `INDEXER_PASSWORD`/`API_PASSWORD` — **not** a default. That choice *is* the "change default creds" hardening this objective tests.
4. Note the two tiers: the **manager** (detection engine, `:55000` API, agent ports `1514`/`1515`) and the **indexer** (search/storage, the OpenSearch fork). Confirm you can reach the manager API:
   ```bash
   curl -sk -u "wazuh-wui:<API_PASSWORD>" https://localhost:55000/security/user/authenticate
   ```
   (swap in the password you set in step 3).

### Part B — Collect & normalize telemetry (`siem-collect`)
5. Onboard an agent. Simplest path: run the Wazuh agent as a container against the manager, or install it on the host — `docker compose -p oss500-siem -f agent-compose.yml up -d` (points `MANAGER_IP` at the manager). Confirm enrollment in the dashboard **Agents** view (status *active*).
6. Generate raw telemetry: on the agent, simulate SSH brute force —
   ```bash
   for i in $(seq 1 8); do ssh -o BatchMode=yes baduser@localhost true 2>/dev/null; done
   ```
   (or append crafted `Failed password` lines to a monitored log).
7. **Your turn: go find the normalization, don't take it on faith.** A Wazuh **decoder** is watching the agent's shipped `auth.log` and pulling fields out of the raw text; a rule then matches on those fields. In the dashboard **Threat Hunting / Discover**, filter to your agent and open the alert document your brute force produced. Note down: which fields got parsed out of the raw line (hint: look for something namespaced like `data.srcip`/`data.srcuser`), and the `rule.id` / `rule.mitre.id` that fired. That's raw text becoming a normalized schema — you should be able to point at the exact JSON keys that prove it.

### Part C — Detection-as-code with Sigma (`siem-detect`)
8. Read the sample Sigma rule [`sigma/ssh-bruteforce.yml`](../lab-infra/siem/sigma/ssh-bruteforce.yml) yourself and identify its load-bearing pieces before moving on: the `logsource` (what product/service does it target?), the `detection` selection (what field/value marks a failed login?), the `condition`, the `level`, and the MITRE `tags`. This is the portable, engine-agnostic format — nothing in it mentions OpenSearch.
9. **Convert it to a real backend query — your turn.** Install the tooling:
   ```bash
   pip install sigma-cli pysigma-backend-opensearch
   ```
   Don't guess a `-p` pipeline — list what's actually registered for this backend first:
   ```bash
   sigma list pipelines opensearch
   ```
   Every row in that table is an **ECS field-mapping** pipeline for a specific *source*: Winlogbeat/Sysmon (`ecs_windows`), Zeek (`ecs_zeek_beats`/`ecs_zeek_corelight`), Kubernetes audit (`ecs_kubernetes`), macOS ESF (`ecs_macos_esf`) — none of them target Linux auth logs. That's not an oversight to work around: this rule's `logsource` (`product: linux`, `service: sshd`) already uses the same field names (`src_ip`, …) the Wazuh decoder writes into the alert document, so there's nothing to remap. Your turn: convert it **without** a pipeline —
   ```bash
   sigma convert -t opensearch --without-pipeline lab-infra/siem/sigma/ssh-bruteforce.yml
   ```
   — and confirm the emitted query references the same field names you noted on the alert document in Part B. (Conceptually, `-t kusto` would emit the equivalent Sentinel KQL analytics rule — same source, different engine. Picking `ecs_windows` here would silently rename fields to a Sysmon schema that doesn't exist in this data, and the resulting query would just never match anything.)
10. **Operationalize it.** Either save the converted query as an OpenSearch **monitor/alert**, or map it to the equivalent native Wazuh rule in [`custom-rules.xml`](../lab-infra/siem/config/custom-rules.xml) — open that file and find where a custom rule keys on the same condition your Sigma rule expresses. Confirm whichever path you choose actually flags the brute-force events from Part B. The point: one portable detection, deployed to this backend.

### Part D — Threat hunting with OpenSearch Query DSL (`siem-hunt`)
11. **Form the hypothesis, then write the query yourself.** The hypothesis: "someone is brute-forcing SSH, and I can find the noisiest source IP." In the dashboard **Dev Tools** (or `curl` the `_search` API), write a query against `wazuh-alerts-*` that: filters to the brute-force rule (the `rule.id` you noted in Part B), filters to a recent time window (`@timestamp` in the last hour), and aggregates a `terms` bucket on the source-IP field. Hint: OpenSearch Query DSL shapes this as `bool` → `filter` (for exact-match/range clauses that don't affect scoring) plus a top-level `aggs` block — structurally the same job KQL does with `where ... | summarize count() by srcip`. Your turn: assemble the JSON and run it.
12. Read the aggregation: the top bucket in your `terms` agg is your noisiest brute-force source — the hypothesis confirmed by data, not by waiting for a page.
13. **Pivot — your turn to write a second query.** Take the top `srcip` from step 11 and search for it across *all* indices: same target, but swap the filter to a `must` clause on that IP and drop the rule filter entirely. This surfaces everything that host touched — the correlation step of an investigation.

### Part E — Automated response (`siem-response`)
14. **Go find the active-response wiring yourself.** Open [`config/ossec.conf`](../lab-infra/siem/config/ossec.conf) and locate two things: a `<command name="firewall-drop">` definition, and the `<active-response>` block that binds it to a rule. Work out for yourself: which `rule_id` (or `level`) gates it, and what does the `<timeout>` do? (A comment in the file references `siem-response`.) Don't move on until you can state the trigger condition and the auto-revert behavior in your own words.
15. Trigger it: repeat the brute force from Part B until the high-level correlated rule fires. On the agent, confirm the source IP is now dropped:
    ```bash
    sudo iptables -L -n | grep <srcip>
    ```
    (or check the agent's active-response log `/var/ossec/logs/active-responses.log`).
16. Watch it self-revert: after the timeout you found in step 14 elapses, re-run the `iptables -L -n` check — the rule should be gone, automatically. Detection → decision (level) → action (drop) → recovery (timeout): the full IR loop, and you just watched all four stages happen.

## Verification

> **Validation status — host-pending.** Full **Wazuh agent enrollment** (agent shows *active* in the dashboard, alerts flow) has not yet been run end-to-end on a host by the author. The agent↔manager docker-network fix (the agent now joins `oss500-siem_default`, the network the `-p oss500-siem` project actually creates) *is* verified mechanically with a throwaway Compose stack. If enrollment misbehaves, it's a finding to report.

- **Deploy**: all three containers `healthy`; dashboard reachable over TLS with **non-default** credentials; manager API authenticates.
- **Collect**: the agent shows *active*, and a brute-force alert document in the indexer has **parsed fields** (`data.srcip`, `rule.mitre.id`) — normalization proven.
- **Detect**: the Sigma YAML converts to a backend query and the corresponding rule/monitor **flags the brute-force events** (a Sigma rule matching an event in Wazuh/OpenSearch — the observable proof).
- **Hunt**: the OpenSearch DSL aggregation returns the attacking `srcip` in the `top_src` buckets.
- **Respond**: the attacker IP appears in the agent's `iptables` DROP rules after the alert, then **disappears after the timeout** — active response provably contained and reverted.

## Reference solution
Build it yourself first; check after.

### Part A — Deploy the SIEM (`siem-deploy`)
1. `cd lab-infra/siem && ./up.sh` runs `docker compose -p oss500-siem up -d` for `wazuh.manager`, `wazuh.indexer`, `wazuh.dashboard` and generates the internal TLS certs on first run.
2. `docker compose -p oss500-siem ps` — wait until all three show `healthy` (the indexer takes the longest).
3. Dashboard at `https://localhost:5601` (self-signed cert warning is expected); log in with the admin user and the password set in `.env` — **not** a default (proving the "change default creds" hardening).
4. The **manager** (detection engine, `:55000` API, agent ports `1514`/`1515`) vs. the **indexer** (search/storage, the OpenSearch fork). Confirm you can reach the manager API:
   ```bash
   curl -sk -u "wazuh-wui:<API_PASSWORD>" https://localhost:55000/security/user/authenticate
   ```

### Part B — Collect & normalize telemetry (`siem-collect`)
5. `docker compose -p oss500-siem -f agent-compose.yml up -d` (`MANAGER_IP` pointed at the manager). Confirm enrollment in the dashboard **Agents** view (status *active*).
6. ```bash
   for i in $(seq 1 8); do ssh -o BatchMode=yes baduser@localhost true 2>/dev/null; done
   ```
   (or append crafted `Failed password` lines to a monitored log).
7. The agent ships `auth.log`; a Wazuh **decoder** extracts `srcip`/`srcuser`; rules `5710`/`5712`/`5551` fire. In the dashboard **Threat Hunting / Discover**, an alert document's *parsed* fields — `data.srcip`, `rule.id`, `rule.mitre.id` — are the proof: raw text became a normalized schema.

### Part C — Detection-as-code with Sigma (`siem-detect`)
8. [`sigma/ssh-bruteforce.yml`](../lab-infra/siem/sigma/ssh-bruteforce.yml): `logsource` (`product: linux`, `service: sshd`), a `detection` selection on failed logins, `condition`, `level: high`, and `tags: [attack.t1110]` (MITRE brute force).
9. ```bash
   pip install sigma-cli pysigma-backend-opensearch
   sigma list pipelines opensearch            # every result is ECS for Windows/Zeek/K8s/macOS — none for Linux
   sigma convert -t opensearch --without-pipeline ../lab-infra/siem/sigma/ssh-bruteforce.yml
   ```
   No pipeline is the *correct* choice, not a fallback: the rule's fields already match the Wazuh decoder's raw output, so remapping to an ECS schema (e.g. `ecs_windows`) would rename fields that don't exist in this data. The *same YAML* becomes a backend query. (Conceptually, `-t kusto` would emit the equivalent Sentinel KQL analytics rule.)
10. Save the converted query as an OpenSearch **monitor/alert** (or map it to the equivalent native Wazuh rule in [`custom-rules.xml`](../lab-infra/siem/config/custom-rules.xml)) and confirm it flags the brute-force events. One portable detection, deployed to this backend.

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
14. [`config/ossec.conf`](../lab-infra/siem/config/ossec.conf): a `<command name="firewall-drop">` and an `<active-response>` block bound to the brute-force `rule_id` at `level >= 10`, with a `<timeout>` (auto-revert). Comment references `siem-response`.
15. Repeat the brute force from Part B until the high-level correlated rule fires. On the agent, confirm the source IP is now dropped:
    ```bash
    sudo iptables -L -n | grep <srcip>
    ```
    (or check the agent's active-response log `/var/ossec/logs/active-responses.log`).
16. Watch it self-revert: after the timeout, the rule is removed automatically — `iptables -L -n` no longer lists the IP. Detection → decision (level) → action (drop) → recovery (timeout), the full IR loop.

If your Sigma conversion picked an ECS pipeline (e.g. `ecs_windows`) for this Linux/sshd logsource, the emitted fields won't line up with what the decoder actually parsed — run `sigma list pipelines <backend>` before guessing; when nothing in the list matches the `logsource`, convert with `--without-pipeline` rather than reaching for the nearest-sounding one.

## Teardown
- `docker compose -p oss500-siem -f agent-compose.yml down` (agent), then `cd lab-infra/siem && ./down.sh` (`docker compose -p oss500-siem down -v` — the `-v` removes the heavy indexer volumes).

> **Validate it *(purple team)*.** Run a Caldera adversary chain in [`d5-infra-attack-simulation`](d5-infra-attack-simulation.md) and confirm Wazuh **correlates** the multi-step operation (not just single events) — the SIEM's job is the chain. Also wire a ZTNA denial (from [`d5-ztna-authz`](d5-ztna-authz.md)) into Wazuh to prove attack → deny → alert.

## What the exam asks
- A SIEM has a **detection engine** (Wazuh manager / Sentinel analytics) and a **search store** (OpenSearch indexer / Log Analytics). "Can't search old events" = store; "no alert" = detection engine.
- **Normalization precedes detection** — decoders/ASIM parse raw logs into fields before any rule can match. Un-parsed logs are why a rule "doesn't fire."
- **Sigma is a portable format**, not an engine — it must be *converted* to OpenSearch DSL / KQL / SPL to run. Detections map to MITRE ATT&CK.
- **Hunting is proactive** (hypothesis → query with aggregations), distinct from a rule that fires on its own. DSL `terms` ≈ KQL `summarize by`.
- **Active response = conditional SOAR automation** keyed to rule level/ID, time-bounded and self-reverting. It can be weaponized (spoofed source → self-DoS), so gate on high-confidence rules and allow-list critical hosts. Alert firing ≠ IP blocked — response is a separate configured stage.
