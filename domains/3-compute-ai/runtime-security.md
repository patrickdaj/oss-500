# Detect and respond to runtime threats

Domain 3, subsection 2 (`d3-runtime`). Admission control (subsection 1) decides what's *allowed to start*; runtime security watches what workloads *actually do once running* and reacts. A pod can pass every admission policy and still be compromised at runtime — an attacker exec's a shell into it, reads `/etc/shadow`, spawns a crypto miner, or opens an outbound connection to a C2 host. This subsection covers detecting that behavior at the syscall/kernel level with **Falco** and **Tetragon**, and routing the resulting alerts to a response pipeline with **Falcosidekick**.

Primary lab: [d3-runtime-detection](../../labs/d3-runtime-detection.md). Lab-infra component: [`lab-infra/runtime`](../../lab-infra/runtime/) (Falco + Tetragon + Falcosidekick, deployed into the deliberately `privileged` `oss500-security` namespace because kernel instrumentation needs host access). The SC-500 analog is **Microsoft Defender for Containers** — specifically its runtime threat detection sensor, which does the same syscall/eBPF-based behavioral detection on AKS.

## Detect anomalous runtime behavior with syscall-based rules

*Objective: `rt-falco` · OSS: Falco ≈ SC-500: Defender for Containers · Lab: [d3-runtime-detection](../../labs/d3-runtime-detection.md)*

**Falco** is a CNCF runtime-security engine that taps the stream of kernel **syscalls** (via a kernel module or, preferably, a **modern eBPF probe**) and evaluates each event against a rule set. When a container does something a rule considers suspicious — a shell spawned inside a container, a write under `/etc/`, a sensitive file read, an outbound connection from an unexpected process — Falco emits a prioritized alert. It runs as a DaemonSet (one agent per node) and needs host visibility, which is why it lands in the `privileged` `oss500-security` namespace.

Rules are YAML with three building blocks: **macros** (reusable condition fragments), **lists** (value sets), and **rules** (the alerts). A rule pairs a filtering `condition` written in Falco's fields language with an `output` template and a `priority`:

```yaml
- rule: Terminal shell in container
  desc: A shell was spawned by a non-shell program in a container
  condition: >
    spawned_process and container
    and shell_procs and proc.tty != 0
    and not user_expected_terminal_shell_in_container_conditions
  output: >
    Shell spawned in container (user=%user.name container=%container.name
    shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline)
  priority: NOTICE
  tags: [container, shell, mitre_execution]
```

Falco ships a maintained default rule set (`falco_rules.yaml`) covering the common Falco/MITRE ATT&CK cases; you add `falco_rules.local.yaml` overrides for your environment (silence a known-good exec, tighten a noisy rule). The canonical demo — and the lab's verification — is `kubectl exec -it <pod> -- bash`, which trips **"Terminal shell in container"** and prints an alert within a second or two. This is exactly what Defender for Containers reports as a "Suspicious shell / terminal opened in container" alert; Falco is the open-source engine doing the same syscall-level detection.

Exam gotchas:
- Falco *detects and alerts* — it is not, by itself, a blocking control. Prevention comes from admission policy (subsection 1) and network policy; Falco tells you when those were bypassed. (Falco Talon / response actions add reaction, covered under `rt-response`.)
- Prefer the **modern eBPF probe** over the legacy kernel module — no compilation against kernel headers, safer, the current default.
- Rules match on fields (`proc.name`, `fd.name`, `container.id`, `k8s.ns.name`); tuning is done with `local` rule overrides and exceptions, not by editing the shipped default rules.

