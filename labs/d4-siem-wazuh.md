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
6. **Generate raw telemetry — crafted log lines, not a real `ssh` attempt.** The agent container has neither an `sshd` server nor an `ssh` client, so there is nothing to actually brute-force; instead you feed the built-in sshd decoder the exact syslog line shape it expects, appended to `/var/log/auth.log` (the path the agent's default Linux config already monitors):
   ```bash
   docker compose -p oss500-siem -f agent-compose.yml exec wazuh.agent sh -c '
     touch /var/log/auth.log
     for i in $(seq 1 8); do
       echo "$(date "+%b %e %H:%M:%S") oss500-agent sshd[$((10000+i))]: Failed password for invalid user baduser from 203.0.113.7 port $((40000+i)) ssh2" >> /var/log/auth.log
     done'
   ```
   The line shape that matters: `<Mon> <D> <HH:MM:SS> <host> sshd[<pid>]: Failed password for invalid user <user> from <ip> port <port> ssh2` — this is exactly what a real sshd logs on failed auth, and what Wazuh's built-in sshd decoder pattern-matches to populate `data.srcip`/`data.srcuser`. If the agent was already running when you `touch`ed the file, give the logcollector a moment (or `docker compose -p oss500-siem -f agent-compose.yml restart wazuh.agent`) to pick up the newly-created path.
7. **Your turn: go find the normalization, don't take it on faith.** A Wazuh **decoder** is watching the agent's shipped `auth.log` and pulling fields out of the raw text; a rule then matches on those fields. In the dashboard **Threat Hunting / Discover**, filter to your agent and open the alert document your brute force produced. Note down: which fields got parsed out of the raw line (hint: look for something namespaced like `data.srcip`/`data.srcuser`), and the `rule.id` / `rule.mitre.id` that fired. That's raw text becoming a normalized schema — you should be able to point at the exact JSON keys that prove it.

### Part C — Detection-as-code with Sigma (`siem-detect`)
8. Read the sample Sigma rule [`sigma/ssh-bruteforce.yml`](../lab-infra/siem/sigma/ssh-bruteforce.yml) yourself and identify its load-bearing pieces before moving on: the `logsource` (what product/service does it target?), the `detection` selection (a bare list under `selection` — Sigma's plain-**keyword** form, not a field:value match), the `condition`, the `level`, and the MITRE `tags`. This is the portable, engine-agnostic format — nothing in it mentions OpenSearch.
9. **Convert it to a real backend query — your turn.** Install the tooling:
   ```bash
   pip install sigma-cli pysigma-backend-opensearch
   ```
   Don't guess a `-p` pipeline — list what's actually registered for this backend's target first (the CLI's target id for this backend is `opensearch_lucene`, not `opensearch`):
   ```bash
   sigma list pipelines opensearch_lucene
   ```
   The table comes back **empty** — pysigma-backend-opensearch currently registers no pipeline at all for this target (the ECS pipelines you'll see under a bare `sigma list pipelines` — `ecs_windows`, `ecs_zeek_beats`/`ecs_zeek_corelight`, `ecs_kubernetes`, `ecs_macos_esf` — are scoped to other targets, and passing one here with `-p` is rejected with "not intended to be used with the target `opensearch_lucene`"). That's not a gap to work around: this rule's `detection` is a plain keyword selection, not a field:value match, so there is no field-name remapping for a pipeline to do in the first place — a keyword search runs against the raw log text regardless of source. Your turn: convert it **without** a pipeline —
   ```bash
   sigma convert -t opensearch_lucene --without-pipeline lab-infra/siem/sigma/ssh-bruteforce.yml
   # -> *Failed\ password* OR *authentication\ failure*
   ```
   — and confirm the emitted query is the same two keyword terms your `detection.selection` listed, unmapped (`Failed password`, `authentication failure`) — proof a keyword selection needs no source-specific pipeline at all. (Conceptually, `-t kusto` would emit the equivalent Sentinel KQL analytics rule — same source, different engine. Forcing `ecs_windows` here with `--disable-pipeline-check` would be pointless: there's no field name in this rule for it to remap.)
10. **Operationalize it.** Either save the converted query as an OpenSearch **monitor/alert**, or map it to the equivalent native Wazuh rule in [`custom-rules.xml`](../lab-infra/siem/config/custom-rules.xml) — open that file and find where a custom rule keys on the same condition your Sigma rule expresses. Confirm whichever path you choose actually flags the brute-force events from Part B. The point: one portable detection, deployed to this backend.

### Part D — Threat hunting with OpenSearch Query DSL (`siem-hunt`)
11. **Form the hypothesis, then write the query yourself.** The hypothesis: "someone is brute-forcing SSH, and I can find the noisiest source IP." In the dashboard **Dev Tools** (or `curl` the `_search` API), write a query against `wazuh-alerts-*` that: filters to the brute-force rule (the `rule.id` you noted in Part B), filters to a recent time window (`@timestamp` in the last hour), and aggregates a `terms` bucket on the source-IP field. Hint: OpenSearch Query DSL shapes this as `bool` → `filter` (for exact-match/range clauses that don't affect scoring) plus a top-level `aggs` block — structurally the same job KQL does with `where ... | summarize count() by srcip`. Your turn: assemble the JSON and run it.
12. Read the aggregation: the top bucket in your `terms` agg is your noisiest brute-force source — the hypothesis confirmed by data, not by waiting for a page.
13. **Pivot — your turn to write a second query.** Take the top `srcip` from step 11 and search for it across *all* indices: same target, but swap the filter to a `must` clause on that IP and drop the rule filter entirely. This surfaces everything that host touched — the correlation step of an investigation.

### Part E — Automated response (`siem-response`)
14. **Go find the active-response wiring yourself.** Open [`config/ossec.conf`](../lab-infra/siem/config/ossec.conf) and locate two things: a `<command name="firewall-drop">` definition, and the `<active-response>` block that binds it to a rule. Work out for yourself: which `rule_id` (or `level`) gates it, and what does the `<timeout>` do? (A comment in the file references `siem-response`.) Don't move on until you can state the trigger condition and the auto-revert behavior in your own words.
15. Trigger it: repeat the crafted brute-force burst from Part B (a fresh source IP makes the drop easy to spot) until the high-level correlated rule fires. Confirm the source IP is now dropped inside the agent container:
    ```bash
    docker compose -p oss500-siem -f agent-compose.yml exec wazuh.agent iptables -L -n | grep <srcip>
    ```
    (or check the agent's active-response log: `docker compose -p oss500-siem -f agent-compose.yml exec wazuh.agent cat /var/ossec/logs/active-responses.log`).
16. Watch it self-revert: after the timeout you found in step 14 elapses, re-run the `iptables -L -n` check — the rule should be gone, automatically. Detection → decision (level) → action (drop) → recovery (timeout): the full IR loop, and you just watched all four stages happen.

## Verification

> **Validation status — host-pending.** The manager config (`ossec.conf`, now shipping a `<ruleset>` block so decoders/rules actually load), the custom rules XML, and the Sigma rule are all mechanically valid, and the Sigma conversion step was run live against current `sigma-cli`/`pysigma-backend-opensearch`: `sigma list pipelines opensearch` **fails** (the CLI's target id for this backend is `opensearch_lucene`, not `opensearch`) and `sigma convert -t opensearch_lucene --without-pipeline sigma/ssh-bruteforce.yml` succeeds, emitting `*Failed\ password* OR *authentication\ failure*` — the lab text above reflects this. Full **Wazuh agent enrollment + crafted-telemetry + alert-firing** (agent shows *active*, the alert document lands with parsed fields, rule 100100/firewall-drop fires) has **not** been run end-to-end against a live manager/indexer in this pass — this host had a kind cluster already up and limited free disk, so the full ~4–6 GB stack wasn't brought up alongside it. That run is still owed before this lab is marked fully valid; if it misbehaves, it's a finding to report.

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
   docker compose -p oss500-siem -f agent-compose.yml exec wazuh.agent sh -c '
     touch /var/log/auth.log
     for i in $(seq 1 8); do
       echo "$(date "+%b %e %H:%M:%S") oss500-agent sshd[$((10000+i))]: Failed password for invalid user baduser from 203.0.113.7 port $((40000+i)) ssh2" >> /var/log/auth.log
     done'
   ```
   Crafted lines, not a real `ssh` attempt — the container has no sshd/ssh client.
7. The agent's default Linux config monitors `/var/log/auth.log`; a Wazuh **decoder** extracts `srcip`/`srcuser`; rule `5710` (and the correlation rule `100100` on top of it) fire. In the dashboard **Threat Hunting / Discover**, an alert document's *parsed* fields — `data.srcip`, `rule.id`, `rule.mitre.id` — are the proof: raw text became a normalized schema.

### Part C — Detection-as-code with Sigma (`siem-detect`)
8. [`sigma/ssh-bruteforce.yml`](../lab-infra/siem/sigma/ssh-bruteforce.yml): `logsource` (`product: linux`, `service: sshd`), a `detection` selection on failed logins, `condition`, `level: high`, and `tags: [attack.t1110]` (MITRE brute force).
9. ```bash
   pip install sigma-cli pysigma-backend-opensearch
   sigma list pipelines opensearch_lucene     # empty — this backend target registers no pipeline at all
   sigma convert -t opensearch_lucene --without-pipeline ../lab-infra/siem/sigma/ssh-bruteforce.yml
   # -> *Failed\ password* OR *authentication\ failure*
   ```
   No pipeline is the *correct* choice, not a fallback: the rule's `detection` is a plain keyword selection with no field:value mapping, so there's nothing for a pipeline to remap regardless of source. The *same YAML* becomes a backend query — a Lucene keyword match on the raw log text. (Conceptually, `-t kusto` would emit the equivalent Sentinel KQL analytics rule.)
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
15. Repeat the crafted brute-force burst from Part B until the high-level correlated rule fires. Confirm the source IP is now dropped inside the agent container:
    ```bash
    docker compose -p oss500-siem -f agent-compose.yml exec wazuh.agent iptables -L -n | grep <srcip>
    ```
    (or check the agent's active-response log: `docker compose -p oss500-siem -f agent-compose.yml exec wazuh.agent cat /var/ossec/logs/active-responses.log`).
16. Watch it self-revert: after the timeout, the rule is removed automatically — `iptables -L -n` no longer lists the IP. Detection → decision (level) → action (drop) → recovery (timeout), the full IR loop.

If your Sigma conversion picked an ECS pipeline (e.g. `ecs_windows`) for this Linux/sshd logsource, the emitted fields won't line up with what the decoder actually parsed — run `sigma list pipelines <target>` before guessing (the CLI's target id for a backend isn't always the backend's own name — `opensearch_lucene`, not `opensearch`, here); when nothing in the list matches the `logsource`, convert with `--without-pipeline` rather than reaching for the nearest-sounding one.

## Teardown
- `docker compose -p oss500-siem -f agent-compose.yml down` (agent), then `cd lab-infra/siem && ./down.sh` (`docker compose -p oss500-siem down -v` — the `-v` removes the heavy indexer volumes).

> **Validate it *(purple team)*.** Run a Caldera adversary chain in [`d5-infra-attack-simulation`](d5-infra-attack-simulation.md) and confirm Wazuh **correlates** the multi-step operation (not just single events) — the SIEM's job is the chain. Also wire a ZTNA denial (from [`d5-ztna-authz`](d5-ztna-authz.md)) into Wazuh to prove attack → deny → alert.

## What the exam asks
- A SIEM has a **detection engine** (Wazuh manager / Sentinel analytics) and a **search store** (OpenSearch indexer / Log Analytics). "Can't search old events" = store; "no alert" = detection engine.
- **Normalization precedes detection** — decoders/ASIM parse raw logs into fields before any rule can match. Un-parsed logs are why a rule "doesn't fire."
- **Sigma is a portable format**, not an engine — it must be *converted* to OpenSearch DSL / KQL / SPL to run. Detections map to MITRE ATT&CK.
- **Hunting is proactive** (hypothesis → query with aggregations), distinct from a rule that fires on its own. DSL `terms` ≈ KQL `summarize by`.
- **Active response = conditional SOAR automation** keyed to rule level/ID, time-bounded and self-reverting. It can be weaponized (spoofed source → self-DoS), so gate on high-confidence rules and allow-list critical hosts. Alert firing ≠ IP blocked — response is a separate configured stage.
