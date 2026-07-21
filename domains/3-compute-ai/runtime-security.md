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

Falco ships a maintained default rule set (`falco_rules.yaml`, now distributed as a versioned artifact from the `falcosecurity/rules` repo) covering the common Falco/MITRE ATT&CK cases; you add `falco_rules.local.yaml` overrides for your environment (silence a known-good exec, tighten a noisy rule). The canonical demo — and the lab's verification — is `kubectl exec -it <pod> -- bash`, which trips **"Terminal shell in container"** and prints an alert within a second or two. This is exactly what Defender for Containers reports as a "Suspicious shell / terminal opened in container" alert; Falco is the open-source engine doing the same syscall-level detection.

The three priority/output mechanics worth knowing: every rule has a **`priority`** (`EMERGENCY`→`DEBUG`), which downstream routing filters on; an **`output`** template that interpolates Falco fields (`%proc.cmdline`, `%k8s.ns.name`, `%container.image.repository`); and optional **`tags`** (`mitre_execution`, `T1059`) that map the rule to MITRE ATT&CK techniques for the Containers matrix. Falco enriches events with Kubernetes metadata via its `k8smeta`/`container` plugins, so alerts carry pod, namespace and image — but that enrichment is best-effort and can lag on a fast exit, a real failure mode. Two other tuning realities: default rules are *noisy* out of the box (package managers, health-check `sh` calls, and sidecars all trip generic rules), so production Falco is mostly an exercise in writing `exceptions:` and `- macro:` overrides; and rule changes are hot-reloaded, so you don't restart the DaemonSet to tune. The biggest operational pitfall is the driver: the legacy kernel module or `ebpf` (kmod) driver can fail to load on a node whose kernel it doesn't support, silently leaving that node uninstrumented — the **modern eBPF probe** (CO-RE, no kernel headers) is the fix and the current default.

Exam gotchas:
- Falco *detects and alerts* — it is not, by itself, a blocking control. Prevention comes from admission policy (subsection 1) and network policy; Falco tells you when those were bypassed. (Falco Talon / response actions add reaction, covered under `rt-response`.)
- Prefer the **modern eBPF probe** over the legacy kernel module — no compilation against kernel headers, safer, the current default. A node whose driver failed to load is silently blind; verify coverage per node.
- Rules match on fields (`proc.name`, `fd.name`, `container.id`, `k8s.ns.name`); tuning is done with `local` rule overrides and `exceptions`, not by editing the shipped default rules (edits get clobbered on upgrade).
- Rule `tags` carry MITRE ATT&CK technique IDs — the seam that lets a Falco alert light up an ATT&CK-mapped detection in the SIEM.
- Falco reads syscalls plus optional **plugins** (Kubernetes audit logs, cloud/AWS CloudTrail, etc.) — its scope is not limited to container syscalls; the plugin framework is how it ingests non-syscall event sources.

