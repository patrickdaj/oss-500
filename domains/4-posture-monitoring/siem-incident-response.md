# Operate a SIEM and respond to incidents

Domain 4, subsection 2 (`d4-siem`). A SIEM (Security Information and Event Management) centralizes security telemetry, runs detections against it, and drives the incident-response loop: collect → normalize → detect → hunt → respond. The open-source stack here is **Wazuh** (agents, manager, detection engine, active response) on an **OpenSearch** indexer/dashboard, with **Sigma** as the portable, vendor-neutral detection-as-code format. It maps to **Microsoft Sentinel** end to end. Primary lab: [d4-siem-wazuh](../../labs/d4-siem-wazuh.md) on [`lab-infra/siem`](../../lab-infra/siem/) (Wazuh manager + indexer + dashboard via Docker Compose). This is the heaviest stack in the course — **run it alone**.

## Deploy a SIEM and its search backend

*Objective: `siem-deploy` · OSS: Wazuh + OpenSearch ≈ SC-500: Microsoft Sentinel · Lab: [d4-siem-wazuh](../../labs/d4-siem-wazuh.md)*

A SIEM is really two tiers: an **ingest/detection** tier and a **search/storage** tier. In this stack the **Wazuh manager** is the ingest/detection engine — it receives events from agents and syslog, runs decoders and rules, and generates alerts — while the **Wazuh indexer (a fork of OpenSearch)** stores those alerts and events for search, and the **Wazuh dashboard (a fork of OpenSearch Dashboards)** visualizes them. The Wazuh Docker Compose deployment (`wazuh/wazuh-docker`) brings up `wazuh.manager`, `wazuh.indexer`, and `wazuh.dashboard` as three containers; a single-node indexer is fine for a lab, multi-node for production.

Sizing and security matter even in a lab: the indexer is JVM/Lucene-based and memory-hungry (hence "run it alone"), all inter-component traffic and the API use TLS certificates generated at bootstrap, and the indexer ships with default credentials you **must** change. The manager exposes a REST API (`:55000`) for programmatic management and the agents connect on `1514/tcp` (events) and `1515/tcp` (enrollment).

SC-500 mapping: the whole thing ≈ **Microsoft Sentinel** — Wazuh manager+indexer ≈ Sentinel's analytics + the Log Analytics workspace it sits on, the Wazuh dashboard ≈ the Sentinel portal (workbooks, incidents, hunting). Where Sentinel is a managed Azure service billed per-GB ingested, this stack is the self-hosted equivalent you stand up and secure yourself — which is exactly why the exam's "what does a SIEM do / what are its tiers" concepts transfer.

Exam gotchas:
- Distinguish the **detection engine** (Wazuh manager / Sentinel analytics) from the **search store** (OpenSearch indexer / Log Analytics workspace). A "we can't search old events" problem is the store; "no alert fired" is the detection engine.
- The Wazuh indexer/dashboard are **OpenSearch/OpenSearch-Dashboards forks** — OpenSearch itself forked from Elasticsearch/Kibana 7.10. If a question names Elastic/Kibana concepts, the OpenSearch equivalents apply.
- Change **default indexer/admin/API credentials** at deploy — shipping defaults is a classic finding. Certs and creds are the two must-harden items.