**Resources:**
- [Falco — Rules](https://falco.org/docs/concepts/rules/) (~25 min)
- [Falco — Getting started / Kubernetes](https://falco.org/docs/getting-started/) (~15 min)

## Observe and enforce process/network behavior with eBPF

*Objective: `rt-tetragon` · OSS: Tetragon ≈ SC-500: Defender for Containers runtime protection · Lab: [d3-runtime-detection](../../labs/d3-runtime-detection.md)*

**Tetragon** (from the Cilium project, CNCF) is also eBPF-based, but it goes a step past Falco: as well as *observing* process execution, file access and network activity with rich Kubernetes identity, it can **enforce in-kernel** — kill or signal a process synchronously when a policy matches, without a round-trip to userspace. Where Falco's model is "detect and alert," Tetragon's is "observe *and optionally block*," which makes it the closer analog to Defender for Containers' inline runtime protection.

Policy is a `TracingPolicy` CRD that hooks kernel functions (kprobes/tracepoints/LSM hooks). This one watches for writes to sensitive files and enforces by sending `SIGKILL`:

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: block-sensitive-write
spec:
  kprobes:
    - call: "security_file_permission"
      syscall: false
      args:
        - index: 0
          type: "file"
      selectors:
        - matchArgs:
            - index: 0
              operator: "Prefix"
              values: ["/etc/shadow", "/etc/passwd"]
          matchActions:
            - action: Sigkill      # in-kernel enforcement, not just an alert
```

Out of the box `tetra getevents` (or the Grafana/JSON export) streams `process_exec`, `process_exit`, `process_kprobe` events already enriched with pod, namespace, labels and container image — so you get a process-ancestry and network audit trail per workload with far less overhead than logging every syscall. The `matchActions` verbs (`Sigkill`, `Override` to fake a return code, `Post` to just report) are what turn observation into enforcement.

On SC-500 this is the enforcement half of **Defender for Containers' runtime protection** and its process/network behavioral analytics. Tetragon and Falco are complementary, not either/or: many stacks run Falco for its broad curated rule set and Tetragon for low-overhead process/network observability plus selective in-kernel enforcement.

Exam gotchas:
- Falco = detect/alert (userspace evaluation of syscalls). Tetragon = observe *and can enforce in-kernel* (`Sigkill`/`Override`). If the scenario needs to *stop* the action synchronously, that's Tetragon.
- Tetragon events carry Kubernetes identity (pod, namespace, labels, image) natively — good for attributing an event to a workload without a separate enrichment step.
- Both use eBPF and need privileged/host access; both live in `oss500-security`.

**Resources:**
- [Tetragon — Documentation](https://tetragon.io/docs/) (~25 min)
- [Tetragon — TracingPolicy & enforcement](https://tetragon.io/docs/concepts/tracing-policy/) (~20 min)

## Route runtime alerts and trigger response actions

*Objective: `rt-response` · OSS: Falcosidekick ≈ SC-500: Defender alerts / automation · Lab: [d3-runtime-detection](../../labs/d3-runtime-detection.md)*

A detection nobody sees is worthless. **Falcosidekick** is the fan-out and response layer for Falco: Falco posts every alert as JSON to Falcosidekick's HTTP endpoint, and Falcosidekick forwards it to any of ~60 outputs — Slack/Teams/webhook for humans, Loki/Elasticsearch/OpenSearch for storage and hunting (feeding the Domain 4 SIEM), Prometheus/`statsd` for metrics, and **Falcosidekick-UI** for a live alert feed. It's the hub that turns "Falco fired" into "the SOC knows, the event is searchable, and something automated happened."

Configuration is just enabling outputs (Helm values or env vars):

```yaml
# falcosidekick Helm values (excerpt)
falcosidekick:
  config:
    slack:
      webhookurl: "https://hooks.slack.example/…"
      minimumpriority: "warning"     # only warning+ paged
    loki:
      hostport: "http://loki.oss500-monitoring:3100"
      minimumpriority: "notice"      # everything notice+ stored for hunting
    webhook:
      address: "http://responder.oss500-security:8080"   # your automation hook
```

For actual **response actions**, the modern path is **Falco Talon**, a response engine that consumes Falco events and runs remediation "rules" — e.g., on a "Terminal shell in container" alert, `terminate` the offending pod, `label` it for quarantine, or apply a NetworkPolicy to cut its egress. (Historically this was done with `falcosidekick` + the Kubernetes-response webhook; Talon is the current dedicated tool.) A Talon rule maps a Falco rule name to an action:

```yaml
- action: Terminate offending pod
  actionner: kubernetes:terminate
  match:
    rules: ["Terminal shell in container"]
    priority: ">=notice"
```

This is the OSS mirror of **Defender for Cloud's alert automation**: a Defender for Containers alert triggers a Logic App / workflow automation that isolates or kills the workload. Falco (detect) → Falcosidekick (route/notify/store) → Talon (respond) is the same detect-notify-respond pipeline, assembled from open-source parts, and it hands off to the SIEM you build in Domain 4.

Exam gotchas:
- Falcosidekick is a *router/forwarder*, not a detector — it produces no alerts of its own; it fans Falco's alerts out and applies per-output `minimumpriority` filtering.
- Automated *response* (kill/quarantine the pod) is Falco Talon (or a response webhook), not Falcosidekick itself. Know the division of labor.
- Sending Falco alerts to Loki/OpenSearch is how runtime detections reach the Domain 4 SIEM for correlation and hunting — this is the seam between the two domains.

**Resources:**
- [Falcosidekick — Outputs](https://github.com/falcosecurity/falcosidekick) (~15 min)
- [Falco Talon — Response engine](https://docs.falco-talon.org/) (~15 min)

## Summary
| Objective | Takeaway |
|---|---|
| `rt-falco` | Falco evaluates kernel syscalls (eBPF) against YAML rules and alerts on runtime anomalies like a shell in a container — the OSS Defender for Containers detection engine. |
| `rt-tetragon` | Tetragon (eBPF) observes process/network behavior with K8s identity and can enforce in-kernel (`Sigkill`/`Override`) — detection *plus* synchronous blocking. |
| `rt-response` | Falcosidekick fans Falco alerts to Slack/SIEM/metrics; Falco Talon executes response actions (terminate/quarantine) — the OSS Defender alert-automation pipeline. |
