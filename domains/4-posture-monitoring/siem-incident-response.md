# Operate a SIEM and respond to incidents

Domain 4, subsection 2 (`d4-siem`). A SIEM (Security Information and Event Management) centralizes security telemetry, runs detections against it, and drives the incident-response loop: collect → normalize → detect → hunt → respond. The open-source stack here is **Wazuh** (agents, manager, detection engine, active response) on an **OpenSearch** indexer/dashboard, with **Sigma** as the portable, vendor-neutral detection-as-code format. It maps to **Microsoft Sentinel** end to end. Primary lab: [d4-siem-wazuh](../../labs/d4-siem-wazuh.md) on [`lab-infra/siem`](../../lab-infra/siem/) (Wazuh manager + indexer + dashboard via Docker Compose). This is the heaviest stack in the course — **run it alone**.

## Deploy a SIEM and its search backend

*Objective: `siem-deploy` · OSS: Wazuh + OpenSearch ≈ SC-500: Microsoft Sentinel · Lab: [d4-siem-wazuh](../../labs/d4-siem-wazuh.md)*

A SIEM is really two tiers: an **ingest/detection** tier and a **search/storage** tier. In this stack the **Wazuh manager** is the ingest/detection engine — it receives events from agents and syslog, runs decoders and rules, and generates alerts — while the **Wazuh indexer (a fork of OpenSearch)** stores those alerts and events for search, and the **Wazuh dashboard (a fork of OpenSearch Dashboards)** visualizes them. The Wazuh Docker Compose deployment (`wazuh/wazuh-docker`) brings up `wazuh.manager`, `wazuh.indexer`, and `wazuh.dashboard` as three containers; a single-node indexer is fine for a lab, multi-node for production.

Sizing and security matter even in a lab: the indexer is JVM/Lucene-based and memory-hungry (hence "run it alone" — budget 4 GB+ heap and set `vm.max_map_count=262144` on the host or the indexer container crash-loops on boot), all inter-component traffic and the API use TLS certificates generated at bootstrap, and the indexer ships with default credentials you **must** change. The manager exposes a REST API (`:55000`) for programmatic management and the agents connect on `1514/tcp` (events) and `1515/tcp` (enrollment). Ports at a glance:

```
1514/tcp  agent → manager   event/log stream
1515/tcp  agent → manager   enrollment (authd, key exchange)
55000/tcp manager REST API  programmatic mgmt (TLS)
9200/tcp  indexer           OpenSearch HTTP API (TLS)
443/tcp   dashboard         web UI
```

The bootstrap gotcha most people hit: run the Wazuh Docker `generate-indexer-certs.yml` step **before** `docker compose up`, or the indexer and dashboard fail their mutual-TLS handshake and never come healthy.

SC-500 mapping: the whole thing ≈ **Microsoft Sentinel** — Wazuh manager+indexer ≈ Sentinel's analytics + the Log Analytics workspace it sits on, the Wazuh dashboard ≈ the Sentinel portal (workbooks, incidents, hunting). Where Sentinel is a managed Azure service billed per-GB ingested, this stack is the self-hosted equivalent you stand up and secure yourself — which is exactly why the exam's "what does a SIEM do / what are its tiers" concepts transfer.

Exam gotchas:
- Distinguish the **detection engine** (Wazuh manager / Sentinel analytics) from the **search store** (OpenSearch indexer / Log Analytics workspace). A "we can't search old events" problem is the store; "no alert fired" is the detection engine.
- The Wazuh indexer/dashboard are **OpenSearch/OpenSearch-Dashboards forks** — OpenSearch itself forked from Elasticsearch/Kibana 7.10. If a question names Elastic/Kibana concepts, the OpenSearch equivalents apply.
- Change **default indexer/admin/API credentials** at deploy — shipping defaults is a classic finding. Certs and creds are the two must-harden items.
- Retention/sizing is a **storage-tier** concern (indexer shards, ISM policies), separate from detection. "Old events aged out / disk full" is index lifecycle management, not a rule problem.
- SIEM value follows the **collect→normalize→detect→hunt→respond** loop; a deployment that only stores logs (no rules, no response) is a log lake, not a SIEM. The exam expects the full loop.

