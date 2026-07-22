# Checkpoint 4 — Manage and monitor security posture

Generated from `assessment/data/quiz-4.yaml` — study-hub runs this interactively (Tests page). Pass bar: 80%. 31 questions.

### 1. A developer asks how to "make our app push its metrics to Prometheus so the security team can graph request errors." What is the correct guidance for a standard long-running service?

- A. Add a Pushgateway and have the app push on every request
- B. Expose a /metrics endpoint and let Prometheus scrape it, selected by a ServiceMonitor
- C. Write the metrics into Loki and query them with LogQL
- D. Send the metrics over OTLP directly into Alertmanager

<details><summary>Answer</summary>

**B** — Prometheus is pull-based: the service exposes /metrics and a ServiceMonitor tells Prometheus to scrape it — no code pushes metrics. The Pushgateway is only for short-lived batch jobs and is an anti-pattern for services. Metrics don't go into Loki, and Alertmanager routes alerts, it doesn't ingest metrics.

[Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/) · objectives: `obs-metrics`

</details>

### 2. An engineer wants to label every Prometheus metric (and Loki log stream) with the full request URL and a unique request ID so they can filter precisely. Why is this a bad idea in both systems?

- A. Labels are case-sensitive and URLs contain mixed case
- B. High-cardinality labels (unique per request) explode memory and index size — that data belongs in the log line/trace, not a label
- C. Prometheus and Loki forbid more than three labels per series
- D. Only Alertmanager is allowed to add labels

<details><summary>Answer</summary>

**B** — Both Prometheus and Loki index by labels, and a label whose value is unique per request (request ID, full URL) creates unbounded cardinality that wrecks memory and performance. Put high-cardinality detail in the log content or trace, and keep labels low-cardinality (namespace, app, pod).

