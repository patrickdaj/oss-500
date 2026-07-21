# lab-infra/runtime — Falco + Tetragon + Falcosidekick

Runtime threat detection and response for the cluster (`d3-runtime` → `rt-falco`, `rt-tetragon`, `rt-response`). Mirrors what **Microsoft Defender for Containers** does on AKS: syscall/eBPF behavioral detection, alert routing/automation, and in-kernel enforcement.

## What this brings up

| Component | Chart | Role | Objective |
|---|---|---|---|
| Falco | `falcosecurity/falco` | eBPF syscall detection + rules | `rt-falco` |
| Falcosidekick (+ UI) | bundled in `falcosecurity/falco` | fan-out alerts to Slack/Loki/metrics/UI | `rt-response` |
| Falco Talon | `falcosecurity/falco-talon` | response actions (terminate/quarantine) | `rt-response` |
| Tetragon | `cilium/tetragon` | eBPF process/network observability + enforcement | `rt-tetragon` |

Everything lands in the **`oss500-security`** namespace, which is deliberately labelled `pod-security.kubernetes.io/enforce: privileged` in [`shared/namespaces.yaml`](../shared/namespaces.yaml). This is the documented exception to the restricted baseline: kernel instrumentation legitimately needs host mounts (`/proc`, `/dev`, the kernel) and eBPF privileges (`CAP_BPF`/`CAP_SYS_ADMIN`). Security tooling is the exception that proves the pod-hardening rule — commented against `pod-psa`/`pod-securitycontext` in the values.

## Why privileged / host access (read before running)

- **Falco** runs as a DaemonSet with the modern eBPF probe; it needs `hostPID` and access to the kernel to observe syscalls across all pods on the node. Without host visibility it can't see the very containers it's protecting.
- **Tetragon** loads eBPF programs (kprobes/LSM hooks) into the kernel; enforcement (`Sigkill`) happens in-kernel, which requires the privileged host agent.
- These privileges are the reason runtime security is *centralized and audited* — you accept a small, well-understood privileged footprint (the security agents) to protect everything else.

## Layout

```
runtime/
├── README.md
├── up.sh                         # helm install falco (+sidekick+talon) and tetragon
├── down.sh                       # helm uninstall + namespace cleanup
├── falco/values.yaml             # eBPF driver, sidekick outputs, talon wiring
├── falcosidekick/values.yaml     # output config (Slack/Loki/webhook) + UI
├── tetragon/values.yaml          # tetragon chart values
├── tetragon/block-sensitive-read.yaml   # TracingPolicy: Sigkill on /etc/shadow read
├── talon/rules.yaml              # Talon response rules (terminate on shell)
└── falcosidekick-slack.secret.example   # copy → .secret, add your webhook (gitignored)
```

## Usage

```bash
cd lab-infra/runtime
cp falcosidekick-slack.secret.example falcosidekick-slack.secret   # optional: real Slack webhook
./up.sh
# ...perform labs/d3-runtime-detection.md, trigger a Falco alert, watch Tetragon kill a process...
./down.sh
```

## Verify it's healthy

```bash
kubectl -n oss500-security get pods -l app.kubernetes.io/name=falco -o wide   # one per node
kubectl -n oss500-security get pods -l app.kubernetes.io/name=tetragon
kubectl -n oss500-security logs -f ds/falco                                    # live alert stream
```

## Secrets hygiene

`falcosidekick-slack.secret` (real webhook URL) is gitignored — only the `.example` is committed. No other state persists; `down.sh` leaves nothing behind.