**Resources:**
- [Wazuh — getting started / components](https://documentation.wazuh.com/current/getting-started/components/index.html) `[depth]` (~20 min)
- [Wazuh on Docker](https://documentation.wazuh.com/current/deployment-options/docker/index.html) `[depth]` (~15 min)
- [Wazuh architecture](https://documentation.wazuh.com/current/getting-started/architecture.html) `[depth]` (~15 min)
- [OpenSearch — introduction](https://opensearch.org/docs/latest/about/) `[depth]` (~10 min)
- [NIST SP 800-92 — Guide to Computer Security Log Management](https://csrc.nist.gov/pubs/sp/800/92/final) `[depth]` (~30 min)

## Collect and normalize security telemetry from agents and sources

*Objective: `siem-collect` · OSS: Wazuh agents / connectors ≈ SC-500: Sentinel data connectors · Lab: [d4-siem-wazuh](../../labs/d4-siem-wazuh.md)*

Detection is only as good as ingestion. The **Wazuh agent** runs on endpoints and ships log data, file-integrity events, security-config assessment results, and inventory to the manager; agentless sources arrive via **syslog** (`514`), the manager's log collector, or integrations that pull from cloud audit logs (AWS CloudTrail, Azure activity, GCP, Office 365, Docker). The critical concept is **normalization**: raw log lines are meaningless until parsed. Wazuh does this with **decoders** — regex/JSON parsers that extract fields (`srcip`, `srcuser`, `program_name`) into a common schema — and **rules** then match on those normalized fields. This decode→normalize→rule pipeline is the same "connector → parse → schema" pattern every SIEM uses.

Concretely, an agent forwards `/var/log/auth.log`; a decoder recognizes `sshd` lines and extracts the source IP and user; a rule (`5710`, `5712`) fires on repeated failures. The Wazuh rule that ties normalized fields to a detection looks like:

```xml
<rule id="100120" level="10" frequency="8" timeframe="120">
  <if_matched_sid>5710</if_matched_sid>   <!-- 5710 = sshd auth failure -->
  <same_source_ip/>
  <description>SSH brute force: 8 failures from same source in 120s</description>
  <mitre><id>T1110</id></mitre>          <!-- ATT&CK: Brute Force -->
</rule>
```

Note the `frequency`/`timeframe`/`same_source_ip` correlation and the explicit MITRE ATT&CK tag. For Kubernetes/container security telemetry — Falco alerts from `d3`, audit logs — you forward JSON to the manager and a JSON decoder normalizes it (Falco already emits JSON, so the built-in `json` decoder lifts `output_fields` straight into searchable fields). Wazuh alerts land in the indexer as documents you search in the next objective.

SC-500 mapping: Wazuh agents/connectors ≈ **Sentinel data connectors** (the Azure Monitor Agent, the Log Analytics agent's successor, and the codeless/CEF/syslog connectors). Wazuh decoders ≈ Sentinel's parsers / ASIM (Advanced Security Information Model) normalization. "Onboard a data source" on the exam ≈ deploy the agent or wire a connector; "normalize to a common schema" ≈ ASIM ≈ Wazuh decoders.

Exam gotchas:
- **Normalization before detection**: you cannot write a portable rule on `srcip` until a decoder produces `srcip`. Un-parsed logs are just text — a common "why doesn't my rule match" root cause.
- Agent-based (rich endpoint telemetry, FIM, SCA) vs agentless/syslog (network gear, appliances) — know when each applies; you can't put an agent on a switch, so it sends syslog.
- Ingestion is where **cost and noise** are decided (in Sentinel it's literal per-GB billing). Filtering/routing at collection time is a real design lever, not just detection tuning.
- **Decoder order matters**: Wazuh applies a parent decoder then children; a custom decoder that doesn't chain (`<parent>`) or sits below a broader match can silently never fire. "Fields aren't extracted" is a decoder-ordering/precedence bug.
- Time sync (NTP) across sources is a prerequisite for correlation — skewed clocks scatter related events across the timeline and break `timeframe` rules. A collection-hygiene item the exam favors.

**Resources:**
- [Wazuh agent — how it works](https://documentation.wazuh.com/current/user-manual/agent/agent-management/index.html) `[depth]` (~15 min)
- [Wazuh decoders (ruleset)](https://documentation.wazuh.com/current/user-manual/ruleset/decoders/index.html) `[depth]` (~15 min)
- [Wazuh log data collection](https://documentation.wazuh.com/current/user-manual/capabilities/log-data-collection/index.html) `[depth]` (~15 min)
- [Microsoft Sentinel ASIM (normalization) overview](https://learn.microsoft.com/en-us/azure/sentinel/normalization) `[depth]` (~15 min)

## Engineer detections with portable detection-as-code rules

*Objective: `siem-detect` · OSS: Sigma rules ≈ SC-500: Sentinel analytics rules · Lab: [d4-siem-wazuh](../../labs/d4-siem-wazuh.md)*

**Sigma** is "the YARA/Snort of logs": a vendor-neutral YAML format for expressing a detection once, then *converting* it to whatever backend query language your SIEM speaks. A Sigma rule has a `logsource` (category/product, e.g. `product: linux`, `service: sshd`), a `detection` block with named **selections** and a boolean `condition`, plus metadata (`level`, `tags` mapped to MITRE ATT&CK):

```yaml
title: SSH Brute Force Followed by Success
status: experimental
logsource: { product: linux, service: sshd }
detection:
  failures:  { CommandName: 'Failed password' }
  success:   { CommandName: 'Accepted password' }
  timeframe: 5m
  condition: failures | count() by SourceIp > 10 and success
level: high
tags: [ attack.credential_access, attack.t1110.001 ]   # ATT&CK Brute Force: Password Guessing
```

The `sigma` CLI (now the `sigma-cli` / **pySigma** toolchain), optionally with a backend field-mapping pipeline, emits an OpenSearch/Elasticsearch query, a Splunk SPL search, a **Sentinel KQL** analytics rule, and so on from the *same* YAML. A pipeline isn't always needed. Note the CLI's target id for this backend is **`opensearch_lucene`**, not `opensearch` — and `sigma list pipelines opensearch_lucene` comes back **empty**: that target registers no pipeline at all (the **ECS** mappings you'll see under a bare `sigma list pipelines` — Winlogbeat/Sysmon, Zeek, Kubernetes audit, macOS ESF — are scoped to *other* targets). That's correct here, not a gap to work around: a Linux/sshd rule whose `detection` is a plain **keyword** selection has no field names for a pipeline to remap, so you convert `--without-pipeline` and the keyword search runs against the raw log text:

```bash
sigma list pipelines opensearch_lucene                                   # empty — this target registers no pipeline
sigma convert -t opensearch_lucene --without-pipeline rules/ssh_bruteforce.yml   # → OpenSearch DSL (keyword match, no remap)
sigma convert -t microsoft365defender  rules/ssh_bruteforce.yml        # → Sentinel/Defender KQL
```

This is detection-as-code: version-controlled, peer-reviewed, portable across tools, which is why it's the exam-relevant answer to "how do we avoid re-writing every detection per vendor."

Wazuh has its own native XML rule/decoder engine (the manager evaluates it in real time), so in practice you either (a) author Wazuh rules directly, or (b) author Sigma and convert it to the OpenSearch query you save as a monitor/detection, or to an equivalent Wazuh rule. The point for SC-500 is the *concept*: portable detection content mapped to ATT&CK, reviewed like code.

SC-500 mapping: Sigma ≈ the **portable content** that becomes **Sentinel analytics rules** (scheduled KQL rules). The Sentinel community publishes analytics rules and hunting queries as code in a GitHub repo, and the Sigma→KQL backend targets Sentinel directly. Sigma `level`/`tags` ≈ Sentinel rule severity + MITRE tactic mapping. "Write a detection once, deploy to many SIEMs" is the Sigma value proposition and a likely exam framing.

Exam gotchas:
- Sigma is a **format/abstraction**, not a running engine — it doesn't detect anything until *converted* to a backend query (OpenSearch DSL, KQL, SPL). "Deploy Sigma to watch logs" is imprecise; you convert then deploy.
- Map detections to **MITRE ATT&CK** (`tags: attack.t1110` = brute force). Tactic/technique tagging is expected of modern detection content, in Sigma and in Sentinel.
- Detection-as-code = version control + review + CI. The benefit over click-built rules is portability and auditability, the same argument as `gov-iac`.
- Not every conversion needs a **pipeline** — `sigma list pipelines <backend>` shows what's registered, and it's a fixed catalog of source-specific ECS/ASIM/Wazuh mappings, not a menu where any entry works. Picking one that doesn't match the rule's `logsource` (e.g. a Windows/Sysmon pipeline for a Linux/sshd rule) silently renames fields to ones that don't exist in the data — "Sigma converted but matches nothing" is usually this gap, not a syntax error.
- Sigma expresses **detection logic**, not response — pair it with active response (`siem-response`) for action. It's the *what to detect*, not the *what to do*.

**Resources:**
- [Sigma — main site / about](https://sigmahq.io/) (reference) (~10 min)
- [SigmaHQ rules repository](https://github.com/SigmaHQ/sigma) `[depth]` (~15 min)
- [Sigma rule format specification](https://github.com/SigmaHQ/sigma-specification) `[depth]` (~15 min)
- [MITRE ATT&CK — matrix & techniques](https://attack.mitre.org/) (reference) (~25 min)
- [pySigma / sigma-cli backends](https://github.com/SigmaHQ/pySigma) `[required-for-lab]` (~10 min)

## Hunt threats and correlate events with a query language

*Objective: `siem-hunt` · OSS: OpenSearch Query DSL ≈ SC-500: KQL threat hunting · Lab: [d4-siem-wazuh](../../labs/d4-siem-wazuh.md)*

Threat hunting is proactive, hypothesis-driven searching through collected telemetry — not waiting for a rule to fire, but asking "if an attacker did X, what evidence would be in the index?" and querying for it. In this stack you hunt with the **OpenSearch Query DSL**, a JSON query language: `bool` queries combine `must`/`should`/`must_not`/`filter` clauses; `match`/`term`/`range`/`wildcard` express conditions; and **aggregations** (`terms`, `date_histogram`, `cardinality`) turn millions of events into the counts and top-N breakdowns a hunt needs — e.g. "top source IPs by failed-login count in the last 24h" is a `bool` filter on the rule ID plus a `terms` aggregation on `srcip`.

A worked hunt: index Wazuh alerts, then query `{"query":{"bool":{"filter":[{"term":{"rule.id":"5710"}},{"range":{"@timestamp":{"gte":"now-1h"}}}]}},"aggs":{"by_ip":{"terms":{"field":"data.srcip","size":10}}}}` to surface the noisiest brute-force sources, pivot to that IP across all indices, and confirm/deny the hypothesis. You can run the same in the dashboard's Discover view (DQL) or via the `_search` API. Correlation across sources — matching an auth event to a subsequent process-execution alert — is the SIEM's core investigative value.

SC-500 mapping: OpenSearch Query DSL ≈ **KQL** used for Sentinel hunting; `bool`/`filter` ≈ KQL `where`, aggregations ≈ KQL `summarize ... by`, `date_histogram` ≈ `bin(TimeGenerated, 1h)`. Sentinel ships built-in **hunting queries** and bookmarks; the concept — a query language over centralized logs, hypothesis-driven, MITRE-aligned — is identical. Recognize the equivalence: a DSL `terms` aggregation and a KQL `summarize count() by` answer the same hunting question.

Exam gotchas:
- **Hunting is proactive** (hypothesis → query), distinct from alerting (a rule fires on its own). Exam scenarios that say "search historical logs for signs of X" want hunting, not a new analytics rule.
- Aggregations (`terms`, `date_histogram`, `cardinality`) are what make hunting scale — you rarely eyeball raw events; you summarize and pivot. Same as KQL `summarize`.
- `filter`/`must_not` (non-scoring, cacheable) vs `must`/`should` (scoring) — for security filtering you almost always want `filter`; relevance scoring rarely matters when hunting on exact field values.
- Hunting is **hypothesis-driven and often ATT&CK-mapped**: you start from a technique ("would credential dumping / T1003 leave traces here?") and query for it. A hunt that finds a repeatable signal should be **promoted to a detection rule** — the hunt→detection feedback loop.
- Aggregations run over the **matched** set — filter tight first (time range + index) or a `terms`/`cardinality` agg over billions of docs is slow or OOMs the indexer. Same discipline as narrowing a LogQL/KQL query before summarizing.

**Resources:**
- [OpenSearch Query DSL](https://opensearch.org/docs/latest/query-dsl/) `[depth]` (~20 min)
- [OpenSearch aggregations](https://opensearch.org/docs/latest/aggregations/) `[depth]` (~15 min)
- [Wazuh — threat hunting with the dashboard](https://documentation.wazuh.com/current/user-manual/wazuh-dashboard/threat-hunting.html) `[depth]` (~15 min)
- [MITRE ATT&CK — Get Started: Detections & Analytics](https://attack.mitre.org/resources/get-started/detections-and-analytics/) `[depth]` (~20 min)
- [Microsoft Sentinel — threat hunting (KQL) docs](https://learn.microsoft.com/en-us/azure/sentinel/hunting) `[depth]` (~15 min)

## Automate incident response with active-response actions

*Objective: `siem-response` · OSS: Wazuh active response ≈ SC-500: Sentinel automation rules / SOAR · Lab: [d4-siem-wazuh](../../labs/d4-siem-wazuh.md)*

Detection without response is just a louder alarm. Wazuh **active response** closes the loop: when a rule of a chosen level or ID fires, the manager instructs an agent (or the manager itself) to run a **command/script** — the canonical example being `firewall-drop`, which adds the attacking source IP to the host firewall (iptables/`ipset`/PF) for a **timeout** window, then automatically removes it. Configuration ties three things together in `ossec.conf`: a `<command>` (the executable + whether it takes the src IP), an `<active-response>` block (which command, which agents/location — `local`, `all`, or a specific agent — and the triggering `rule_id`/`level`), and the timeout:

```xml
<command>
  <name>firewall-drop</name>
  <executable>firewall-drop</executable>
  <timeout_allowed>yes</timeout_allowed>
</command>
<active-response>
  <command>firewall-drop</command>
  <location>local</location>          <!-- act on the agent that saw it -->
  <rules_id>100120</rules_id>          <!-- the SSH brute-force rule -->
  <timeout>600</timeout>               <!-- auto-remove the block after 10m -->
</active-response>
```

Because `timeout_allowed` is `yes`, this is a **stateful** response — the block auto-reverts after 600s. A stateless command (no timeout) fires once and never undoes itself.

The exam-relevant nuance is the SOAR trade-off: automated blocking is powerful but risky (an attacker spoofing a trusted IP can weaponize `firewall-drop` into self-inflicted denial of service), so you gate it on high-confidence rules, allow-list critical infrastructure, and prefer time-bounded actions. The full response loop — detect (rule) → decide (level/confidence) → act (active response) → contain (block/isolate) → recover (timeout/rollback) — is the incident-response muscle this subsection builds, and it's the natural sink for Falco/Suricata alerts from earlier domains.

SC-500 mapping: Wazuh active response ≈ **Sentinel automation rules + playbooks (Logic Apps) / SOAR**. A Sentinel playbook that blocks an IP at the firewall, disables a user, or isolates a device on an incident trigger is the managed-Azure form of `firewall-drop`. The same cautions apply: automated containment needs guardrails (approval steps, scoping) so it can't be turned against you.

Exam gotchas:
- Active response is **conditional automation** keyed to rule level/ID — not "block everything." Match the trigger (which rule) to the action (which command), and note the **timeout** makes it self-reverting.
- Automated blocking can be **weaponized** (spoofed source → self-DoS). High-confidence-only, allow-list critical hosts, time-bound — the same guardrails the exam wants on any SOAR automation.
- Detect vs respond are distinct stages: a fired alert (detection) does nothing on its own; response is a separate configured action. "Alert fired but the IP wasn't blocked" → no/misconfigured active-response block, not a detection failure.
- **Stateful (timeout, auto-revert) vs stateless (one-shot)** is the config distinction — `timeout_allowed`/`<timeout>` makes containment self-healing. Know which the scenario needs.
- Response fits the **NIST 800-61 lifecycle** (prepare → detect/analyze → contain/eradicate/recover → post-incident). `firewall-drop` is *containment*; it isn't eradication or recovery. Don't overclaim what an automated block accomplishes.

**Resources:**
- [Wazuh active response](https://documentation.wazuh.com/current/user-manual/capabilities/active-response/index.html) `[depth]` (~20 min)
- [Wazuh — configuring active response](https://documentation.wazuh.com/current/user-manual/capabilities/active-response/how-to-configure.html) `[depth]` (~15 min)
- [NIST SP 800-61r2 — Computer Security Incident Handling Guide](https://csrc.nist.gov/pubs/sp/800/61/r2/final) `[depth]` (~30 min)
- [Microsoft Sentinel — automation rules & playbooks (SOAR)](https://learn.microsoft.com/en-us/azure/sentinel/automation/automation) `[depth]` (~15 min)

## Summary
| Objective | Takeaway |
|---|---|
| `siem-deploy` | Two tiers: Wazuh manager (detect) + OpenSearch indexer/dashboard (search/store); change default creds & certs; ≈ Microsoft Sentinel |
| `siem-collect` | Agents + syslog/connectors feed the manager; decoders normalize raw logs into fields before rules match; ≈ Sentinel connectors / ASIM |
| `siem-detect` | Sigma = portable YAML detection-as-code, converts to OpenSearch/KQL/SPL; map to MITRE ATT&CK; ≈ Sentinel analytics rules |
| `siem-hunt` | OpenSearch Query DSL `bool`+aggregations, hypothesis-driven, proactive; ≈ KQL threat hunting / `summarize by` |
| `siem-response` | Wazuh active response runs `firewall-drop` on a rule trigger with a timeout; guardrail the SOAR automation; ≈ Sentinel playbooks |