[Documentation](https://grafana.com/docs/loki/latest/get-started/labels/) · objectives: `obs-metrics`, `obs-logs`

</details>

### 3. You need to alert when the rate of "Failed password" lines from a namespace crosses a threshold, but there is no metric for it — only the raw logs in Loki. What is the most direct approach?

- A. Export the logs to Prometheus as a counter first
- B. Use a LogQL metric query such as sum(rate({namespace="x"} |= "Failed password" [5m])) and alert on it
- C. Loki cannot turn logs into a rate; you must add application instrumentation
- D. Query Tempo for the failed-login spans

<details><summary>Answer</summary>

**B** — LogQL can derive metrics from logs with functions like rate() and count_over_time() over a filtered stream, so you can alert on a log-derived rate without any new metric instrumentation. That is exactly Loki's log-to-metric capability.

[Documentation](https://grafana.com/docs/loki/latest/query/metric_queries/) · objectives: `obs-logs`

</details>

### 4. Your team is choosing between Loki and OpenSearch for a log store. The security analysts need fast arbitrary full-text search across every field of years of logs for deep hunting. Which statement is accurate?

- A. Loki is the better fit because it full-text indexes every field
- B. OpenSearch fits richer full-text hunting; Loki indexes only labels and filters content at query time, trading search richness for lower cost
- C. They are functionally identical; pick either
- D. Neither can do full-text search; use Prometheus

<details><summary>Answer</summary>

**B** — Loki deliberately indexes only labels and stores raw lines cheaply, filtering content at query time — great for cost, weaker for arbitrary full-text search. OpenSearch/Elasticsearch maintain per-field inverted indexes suited to rich hunting. Know when a scenario wants Loki vs OpenSearch.

[Documentation](https://grafana.com/docs/loki/latest/get-started/overview/) · objectives: `obs-logs`

</details>

### 5. A request touches eight microservices and is intermittently slow. Metrics show overall latency is up but not which hop is responsible. Which signal pinpoints the offending service, and how is it collected here?

- A. Logs, collected by Promtail into Loki
- B. Distributed traces, emitted as OTLP to the OpenTelemetry Collector and stored in Tempo
- C. More Prometheus histograms on the frontend only
- D. Alertmanager inhibition rules

<details><summary>Answer</summary>

**B** — Traces answer "where in the call graph" — the span tree shows exactly which downstream hop added latency. Apps emit OTLP to the OpenTelemetry Collector, which exports spans to Tempo. Metrics tell you how much/how often; traces localize it across services.

[Documentation](https://opentelemetry.io/docs/what-is-opentelemetry/) · objectives: `obs-traces`

</details>

### 6. You want one instrumentation standard that can send traces to Tempo, metrics to Prometheus, and logs to Loki without a separate agent per backend. What component provides this fan-out?

- A. A Prometheus Pushgateway per backend
- B. The OpenTelemetry Collector — receivers (OTLP) → processors → exporters to multiple backends
- C. A Grafana data source proxy
- D. The Wazuh manager

<details><summary>Answer</summary>

**B** — The OpenTelemetry Collector is a deploy-once pipeline: OTLP receivers feed processors (batch, memory_limiter, sampling) and exporters route traces, metrics, and logs to their respective backends. One instrumentation, many backends — the modern convergence pattern.

[Documentation](https://opentelemetry.io/docs/collector/) · objectives: `obs-traces`

</details>

### 7. During an incident, someone panics: "Grafana just crashed — did we lose all our metrics and logs?" What is the correct answer and why?

- A. Yes, Grafana is the primary store for metrics and logs
- B. No — Grafana only visualizes/queries the backends; the data lives in Prometheus, Loki, and Tempo and is untouched
- C. Only traces are lost because Tempo runs inside Grafana
- D. Yes, unless dashboards were exported to PDF first

<details><summary>Answer</summary>

**B** — Grafana stores no telemetry itself — it is a visualization/correlation layer querying Prometheus, Loki, and Tempo. Losing Grafana loses no data, and provisioned dashboards (JSON in Git) come back on restart. This is the "single pane" being stateless.

[Documentation](https://grafana.com/docs/grafana/latest/fundamentals/) · objectives: `obs-dashboards`

</details>

### 8. A PromQL alert rule shows "Firing" in the Prometheus UI, but the on-call engineer never received a page. Where is the fault most likely?

- A. The PromQL expression is wrong
- B. Alertmanager routing/receiver configuration — the condition fired, but delivery is misconfigured
- C. The metric isn't being scraped
- D. The dashboard panel is broken

<details><summary>Answer</summary>

**B** — Rule evaluation (the condition) lives in Prometheus; routing and delivery live in Alertmanager. "Firing but no page" means the condition worked and the Alertmanager route/receiver (or a silence) is the problem. Rule vs route are separate layers — match the symptom to the layer.

[Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/) · objectives: `obs-alerting`

</details>

### 9. An alert fires and resolves every few seconds on transient blips, paging the team constantly. Which change best stops the flapping without hiding real problems?

- A. Delete the alert rule
- B. Add a `for:` duration so the condition must hold continuously before firing
- C. Route the alert to a second email address
- D. Increase Prometheus retention

<details><summary>Answer</summary>

**B** — A `for:` clause requires the expression to be true continuously for the window before the alert fires, filtering out transient blips. Grouping in Alertmanager further reduces noise, but the `for:` duration is the direct anti-flap control on the rule itself.

[Documentation](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/) · objectives: `obs-alerting`

</details>

### 10. You have planned maintenance on a namespace tonight and don't want its alerts paging anyone, but you want the rules to keep evaluating. What Alertmanager feature fits?

- A. Inhibition rules
- B. A silence matching the namespace label for the maintenance window
- C. Deleting the receiver
- D. Lowering the alert severity label

<details><summary>Answer</summary>

**B** — A silence mutes notifications matching label criteria for a time window while rules keep evaluating — exactly the maintenance case. Inhibition suppresses lower-severity alerts when a higher one fires (a different purpose), and deleting receivers is destructive.

[Documentation](https://prometheus.io/docs/alerting/latest/configuration/) · objectives: `obs-alerting`

</details>

### 11. In the Wazuh + OpenSearch SIEM, analysts report they can see new alerts but cannot search events older than a few days. Which tier should you investigate?

- A. The Wazuh manager's decoders
- B. The Wazuh indexer (OpenSearch) — the search/storage tier and its retention
- C. The active-response configuration
- D. The Sigma conversion pipeline

<details><summary>Answer</summary>

**B** — A SIEM has a detection engine (Wazuh manager) and a search/storage tier (OpenSearch indexer). "Can't search old events" is a storage/retention issue in the indexer; "no alert fired" would point at the manager's rules. Separate the tiers when triaging.

[Documentation](https://documentation.wazuh.com/current/getting-started/components/index.html) · objectives: `siem-deploy`

</details>

### 12. Reviewing a freshly deployed Wazuh + OpenSearch stack for hardening, which TWO items are the classic must-fix findings before it goes live?

- A. Change the default indexer/admin/API credentials
- B. Ensure TLS certificates secure inter-component and API traffic
- C. Disable all decoders to reduce noise
- D. Remove the dashboard so nothing is exposed

<details><summary>Answer</summary>

**A, B** (multiple answers) — Shipping default credentials and running without proper TLS between the manager, indexer, and dashboard are the two canonical hardening gaps. Decoders are needed for normalization, and the dashboard is the analyst UI — you secure them, you don't remove them.

[Documentation](https://documentation.wazuh.com/current/deployment-options/docker/index.html) · objectives: `siem-deploy`

</details>

### 13. An analyst writes a detection that keys on the field `data.srcip`, but it never matches even though the raw SSH logs clearly contain source IPs. What is the most likely root cause?

- A. OpenSearch is down
- B. No decoder is normalizing the raw log into the srcip field, so there is nothing structured to match
- C. The rule level is too high
- D. Active response consumed the events

<details><summary>Answer</summary>

**B** — Detection depends on normalization: a decoder must parse the raw line and extract srcip before any rule can match that field. Un-parsed logs are just text — the classic "why doesn't my rule fire" cause. This is the ASIM/parser concept in Sentinel terms.

[Documentation](https://documentation.wazuh.com/current/user-manual/ruleset/decoders/index.html) · objectives: `siem-collect`

</details>

### 14. You must onboard a managed network switch that cannot run an endpoint agent into the SIEM. What is the appropriate collection method?

- A. Install the Wazuh agent on the switch
- B. Forward the switch's syslog to the Wazuh manager's syslog listener
- C. Nothing — network devices can't be monitored
- D. Scrape the switch with a Prometheus ServiceMonitor

<details><summary>Answer</summary>

**B** — Appliances and network gear that can't host an agent send syslog to the manager, where a decoder normalizes it. Agent-based collection gives richer endpoint telemetry (FIM, SCA) but isn't possible on a switch — the agent-vs-agentless choice depends on the source.

[Documentation](https://documentation.wazuh.com/current/user-manual/agent/agent-management/index.html) · objectives: `siem-collect`

</details>

### 15. Your org runs Wazuh today but may move to a different SIEM next year. Leadership wants detection content that won't have to be rewritten per vendor. What approach delivers this?

- A. Hard-code all detections as native vendor rules and export them as PDFs
- B. Author detections as Sigma rules and convert them to each backend's query language (OpenSearch DSL, KQL, SPL)
- C. Only use the vendor's built-in rules
- D. Store detections as Grafana dashboards

<details><summary>Answer</summary>

**B** — Sigma is a vendor-neutral YAML detection format; the sigma CLI converts one rule to OpenSearch, Sentinel KQL, Splunk SPL, etc. That portability — plus version control and review — is detection-as-code, the answer to "write once, deploy to many SIEMs."

[Documentation](https://sigmahq.io/) · objectives: `siem-detect`

</details>

### 16. You convert a Sigma rule with the sigma CLI and deploy the output to OpenSearch, but it never matches — the rule keys on `Image` and `CommandLine` while your indexed events use ECS-style `process.executable` and `process.command_line`. What did the conversion get wrong?

- A. Sigma rules cannot be converted to OpenSearch at all
- B. The conversion needs the right processing pipeline (field-mapping) alongside the backend — the backend selects the query language, the pipeline maps Sigma's logsource/field names onto the target schema; without the matching pipeline the fields never line up
- C. The rule must be hand-rewritten field-by-field for every backend
- D. OpenSearch requires the rule to be registered as a Prometheus recording rule first

<details><summary>Answer</summary>

**B** — `sigma convert` takes two things: a backend (the target query language, e.g. OpenSearch DSL) and a processing pipeline that translates Sigma's taxonomy and field names into the destination schema (e.g. ECS). Pick the backend but the wrong or no pipeline and you get syntactically valid queries whose field names never match the indexed data — backend + pipeline together are the conversion mechanics.

[Documentation](https://github.com/SigmaHQ/sigma) · objectives: `siem-detect`

</details>

### 17. A hunter hypothesizes SSH brute force is occurring and wants the top source IPs by failed-login count in the last hour from the alerts index. Which OpenSearch Query DSL construction fits?

- A. A match_all query with no aggregation
- B. A bool query filtering on the failed-login rule id and a time range, plus a terms aggregation on the srcip field
- C. A single term query on the message text only
- D. An Alertmanager route matcher

<details><summary>Answer</summary>

**B** — Hunting summarizes and pivots: a bool/filter narrows to the rule id and time window, and a terms aggregation on srcip returns the top offenders — the DSL analogue of KQL `where ... | summarize count() by srcip`. Aggregations are what make hunting scale.

[Documentation](https://opensearch.org/docs/latest/aggregations/) · objectives: `siem-hunt`

</details>

### 18. Which statement best distinguishes threat hunting from alerting in the SIEM?

- A. Hunting is fully automated and requires no analyst
- B. Hunting is proactive and hypothesis-driven — you query historical telemetry for evidence — whereas an alert rule fires on its own when a condition matches
- C. Alerting searches history; hunting waits for rules to fire
- D. They are the same activity with different names

<details><summary>Answer</summary>

**B** — Hunting starts from a hypothesis ("if an attacker did X, what evidence exists?") and queries the collected data proactively; alerting is a standing rule that fires when its condition is met. A scenario that says "search historical logs for signs of X" is hunting, not a new analytics rule.

[Documentation](https://opensearch.org/docs/latest/query-dsl/) · objectives: `siem-hunt`

</details>

### 19. You configure Wazuh active response with firewall-drop bound to a high-level brute-force rule and a 600-second timeout. During testing, an attacker spoofs packets with the source IP of your upstream DNS resolver. What risk does this illustrate, and what mitigates it?

- A. No risk — active response is always safe
- B. Automated blocking can be weaponized into self-DoS via spoofed sources; mitigate by triggering only on high-confidence rules, allow-listing critical infrastructure, and time-bounding the block
- C. The timeout makes the block permanent, which is the fix
- D. The only fix is to disable the indexer

<details><summary>Answer</summary>

**B** — firewall-drop adds the (attacker-controlled) source IP to the host firewall, so a spoofed trusted IP can turn the automation against you. Guardrails: high-confidence rules only, allow-list critical hosts, and a timeout that auto-reverts. Same cautions as any SOAR playbook.

[Documentation](https://documentation.wazuh.com/current/user-manual/capabilities/active-response/index.html) · objectives: `siem-response`

</details>

### 20. A brute-force alert fired in Wazuh, but the attacker's IP was never blocked on the agent. Detection clearly worked. Where do you look?

- A. The decoder that parses auth.log
- B. The active-response configuration — the response stage is separate from detection and is likely unbound or the rule id/level didn't match the trigger
- C. The OpenSearch retention setting
- D. The Grafana data source

<details><summary>Answer</summary>

**B** — Detection (a fired rule) and response (running firewall-drop) are distinct stages. If the alert fired but nothing was blocked, the active-response block is misconfigured or its rule_id/level didn't match. Alert firing never implies a block occurred.

[Documentation](https://documentation.wazuh.com/current/user-manual/capabilities/active-response/how-to-configure.html) · objectives: `siem-response`, `siem-detect`

</details>

### 21. Security wants network detection that can actually DROP a known exploit inline, accepting that the sensor now sits in the traffic path. Which Suricata deployment mode is required?

- A. IDS mode reading a SPAN/mirror port
- B. IPS mode inline (e.g. via NFQUEUE), with drop/reject rule actions
- C. Passive AF-PACKET capture only
- D. Zeek in cluster mode

<details><summary>Answer</summary>

**B** — Only inline IPS mode (traffic passes through Suricata, typically via NFQUEUE) can drop/reject packets. A mirror/tap in IDS mode can alert but never block. Inline enables prevention at the cost of being in the failure path — the core IDS-vs-IPS trade-off.

[Documentation](https://docs.suricata.io/en/latest/setup-guides/nftables.html) · objectives: `nid-suricata`

</details>

### 22. A Suricata sensor has been running for months but has never generated an alert, even during a known incident. Its interface is definitely seeing traffic. What is the most likely cause?

- A. Suricata cannot generate alerts without Grafana
- B. Its ruleset is empty or stale — the rules are the detection content and must be maintained (e.g. suricata-update with ET Open)
- C. IDS mode never alerts; only IPS does
- D. EVE JSON output is disabled, so detection stopped

<details><summary>Answer</summary>

**B** — An IDS with no/stale rules detects nothing — the ruleset is the detection content. suricata-update pulls and maintains feeds like ET Open; sid/rev version rules. (EVE JSON only affects where alerts are written, not whether detection occurs.)

[Documentation](https://docs.suricata.io/en/latest/rules/intro.html) · objectives: `nid-suricata`

</details>

### 23. An attacker is using a brand-new C2 domain with no signature in any feed, but an internal host beacons to it every 60 seconds. Which tool is best suited to surface this, and how?

- A. Suricata, because it blocks all unknown domains by default
- B. Zeek, whose conn.log/dns.log capture the behavior (periodic connections to a rare domain) so you can hunt the anomaly without any signature
- C. Alertmanager inhibition
- D. kube-bench node checks

<details><summary>Answer</summary>

**B** — Zeek logs behavior — conn.log and dns.log record the periodic beaconing to a rare domain even with no signature to match. Suricata excels at known threats via signatures; novel/behavioral detection is Zeek's strength. They're complementary on the same tap.

[Documentation](https://docs.zeek.org/en/master/logs/index.html) · objectives: `nid-zeek`

</details>

### 24. How would you best summarize the division of labor between Suricata and Zeek when both run on the same network tap?

- A. Both are signature engines; running two is redundant
- B. Suricata answers 'did a known-bad signature match?' (and can block inline); Zeek answers 'record everything that happened' for behavioral hunting and enrichment
- C. Zeek blocks traffic while Suricata only logs
- D. Suricata replaces the SIEM; Zeek replaces Prometheus

<details><summary>Answer</summary>

**B** — Suricata is the signature alarm (and, inline, the blocker); Zeek is the DVR producing rich protocol logs for hunting and for enriching Suricata alerts with full connection context. Complementary, not redundant — precision on known threats plus breadth of behavioral context.

[Documentation](https://docs.zeek.org/en/master/about.html) · objectives: `nid-zeek`, `nid-suricata`

</details>

### 25. A team runs Trivy on every image and reports "our posture is fully covered." An auditor notes pods running privileged with hostPath mounts. What capability is missing, and which tool provides it?

- A. Nothing is missing; Trivy covers configuration too
- B. Configuration/posture scanning of the cluster — Kubescape evaluates controls like privileged, hostPath, RBAC, and admission risk, which image CVE scanning does not
- C. A faster image registry
- D. More Prometheus exporters

<details><summary>Answer</summary>

**B** — Image CVE scanning (Trivy) and configuration/posture scanning (Kubescape) are different problems. Privileged/hostPath/RBAC misconfigurations are posture findings that Kubescape surfaces; Trivy would never flag them. CSPM ≠ vulnerability management.

[Documentation](https://kubescape.io/docs/) · objectives: `vuln-cluster`

</details>

### 26. On a managed AKS cluster, a requirement says "run kube-bench to audit the API server and etcd against the CIS Benchmark." Why is this partially infeasible?

- A. kube-bench only runs on Windows nodes
- B. The managed control plane (API server, etcd) is operated by the cloud provider under shared responsibility — you can audit your nodes/kubelet, not the master components
- C. CIS benchmarks don't cover Kubernetes
- D. kube-bench requires Defender for Cloud to run

<details><summary>Answer</summary>

**B** — On managed clusters the provider owns and hides the control plane, so you can't benchmark the API server/etcd flags — only the node/kubelet portions you control. On a self-managed cluster (like kind) kube-bench audits everything. This is a shared-responsibility distinction.

[Documentation](https://github.com/aquasecurity/kube-bench) · objectives: `vuln-cis`

</details>

### 27. kube-bench output lists a check as [WARN]/Manual. A junior engineer marks it "passed" to close the ticket. What is the correct interpretation?

- A. [WARN]/Manual means the check passed automatically
- B. [WARN]/Manual items require human verification — they are not automatically a PASS and must be reviewed against the remediation guidance
- C. [WARN] means the tool errored and can be ignored
- D. Manual checks are always non-compliant

<details><summary>Answer</summary>

**B** — CIS checks are Scored/Not Scored and Automated/Manual. A [WARN]/Manual result needs a human to verify the control against the remediation text — it is neither an automatic pass nor an automatic fail. Reading WARN as PASS hides real gaps.

[Documentation](https://www.cisecurity.org/benchmark/kubernetes) · objectives: `vuln-cis`

</details>

### 28. An auditor asks for your cluster's posture "mapped to MITRE ATT&CK" this week and "against NSA-CISA guidance" next week. How do you produce both efficiently with Kubescape?

- A. Run entirely separate tools for each framework
- B. Scan against the requested framework (e.g. `kubescape scan framework mitre`, then `nsa`) — a framework is a lens over the same controls, so you re-report, not re-architect
- C. Frameworks require rebuilding the cluster each time
- D. Only CIS is supported, so convert everything to CIS

<details><summary>Answer</summary>

**B** — Kubescape maps the same underlying control results to multiple frameworks (NSA, MITRE ATT&CK for Kubernetes, CIS). You select the framework the auditor asks for and export the report; it's re-lensing the same findings, producing a compliance % and risk score per framework.

[Documentation](https://kubescape.io/docs/frameworks-and-controls/frameworks/) · objectives: `vuln-compliance`

</details>

### 29. A Kubescape `scan framework nsa` returns 84% with a list of failing controls, each carrying a severity weight and a count of affected resources. With limited remediation time this sprint, which failing controls do you fix first to raise the score and cut risk the most?

- A. The controls with the largest number of failing resources, regardless of severity
- B. The highest-weighted (severity-weighted) failing controls — Kubescape scores are severity-weighted, so remediating high-weight controls moves the compliance % and reduces risk most per fix; then re-scan to confirm the trend upward
- C. The controls in alphabetical order, to be systematic
- D. None until you can reach exactly 100%, since a partial score is not worth acting on

<details><summary>Answer</summary>

**B** — Kubescape's compliance score is severity-weighted per control, so both the number and the real risk move most when you remediate the highest-weighted failing controls first, then re-scan to confirm the score trends upward — risk-based prioritization, not raw failing-resource count or a 100%-or-nothing gate. The score is a trend to improve across successive scans.

[Documentation](https://kubescape.io/docs/scanning/) · objectives: `vuln-compliance`

</details>

### 30. Trivy returns 400 CVEs across your images. With limited time, which finding should you remediate FIRST?

- A. Whichever image has the most total CVEs
- B. A CRITICAL with a fix available on an internet-facing, privileged pod — combining severity, fixability, and exposure/blast-radius
- C. A LOW severity with no fix on an isolated batch job
- D. Always the oldest CVE by publish date

<details><summary>Answer</summary>

**B** — Prioritize by risk, not raw count: severity × exploitability × fix-available × exposure. A fixable CRITICAL on an exposed, privileged workload (Trivy severity + Kubescape exposure context) outranks unfixable or isolated findings — attack-path-style prioritization, like Defender's risk-based recommendations.

[Documentation](https://trivy.dev/latest/docs/) · objectives: `vuln-remediate`

</details>

### 31. After bumping a base image and hardening the manifest, when is the remediation actually "done"?

- A. As soon as the ticket is closed
- B. When a re-scan confirms the finding cleared AND admission control (e.g. Kyverno/PSA) prevents the insecure version from being redeployed
- C. When the CVE is marked 'won't fix' upstream
- D. When Grafana stops showing the alert

<details><summary>Answer</summary>

**B** — Remediation isn't complete until you re-scan to verify the finding cleared and you gate admission so the insecure configuration/image can't regress. "Fixed" means verified-and-prevented, mirroring a Defender recommendation moving to healthy and staying there.

[Documentation](https://trivy.dev/latest/docs/target/kubernetes/) · objectives: `vuln-remediate`, `vuln-cluster`

</details>
