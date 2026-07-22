# Lab d3: Runtime threat detection and response

Trip a Falco rule by opening a shell in a container, watch the alert fan out through Falcosidekick, then have Tetragon kill a process reading `/etc/shadow` in-kernel.

**Objectives covered**

| id | Objective |
|---|---|
| `rt-falco` | Detect anomalous runtime behavior with syscall-based rules |
| `rt-tetragon` | Observe and enforce process/network behavior with eBPF |
| `rt-response` | Route runtime alerts and trigger response actions |

**SC-500 correspondence**: Microsoft Defender for Containers — runtime threat detection (the "suspicious shell / terminal opened in container" alert), eBPF-based behavioral protection, and Defender alert automation (Logic Apps / workflow automation) for response.

**Prerequisites**
- kind cluster + [`lab-infra/shared`](../lab-infra/shared/) up.
- [`lab-infra/runtime`](../lab-infra/runtime/) up (`./up.sh`) — Falco + Tetragon + Falcosidekick in the privileged `oss500-security` namespace (they need host mounts and eBPF).
- Notes read: [runtime-security.md](../domains/3-compute-ai/runtime-security.md)

**Estimated time**: 2–2.5 h · $0 (local)

## Steps

### Part A — Falco detects a shell in a container (`rt-falco`)

1. Confirm the Falco DaemonSet is running on every node: `kubectl -n oss500-security get pods -l app.kubernetes.io/name=falco -o wide` — one per node, using the modern eBPF probe.
2. Stream Falco's events: `kubectl -n oss500-security logs -f ds/falco` (leave running in one terminal).
3. Deploy a victim pod and open a shell in it — the canonical trigger:
   ```bash
   kubectl -n oss500-apps run victim --image=nginxinc/nginx-unprivileged:stable --restart=Never
   kubectl -n oss500-apps exec -it victim -- sh
   ```
4. Within ~1–2 s, Falco emits **`Terminal shell in container`** (priority NOTICE) with `container`, `proc.cmdline`, `user`, and the K8s pod/namespace fields. That's the runtime detection observable — same event Defender for Containers reports as a suspicious-shell alert.
5. Trigger a second rule: inside the pod, `cat /etc/shadow` → Falco fires **`Read sensitive file untrusted`** (or similar). Note how the rule matched on `fd.name` under a sensitive path.
6. Add a local tuning override to show rule customization without editing shipped rules: append an exception to `falco_rules.local.yaml` (in the Helm values) for a known-good process and reload — the shipped `falco_rules.yaml` stays untouched.

### Part B — Falcosidekick routes and stores alerts (`rt-response`)

7. Confirm Falco is posting to Falcosidekick: `kubectl -n oss500-security logs deploy/falcosidekick` shows each event received.
8. Open the Falcosidekick-UI: `kubectl -n oss500-security port-forward svc/falcosidekick-ui 2802:2802` → browse `http://localhost:2802` and see the shell-in-container and sensitive-file events with priority filtering.
9. Confirm the Loki output is wired (so runtime alerts reach the Domain 4 SIEM): the values set `loki.hostport` to the monitoring namespace; alerts are queryable in Loki/Grafana once that stack is up. This is the seam to Domain 4.
10. (Response) Review the Falco Talon rule shipped in the values that maps `Terminal shell in container` → `kubernetes:terminate`. With Talon enabled, re-run the exec in step 3 and watch the **victim pod get terminated automatically** — the OSS mirror of a Defender alert triggering a containment workflow.

### Part C — Tetragon observes and enforces in-kernel (`rt-tetragon`)

11. Stream Tetragon events: `kubectl -n oss500-security exec ds/tetragon -c tetragon -- tetra getevents -o compact` — watch `process_exec`/`process_exit` events already enriched with pod, namespace, and image.
12. Apply the shipped `TracingPolicy` that `Sigkill`s any process reading `/etc/shadow`:
    ```bash
    kubectl apply -f lab-infra/runtime/tetragon/block-sensitive-read.yaml
    ```
13. In the victim pod, `kubectl -n oss500-apps exec -it victim -- cat /etc/shadow` → the process is **killed by the kernel** (the command dies immediately) and Tetragon logs a `process_kprobe` with `action: Sigkill`. Falco *alerted* on this; Tetragon *stopped* it — the detect-vs-enforce distinction, live.

## Verification
- **Falco alert fires** on `kubectl exec` into a container (`Terminal shell in container`) within seconds, visible in the Falco logs and the Falcosidekick-UI (Parts A/B).
- With Talon enabled, the victim pod is **automatically terminated** after the shell alert (Part B).
- Tetragon **kills the `cat /etc/shadow` process in-kernel** (`Sigkill` in the event stream), so the sensitive file is never read (Part C).

## Teardown
- `kubectl -n oss500-apps delete pod victim --ignore-not-found; kubectl delete tracingpolicy block-sensitive-read --ignore-not-found`
- `cd lab-infra/runtime && ./down.sh`

> **Validate it *(purple team)*.** Fire the real techniques at these rules in [`d5-infra-attack-simulation`](d5-infra-attack-simulation.md): **ATT&CK T1059** (shell in container) and **T1611** (escape to host) ↔ **D3FEND D3-PSA/D3-CI** — confirm Falco/Tetragon actually alert, or document the gap and add the rule.

## What the exam asks
- Falco = detect/alert on syscalls (eBPF), like Defender for Containers detections; it does not block by itself. Tuning is done in `local` rule overrides, not by editing the shipped rules.
- Tetragon = observe *and enforce in-kernel* (`Sigkill`/`Override`); if the scenario must *stop* the action synchronously, that's Tetragon, not Falco.
- Falcosidekick routes/fans-out (Slack, Loki/OpenSearch, metrics) with per-output priority filtering; automated response (terminate/quarantine) is Falco Talon. Sending alerts to Loki/OpenSearch is how runtime detections reach the SIEM.
- Security tooling legitimately runs privileged (host mounts, eBPF) — hence the deliberately `privileged` `oss500-security` namespace, the documented exception to the restricted baseline.