**Resources:**
- [Falco — Rules](https://falco.org/docs/concepts/rules/) (~25 min)
- [Falco — Getting started / Kubernetes](https://falco.org/docs/getting-started/) (~15 min)
- [falcosecurity/rules — the default ruleset repo](https://github.com/falcosecurity/rules) (~15 min)
- [MITRE ATT&CK — Containers matrix](https://attack.mitre.org/matrices/enterprise/containers/) (~20 min)
- [Microsoft Defender for Containers — overview](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-containers-introduction) (~20 min)

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

Out of the box `tetra getevents` (or the Grafana/JSON export) streams `process_exec`, `process_exit`, `process_kprobe` events already enriched with pod, namespace, labels and container image — so you get a process-ancestry and network audit trail per workload with far less overhead than logging every syscall. The `matchActions` verbs (`Sigkill`, `Override` to fake a return code, `Post` to just report, `Signal` to send an arbitrary signal, `NotifyEnforcer`) are what turn observation into enforcement.

The enforcement mechanism is the important distinction. `Sigkill` and `Override` run **synchronously inside the kernel probe**, so the offending syscall/action is stopped before it completes — no userspace round-trip that an attacker could win a race against. That's why Tetragon can *prevent* where Falco can only *notify*. The strongest enforcement comes from hooking **LSM BPF** (`matchActions` on `security_*` hooks) rather than kprobes, because LSM hooks are the kernel's sanctioned enforcement points and can't be bypassed by an alternate syscall path — a kprobe on a specific `syscall` can sometimes be sidestepped by a different call that reaches the same effect. Failure modes to know: an overly broad `Sigkill` selector (e.g. matching a prefix like `/etc` that also covers `/etc/hostname`) will kill legitimate processes and cause cascading restarts; and enforcement requires a kernel new enough for the hook you chose (LSM BPF needs ~5.7+, and BTF/CO-RE for portability). Tetragon runs as a DaemonSet like Falco and defaults to observation-only until a `TracingPolicy` with `matchActions` enforcement is applied.

On SC-500 this is the enforcement half of **Defender for Containers' runtime protection** and its process/network behavioral analytics. Tetragon and Falco are complementary, not either/or: many stacks run Falco for its broad curated rule set and Tetragon for low-overhead process/network observability plus selective in-kernel enforcement.

Exam gotchas:
- Falco = detect/alert (userspace evaluation of syscalls). Tetragon = observe *and can enforce in-kernel* (`Sigkill`/`Override`). If the scenario needs to *stop* the action synchronously, that's Tetragon.
- Tetragon events carry Kubernetes identity (pod, namespace, labels, image) natively — good for attributing an event to a workload without a separate enrichment step.
- Both use eBPF and need privileged/host access; both live in `oss500-security`.
- Prefer **LSM BPF** hooks over raw kprobes for enforcement — they're the kernel's real security-decision points and are harder to bypass than a single-syscall kprobe.
- Enforcement is synchronous/in-kernel, which is exactly why it can *block*; a userspace tool reacting after the event (Falco → Talon) can only remediate *after* the action already happened.

**Resources:**
- [Tetragon — Documentation](https://tetragon.io/docs/) (~25 min)
- [Tetragon — TracingPolicy & enforcement](https://tetragon.io/docs/concepts/tracing-policy/) (~20 min)
- [cilium/tetragon — project & examples](https://github.com/cilium/tetragon) (~15 min)
- [eBPF.io — what eBPF is and why it fits security](https://ebpf.io/) (~15 min)

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

Two design cautions the exam likes. First, **automated response is a double-edged sword**: a `kubernetes:terminate` action wired to a noisy rule is a self-inflicted denial-of-service — an attacker who can trigger the rule can make you kill your own pods. Scope Talon rules to high-confidence, high-priority rules and prefer *containment* actions (apply a deny-all NetworkPolicy, add a `quarantine` label that a NetworkPolicy selects) over outright termination, which also destroys the forensic evidence in the pod. Second, `minimumpriority` filtering happens **per output**, so you can page humans on `critical` while streaming everything `notice`+ to the SIEM for retention and correlation — getting that split wrong either floods Slack or drops the low-severity events that matter for hunting. Falcosidekick also exposes its own Prometheus metrics, which is how you alert on "Falco stopped sending events" (a blinded sensor).

Exam gotchas:
- Falcosidekick is a *router/forwarder*, not a detector — it produces no alerts of its own; it fans Falco's alerts out and applies per-output `minimumpriority` filtering.
- Automated *response* (kill/quarantine the pod) is Falco Talon (or a response webhook), not Falcosidekick itself. Know the division of labor.
- Sending Falco alerts to Loki/OpenSearch is how runtime detections reach the Domain 4 SIEM for correlation and hunting — this is the seam between the two domains.
- Auto-terminate on a noisy/low-confidence rule is a DoS foot-gun; prefer network-quarantine/label containment that also preserves the pod for forensics.
- Falcosidekick fans out to ~60 targets, but detection quality is still Falco's job — routing more places doesn't reduce false positives; rule tuning does.

**Resources:**
- [Falcosidekick — Outputs](https://github.com/falcosecurity/falcosidekick) (~15 min)
- [Falco Talon — Response engine](https://docs.falco-talon.org/) (~15 min)
- [falcosecurity/falco-talon — rules & actionners](https://github.com/falcosecurity/falco-talon) (~15 min)
- [Defender for Cloud — workflow automation](https://learn.microsoft.com/azure/defender-for-cloud/workflow-automation) (~15 min)

## Summary
| Objective | Takeaway |
|---|---|
| `rt-falco` | Falco evaluates kernel syscalls (eBPF) against YAML rules and alerts on runtime anomalies like a shell in a container — the OSS Defender for Containers detection engine. |
| `rt-tetragon` | Tetragon (eBPF) observes process/network behavior with K8s identity and can enforce in-kernel (`Sigkill`/`Override`) — detection *plus* synchronous blocking. |
| `rt-response` | Falcosidekick fans Falco alerts to Slack/SIEM/metrics; Falco Talon executes response actions (terminate/quarantine) — the OSS Defender alert-automation pipeline. |
