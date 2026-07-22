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
- **Host caveat**: on Docker Desktop / macOS the kernel is a LinuxKit VM, so eBPF-based detection (Falco/Tetragon) may behave differently or in-kernel enforcement may not land as described — use a real Linux kernel (Lima/Colima/UTM) for faithful results.
- Notes read: [runtime-security.md](../domains/3-compute-ai/runtime-security.md)

**Estimated time**: 2–2.5 h · $0 (local)

## Challenge

This is a **guided build**: you write the Falco tuning override, the Falco Talon response rule, and the Tetragon enforcement policy yourself, then check each against the [Reference solution](#reference-solution). Reach three observables, in order:

1. **`rt-falco`** — get Falco to fire **`Terminal shell in container`** on an interactive shell in a pod, and **`Read sensitive file untrusted`** on a read of `/etc/shadow` — within seconds, over the eBPF probe, without editing the shipped `falco_rules.yaml`.
2. **`rt-response`** — get that shell alert routed through Falcosidekick (visible in its UI, and in Loki for the Domain 4 SIEM) and, with your Falco Talon rule wired in, watch the victim pod get **quarantined and terminated automatically** — no human in the loop.
3. **`rt-tetragon`** — get Tetragon to **kill the process in-kernel** (`Sigkill`) the instant it opens `/etc/shadow` for read, so the file is never actually read — unlike the Falco case, where the read succeeds and is only reported after the fact.

The distinction that matters for the exam: Falco *detects and alerts*; Tetragon *enforces synchronously in-kernel*. You'll build both halves and see the difference live. No Falco rule YAML, Talon rule, or Tetragon `TracingPolicy` is given below — write them yourself first.

## Build it (guided)

### Part A — Falco detects a shell in a container (`rt-falco`)

1. Confirm the Falco DaemonSet is running on every node: `kubectl -n oss500-security get pods -l app.kubernetes.io/name=falco -o wide` — one per node, using the modern eBPF probe.
2. Stream Falco's events: `kubectl -n oss500-security logs -f ds/falco` (leave running in one terminal).
3. Deploy a victim pod and open a shell in it — the canonical trigger:
   ```bash
   kubectl -n oss500-apps run victim --image=nginxinc/nginx-unprivileged:stable --restart=Never
   kubectl -n oss500-apps exec -it victim -- sh
   ```
4. Within ~1–2 s, Falco should emit **`Terminal shell in container`** (priority NOTICE) with `container`, `proc.cmdline`, `user`, and the K8s pod/namespace fields. That's the runtime detection observable — same event Defender for Containers reports as a suspicious-shell alert.
5. Trigger a second rule: inside the pod, `cat /etc/shadow` → Falco should fire **`Read sensitive file untrusted`** (or similar). Note which field the rule matched on (`fd.name` under a sensitive path) — you'll need the same idea for your own override.
6. **Now tune it — you write the override.** Imagine a liveness/readiness probe execs into the container the same way step 3 did, and floods you with noise. Add a *local* override so that known-good process no longer trips `Terminal shell in container`, without touching the shipped rules:
   - Goal: a `falco_rules.local.yaml` entry (wired into the Helm `customRules`) that (a) defines a macro matching the known-good process name(s), and (b) extends the existing `Terminal shell in container` rule with an `and not <macro>` clause.
   - Hint: Falco's rule `append: true` field extends a named rule's `condition` instead of redefining it — that's how the shipped rule stays untouched, and how tuning is supposed to be done.
   - Your turn: write the macro + append block, add it under Falco's `customRules` in your values (`lab-infra/runtime/falco/values.yaml` or an override layered on top), `helm upgrade` (or re-run `up.sh`) to reload, and confirm the excepted process no longer fires the rule while a real shell still does.

### Part B — Falcosidekick routes and stores alerts (`rt-response`)

7. Confirm Falco is posting to Falcosidekick: `kubectl -n oss500-security logs deploy/falcosidekick` shows each event received.
8. Open the Falcosidekick-UI: `kubectl -n oss500-security port-forward svc/falcosidekick-ui 2802:2802` → browse `http://localhost:2802` and see the shell-in-container and sensitive-file events with priority filtering.
9. Confirm the Loki output is wired (so runtime alerts reach the Domain 4 SIEM): check the Falcosidekick config for a `loki` output pointed at the monitoring namespace's Loki service; alerts should be queryable in Loki/Grafana once that stack is up. This is the seam to Domain 4.
10. **Now automate the response — you write the Talon rule.** Detection alone doesn't contain anything; wire an action to it.
    - Goal: a Falco Talon rule that matches on the `Terminal shell in container` rule name at priority `>=notice` and runs two actions, in order: label the offending pod as quarantined, then terminate it.
    - Hint: Talon rules match on `rules:` / `priority:`, and `actions:` run in list order — `kubernetes:label` then `kubernetes:terminate` (with a short `grace_period_seconds`, ignoring DaemonSets/StatefulSets) gives you quarantine-then-kill instead of an immediate kill that loses the network-isolation window.
    - Your turn: write the rule, apply it (Talon reloads its rule configmap), then re-run the exec from step 3 and watch the **victim pod get labeled and terminated automatically** — the OSS mirror of a Defender alert triggering a containment workflow.

### Part C — Tetragon observes and enforces in-kernel (`rt-tetragon`)

11. Stream Tetragon events: `kubectl -n oss500-security exec ds/tetragon -c tetragon -- tetra getevents -o compact` — watch `process_exec`/`process_exit` events already enriched with pod, namespace, and image.
12. **Now write the enforcement policy yourself.** Falco only *alerted* on the `/etc/shadow` read in Part A — the read still succeeded. Tetragon can stop it before it completes.
    - Goal: a Tetragon `TracingPolicy` that kills, in-kernel, any process that opens `/etc/shadow` (or `/etc/passwd`) for read.
    - Hint: hook the `security_file_permission` LSM call with a `kprobe`, add a `file`-typed arg for the path and an `int`-typed arg for the requested access mask, then a selector that matches the path with a `Prefix` operator and a `matchActions` of `Sigkill`.
    - Your turn: write the `TracingPolicy` YAML and `kubectl apply -f` your own file. Then trigger it:
    ```bash
    kubectl -n oss500-apps exec -it victim -- cat /etc/shadow
    ```
    The process should be **killed by the kernel** (the command dies immediately) with a `process_kprobe` event carrying `action: Sigkill` in the Tetragon stream. Falco *alerted* on this same read in Part A; your policy *stops* it — the detect-vs-enforce distinction, live.

## Verification
- **Falco alert fires** on `kubectl exec` into a container (`Terminal shell in container`) within seconds, visible in the Falco logs and the Falcosidekick-UI (Parts A/B).
- With Talon enabled, the victim pod is **automatically terminated** after the shell alert (Part B).
- Tetragon **kills the `cat /etc/shadow` process in-kernel** (`Sigkill` in the event stream), so the sensitive file is never read (Part C).

## Reference solution
Build it yourself first; check after.

- **Falco local override** (`rt-falco`, step 6) — [`../lab-infra/runtime/falco/values.yaml`](../lab-infra/runtime/falco/values.yaml), under `falco.customRules.falco_rules.local.yaml`: a `known_health_probe` macro (`proc.name in (livenessprobe, readinessprobe)`) plus an `append: true` exception (`and not known_health_probe`) onto `Terminal shell in container` — the shipped `falco_rules.yaml` stays untouched. The same file also sets `driver.kind: modern_ebpf` and wires the `falcosidekick` output block used in Part B.
- **Talon response rule** (`rt-response`, step 10) — [`../lab-infra/runtime/talon/rules.yaml`](../lab-infra/runtime/talon/rules.yaml): `Respond to shell in container` matches `Terminal shell in container` at `priority: ">=notice"` and runs `kubernetes:label` (`oss500.io/quarantine: "true"`) then `kubernetes:terminate` (`grace_period_seconds: 5`, DaemonSets/StatefulSets ignored). A second rule, `Quarantine on sensitive file read`, labels the pod on `Read sensitive file untrusted` at the same priority.
- **Tetragon TracingPolicy** (`rt-tetragon`, step 12) — [`../lab-infra/runtime/tetragon/block-sensitive-read.yaml`](../lab-infra/runtime/tetragon/block-sensitive-read.yaml): a `kprobe` on `security_file_permission` with a `file`-typed arg (index 0) and an `int`-typed access-mask arg (index 1), a selector matching `index: 0` with operator `Prefix` against `/etc/shadow` and `/etc/passwd`, and `matchActions: [{action: Sigkill}]`. Apply the shipped version directly to compare against your own:
  ```bash
  kubectl apply -f lab-infra/runtime/tetragon/block-sensitive-read.yaml
  ```

If your Falco override redefines `Terminal shell in container` instead of `append`-ing to it, you've silently replaced the maintained rule — the next Falco update overwrites your fix. If your Talon rule terminates before labeling, you lose the network-quarantine window. If your Tetragon selector matches on syscall name instead of hooking the LSM call, symlink or bind-mount reads of `/etc/shadow` can slip past it.

## Teardown
- `kubectl -n oss500-apps delete pod victim --ignore-not-found; kubectl delete tracingpolicy block-sensitive-read --ignore-not-found`
- `cd lab-infra/runtime && ./down.sh`

> **Validate it *(purple team)*.** Fire the real techniques at these rules in [`d5-infra-attack-simulation`](d5-infra-attack-simulation.md): **ATT&CK T1059** (shell in container) and **T1611** (escape to host) ↔ **D3FEND D3-PSA/D3-CI** — confirm Falco/Tetragon actually alert, or document the gap and add the rule.

## What the exam asks
- Falco = detect/alert on syscalls (eBPF), like Defender for Containers detections; it does not block by itself. Tuning is done in `local` rule overrides, not by editing the shipped rules.
- Tetragon = observe *and enforce in-kernel* (`Sigkill`/`Override`); if the scenario must *stop* the action synchronously, that's Tetragon, not Falco.
- Falcosidekick routes/fans-out (Slack, Loki/OpenSearch, metrics) with per-output priority filtering; automated response (terminate/quarantine) is Falco Talon. Sending alerts to Loki/OpenSearch is how runtime detections reach the SIEM.
- Security tooling legitimately runs privileged (host mounts, eBPF) — hence the deliberately `privileged` `oss500-security` namespace, the documented exception to the restricted baseline.