**Resources:**
- [Wazuh — getting started / components](https://documentation.wazuh.com/current/getting-started/components/index.html) (~20 min)
- [Wazuh on Docker](https://documentation.wazuh.com/current/deployment-options/docker/index.html) (~15 min)
- [OpenSearch — introduction](https://opensearch.org/docs/latest/about/) (~10 min)

## Collect and normalize security telemetry from agents and sources

*Objective: `siem-collect` · OSS: Wazuh agents / connectors ≈ SC-500: Sentinel data connectors · Lab: [d4-siem-wazuh](../../labs/d4-siem-wazuh.md)*

Detection is only as good as ingestion. The **Wazuh agent** runs on endpoints and ships log data, file-integrity events, security-config assessment results, and inventory to the manager; agentless sources arrive via **syslog** (`514`), the manager's log collector, or integrations that pull from cloud audit logs (AWS CloudTrail, Azure activity, GCP, Office 365, Docker). The critical concept is **normalization**: raw log lines are meaningless until parsed. Wazuh does this with **decoders** — regex/JSON parsers that extract fields (`srcip`, `srcuser`, `program_name`) into a common schema — and **rules** then match on those normalized fields. This decode→normalize→rule pipeline is the same "connector → parse → schema" pattern every SIEM uses.

Concretely, an agent forwards `/var/log/auth.log`; a decoder recognizes `sshd` lines and extracts the source IP and user; a rule (`5710`, `5712`) fires on repeated failures. For Kubernetes/container security telemetry — Falco alerts from `d3`, audit logs — you forward JSON to the manager and a JSON decoder normalizes it. Wazuh alerts land in the indexer as documents you search in the next objective.

SC-500 mapping: Wazuh agents/connectors ≈ **Sentinel data connectors** (the Azure Monitor Agent, the Log Analytics agent's successor, and the codeless/CEF/syslog connectors). Wazuh decoders ≈ Sentinel's parsers / ASIM (Advanced Security Information Model) normalization. "Onboard a data source" on the exam ≈ deploy the agent or wire a connector; "normalize to a common schema" ≈ ASIM ≈ Wazuh decoders.

Exam gotchas:
- **Normalization before detection**: you cannot write a portable rule on `srcip` until a decoder produces `srcip`. Un-parsed logs are just text — a common "why doesn't my rule match" root cause.
- Agent-based (rich endpoint telemetry, FIM, SCA) vs agentless/syslog (network gear, appliances) — know when each applies; you can't put an agent on a switch, so it sends syslog.
- Ingestion is where **cost and noise** are decided (in Sentinel it's literal per-GB billing). Filtering/routing at collection time is a real design lever, not just detection tuning.

**Resources:**
- [Wazuh agent — how it works](https://documentation.wazuh.com/current/user-manual/agent/agent-management/index.html) (~15 min)
- [Wazuh decoders (ruleset)](https://documentation.wazuh.com/current/user-manual/ruleset/decoders/index.html) (~15 min)

## Engineer detections with portable detection-as-code rules

*Objective: `siem-detect` · OSS: Sigma rules ≈ SC-500: Sentinel analytics rules · Lab: [d4-siem-wazuh](../../labs/d4-siem-wazuh.md)*

**Sigma** is "the YARA/Snort of logs": a vendor-neutral YAML format for expressing a detection once, then *converting* it to whatever backend query language your SIEM speaks. A Sigma rule has a `logsource` (category/product, e.g. `product: linux`, `service: sshd`), a `detection` block with named **selections** and a boolean `condition`, plus metadata (`level`, `tags` mapped to MITRE ATT&CK). The `sigma` CLI / `sigma convert` with a backend pipeline emits an OpenSearch/Elasticsearch query, a Splunk SPL search, a **Sentinel KQL** analytics rule, and so on from the *same* YAML — this is detection-as-code: version-controlled, peer-reviewed, portable across tools, which is why it's the exam-relevant answer to "how do we avoid re-writing every detection per vendor."

Wazuh has its own native XML rule/decoder engine (the manager evaluates it in real time), so in practice you either (a) author Wazuh rules directly, or (b) author Sigma and convert it to the OpenSearch query you save as a monitor/detection, or to an equivalent Wazuh rule. The point for SC-500 is the *concept*: portable detection content mapped to ATT&CK, reviewed like code.

SC-500 mapping: Sigma ≈ the **portable content** that becomes **Sentinel analytics rules** (scheduled KQL rules). The Sentinel community publishes analytics rules and hunting queries as code in a GitHub repo, and the Sigma→KQL backend targets Sentinel directly. Sigma `level`/`tags` ≈ Sentinel rule severity + MITRE tactic mapping. "Write a detection once, deploy to many SIEMs" is the Sigma value proposition and a likely exam framing.

Exam gotchas:
- Sigma is a **format/abstraction**, not a running engine — it doesn't detect anything until *converted* to a backend query (OpenSearch DSL, KQL, SPL). "Deploy Sigma to watch logs" is imprecise; you convert then deploy.
- Map detections to **MITRE ATT&CK** (`tags: attack.t1110` = brute force). Tactic/technique tagging is expected of modern detection content, in Sigma and in Sentinel.
- Detection-as-code = version control + review + CI. The benefit over click-built rules is portability and auditability, the same argument as `gov-iac`.

**Resources:**
- [Sigma — main site / about](https://sigmahq.io/) (~10 min)
- [SigmaHQ rules repository & spec](https://github.com/SigmaHQ/sigma) (~15 min)
- [Sigma rule format specification](https://github.com/SigmaHQ/sigma-specification) (~15 min)

## Hunt threats and correlate events with a query language

*Objective: `siem-hunt` · OSS: OpenSearch Query DSL ≈ SC-500: KQL threat hunting · Lab: [d4-siem-wazuh](../../labs/d4-siem-wazuh.md)*

Threat hunting is proactive, hypothesis-driven searching through collected telemetry — not waiting for a rule to fire, but asking "if an attacker did X, what evidence would be in the index?" and querying for it. In this stack you hunt with the **OpenSearch Query DSL**, a JSON query language: `bool` queries combine `must`/`should`/`must_not`/`filter` clauses; `match`/`term`/`range`/`wildcard` express conditions; and **aggregations** (`terms`, `date_histogram`, `cardinality`) turn millions of events into the counts and top-N breakdowns a hunt needs — e.g. "top source IPs by failed-login count in the last 24h" is a `bool` filter on the rule ID plus a `terms` aggregation on `srcip`.

A worked hunt: index Wazuh alerts, then query `{"query":{"bool":{"filter":[{"term":{"rule.id":"5710"}},{"range":{"@timestamp":{"gte":"now-1h"}}}]}},"aggs":{"by_ip":{"terms":{"field":"data.srcip","size":10}}}}` to surface the noisiest brute-force sources, pivot to that IP across all indices, and confirm/deny the hypothesis. You can run the same in the dashboard's Discover view (DQL) or via the `_search` API. Correlation across sources — matching an auth event to a subsequent process-execution alert — is the SIEM's core investigative value.

SC-500 mapping: OpenSearch Query DSL ≈ **KQL** used for Sentinel hunting; `bool`/`filter` ≈ KQL `where`, aggregations ≈ KQL `summarize ... by`, `date_histogram` ≈ `bin(TimeGenerated, 1h)`. Sentinel ships built-in **hunting queries** and bookmarks; the concept — a query language over centralized logs, hypothesis-driven, MITRE-aligned — is identical. Recognize the equivalence: a DSL `terms` aggregation and a KQL `summarize count() by` answer the same hunting question.

Exam gotchas:
- **Hunting is proactive** (hypothesis → query), distinct from alerting (a rule fires on its own). Exam scenarios that say "search historical logs for signs of X" want hunting, not a new analytics rule.
- Aggregations (`terms`, `date_histogram`, `cardinality`) are what make hunting scale — you rarely eyeball raw events; you summarize and pivot. Same as KQL `summarize`.
- `filter`/`must_not` (non-scoring, cacheable) vs `must`/`should` (scoring) — for security filtering you almost always want `filter`; relevance scoring rarely matters when hunting on exact field values.

**Resources:**
- [OpenSearch Query DSL](https://opensearch.org/docs/latest/query-dsl/) (~20 min)
- [OpenSearch aggregations](https://opensearch.org/docs/latest/aggregations/) (~15 min)
- [Wazuh — threat hunting with the dashboard](https://documentation.wazuh.com/current/user-manual/wazuh-dashboard/threat-hunting.html) (~15 min)

## Automate incident response with active-response actions

*Objective: `siem-response` · OSS: Wazuh active response ≈ SC-500: Sentinel automation rules / SOAR · Lab: [d4-siem-wazuh](../../labs/d4-siem-wazuh.md)*

Detection without response is just a louder alarm. Wazuh **active response** closes the loop: when a rule of a chosen level or ID fires, the manager instructs an agent (or the manager itself) to run a **command/script** — the canonical example being `firewall-drop`, which adds the attacking source IP to the host firewall (iptables/`ipset`/PF) for a **timeout** window, then automatically removes it. Configuration ties three things together in `ossec.conf`: a `<command>` (the executable + whether it takes the src IP), an `<active-response>` block (which command, which agents/location — `local`, `all`, or a specific agent — and the triggering `rule_id`/`level`), and the timeout. Stateful responses auto-revert; stateless ones fire once.

The exam-relevant nuance is the SOAR trade-off: automated blocking is powerful but risky (an attacker spoofing a trusted IP can weaponize `firewall-drop` into self-inflicted denial of service), so you gate it on high-confidence rules, allow-list critical infrastructure, and prefer time-bounded actions. The full response loop — detect (rule) → decide (level/confidence) → act (active response) → contain (block/isolate) → recover (timeout/rollback) — is the incident-response muscle this subsection builds, and it's the natural sink for Falco/Suricata alerts from earlier domains.

SC-500 mapping: Wazuh active response ≈ **Sentinel automation rules + playbooks (Logic Apps) / SOAR**. A Sentinel playbook that blocks an IP at the firewall, disables a user, or isolates a device on an incident trigger is the managed-Azure form of `firewall-drop`. The same cautions apply: automated containment needs guardrails (approval steps, scoping) so it can't be turned against you.

Exam gotchas:
- Active response is **conditional automation** keyed to rule level/ID — not "block everything." Match the trigger (which rule) to the action (which command), and note the **timeout** makes it self-reverting.
- Automated blocking can be **weaponized** (spoofed source → self-DoS). High-confidence-only, allow-list critical hosts, time-bound — the same guardrails the exam wants on any SOAR automation.
- Detect vs respond are distinct stages: a fired alert (detection) does nothing on its own; response is a separate configured action. "Alert fired but the IP wasn't blocked" → no/misconfigured active-response block, not a detection failure.

**Resources:**
- [Wazuh active response](https://documentation.wazuh.com/current/user-manual/capabilities/active-response/index.html) (~20 min)
- [Wazuh — configuring active response](https://documentation.wazuh.com/current/user-manual/capabilities/active-response/how-to-configure.html) (~15 min)

## Summary
| Objective | Takeaway |
|---|---|
| `siem-deploy` | Two tiers: Wazuh manager (detect) + OpenSearch indexer/dashboard (search/store); change default creds & certs; ≈ Microsoft Sentinel |
| `siem-collect` | Agents + syslog/connectors feed the manager; decoders normalize raw logs into fields before rules match; ≈ Sentinel connectors / ASIM |
| `siem-detect` | Sigma = portable YAML detection-as-code, converts to OpenSearch/KQL/SPL; map to MITRE ATT&CK; ≈ Sentinel analytics rules |
| `siem-hunt` | OpenSearch Query DSL `bool`+aggregations, hypothesis-driven, proactive; ≈ KQL threat hunting / `summarize by` |
| `siem-response` | Wazuh active response runs `firewall-drop` on a rule trigger with a timeout; guardrail the SOAR automation; ≈ Sentinel playbooks |
