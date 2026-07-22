# Lab d4: Vulnerability & posture management with Kubescape, kube-bench, Trivy

Scan the cluster's posture, benchmark its nodes against CIS, scan images for CVEs, then remediate the highest-risk findings and watch the compliance score move — the measure→fix→re-measure loop that is CSPM.

**Objectives covered**

| id | Objective |
|---|---|
| `vuln-cluster` | Scan cluster configuration for posture risks |
| `vuln-cis` | Audit nodes and cluster against CIS benchmarks |
| `vuln-compliance` | Produce compliance and secure-score style reports |
| `vuln-remediate` | Prioritize and remediate findings across images and infrastructure |

**SC-500 correspondence**: Microsoft Defender for Cloud — CSPM posture & recommendations (Kubescape), CIS benchmark auditing in the regulatory-compliance dashboard (kube-bench), secure score / regulatory compliance (Kubescape frameworks), vulnerability management & risk-based prioritization / attack paths (Trivy + Kubescape).

**Prerequisites**
- kind cluster up + [`lab-infra/shared`](../lab-infra/shared/) applied.
- [`lab-infra/posture`](../lab-infra/posture/) available (`cd lab-infra/posture && ./up.sh` deploys the kube-bench Job and installs the Kubescape/Trivy CLIs or Jobs).
- Notes read: [vulnerability-posture.md](../domains/4-posture-monitoring/vulnerability-posture.md).

**Estimated time**: 2–2.5 h · $0 (local)

> **Resource note:** light (~1–2 GB) — scans are short-lived Jobs/CLI runs. Fine to run alongside a small workload, since the whole point is to scan a cluster that has something in it. Deploy the deliberately-insecure demo workload first so there's something to find.

## Challenge

Deploy a deliberately-insecure workload, run all three tools against it, and read what they find — then close the measure→fix→re-measure loop yourself: pick the workload's worst combination of findings, design (or harden) a manifest that fixes it, apply it, and re-run the exact same scans.

What you must reach — the observable, no solution here:
- **`vuln-cluster`**: Kubescape names your insecure workload's config controls (privileged, root, hostPath, missing resource limits) by resource, both live and pre-admission on the raw manifest.
- **`vuln-cis`**: kube-bench and Kubescape's CIS framework view both produce numbered `[PASS]`/`[FAIL]`/`[WARN]` checks against the node/control plane, each with a benchmark section and remediation text.
- **`vuln-compliance`**: a Kubescape framework report (NSA and/or MITRE) with a baseline compliance % and risk score you can quote as a single number.
- **`vuln-remediate`**: after you replace the insecure workload with a hardened one on a patched image, the previously-failing controls clear, Trivy no longer shows the CVEs on the new tag, and — the concrete pass/fail bar for this lab — **the compliance score measurably rises on re-scan**. See Verification below for the exact delta to reproduce.

The prioritization call, the hardened manifest, and the exact remediation are yours to build in the next section — check them against the reference solution only after you've made your own attempt.

## Build it (guided)

### Part A — Establish a baseline to find (setup)
1. Deploy the intentionally-insecure workload the lab ships: `kubectl apply -f ../lab-infra/posture/insecure-demo.yaml -n oss500-security` — a pod that runs as root, privileged, with a hostPath mount and a pinned old image (`nginx:1.21.0`). This gives all three tools something real to flag. **Note it goes in `oss500-security`, not `oss500-apps`:** the restricted Pod Security Admission on `oss500-apps` would *reject* this pod at admission (that rejection is itself the lesson — admission gating prevents it from ever running), so we place it in the privileged namespace only so the scanners can evaluate a live insecure pod.

### Part B — Cluster posture scan with Kubescape (`vuln-cluster`)
2. Scan the live cluster: `kubescape scan --format json --output kubescape-baseline.json` (or run the shipped Job: `kubectl apply -f ../lab-infra/posture/kubescape-job.yaml`).
3. Read the results: failing **controls** — *Privileged container*, *Allow privilege escalation*, *hostPath mount*, *Non-root containers*, *Resources CPU/memory limits* — each naming the exact resource (your `insecure-demo` pod) and a remediation. Note these are **configuration** findings, not CVEs.
4. Scan a manifest *before* deploy (shift-left): `kubescape scan ../lab-infra/posture/insecure-demo.yaml` — same controls flagged pre-admission, the `gov-iac` discipline applied to posture.

### Part C — CIS benchmark with kube-bench (`vuln-cis`)
5. Run kube-bench against the node: `kubectl logs job/kube-bench -n oss500-security` (the Job from `up.sh`) or `kubectl apply -f ../lab-infra/posture/kube-bench-job.yaml && kubectl logs -f job/kube-bench -n oss500-security`.
6. Read the output: numbered CIS checks with `[PASS]`/`[FAIL]`/`[WARN]`, the benchmark section (e.g. *1.2.x* API-server, *4.x* kubelet), the reason, and remediation text. Note `[WARN]`/Manual items still need human verification — not a pass.
7. Cross-check with Kubescape's CIS view: `kubescape scan framework cis` — the same benchmark, control-mapped. On our self-managed kind cluster you *can* audit the control plane; note that on managed AKS/EKS you couldn't (shared responsibility).

### Part D — Compliance report & score (`vuln-compliance`)
8. Produce a framework report: `kubescape scan framework nsa --format pdf --output nsa-report.pdf` (also try `--format html`). Open it: a compliance **%**, per-control pass/fail, and a **risk/priority score**.
9. Record the baseline score — e.g. "NSA compliance 61%." This is your before number; you'll re-scan after remediation to show the delta (secure-score trend).
10. Note framework interchangeability: `kubescape scan framework mitre` maps the *same* findings to MITRE ATT&CK for Kubernetes — pick the framework the auditor asks for; you're not re-scanning, just re-lensing.

### Part E — Vulnerability scan + prioritized remediation (`vuln-remediate`)
11. Scan the demo image for CVEs: `trivy image --severity CRITICAL,HIGH nginx:1.21.0`. Note each CVE's **severity** and **fixed-version** column.
12. Scan running workloads: `trivy k8s --include-namespaces oss500-security --report summary` — image CVEs mapped to live pods.
13. **Prioritize — your turn.** You now have two independent finding sets on the same pod: Kubescape's config controls (privileged, hostPath, non-root, missing limits) and Trivy's CVE list (severity + `Fixed Version`). Don't just count findings — combine severity × exploitability (is there a fix available?) × exposure (Kubescape's blast-radius context: is it privileged, hostPath-mounted, internet-facing?) into a single ranked list. Use `--ignore-unfixed` to set aside CRITICALs with no patch yet, since you can't act on those today. Which single finding, if fixed, removes the most risk at once? Write down your ranking and reasoning before checking the reference solution.
14. **Remediate — your turn.** Design a hardened replacement for `insecure-demo.yaml` that clears every control Kubescape flagged and every fixable CVE Trivy flagged: non-root user, `readOnlyRootFilesystem`, dropped capabilities, no hostPath, resource limits, and a **patched image tag** (check your `trivy image` output for the fixed version). Sketch the pod-spec changes field by field against your Part B/C findings before comparing against the shipped answer. Then delete the insecure pod (`kubectl delete -f ../lab-infra/posture/insecure-demo.yaml -n oss500-security`) and apply your hardened manifest to `oss500-apps`. It should be *admitted* precisely because it now complies with the restricted Pod Security Admission — if it's rejected, your hardening is incomplete.
15. **Verify the delta**: re-run `kubescape scan framework nsa` and `trivy image` on the new tag. The failing controls should clear and the compliance % should rise — see Verification below for the exact bar to reproduce. Confirm regression prevention: the Kyverno/PSA admission from earlier domains would now *reject* the insecure pod at admission.

## Verification
- **Posture**: Kubescape flags the insecure pod's config controls (privileged/root/hostPath) with named resources and remediations.
- **CIS**: kube-bench prints numbered CIS `[PASS]`/`[FAIL]`/`[WARN]` checks with sections and remediation for the node/control plane.
- **Compliance**: a Kubescape NSA (and/or MITRE) report artifact with a baseline compliance % and risk score.
- **Remediate**: after applying `secure-demo.yaml` + patched image, the previously-failing controls clear, Trivy shows the CVEs resolved on the new tag, and **the compliance score measurably improves on re-scan**. *(The score rising after remediation is the observable proof.)*

## Reference solution
Build it yourself first; check after.

**Prioritization (step 13)**: combine Trivy severity + `Fixed Version` availability with Kubescape's exposure context. The pod that is *privileged, hostPath-mounted, AND running a CRITICAL-with-a-fix image* is top of the list — high severity × fixable × high blast radius. A CRITICAL with no available fix is deprioritized against a fixable HIGH on an exposed, privileged workload — attack-path thinking, not raw CVE count.

**Remediation (step 14)**: the complete hardened manifest already lives at [`../lab-infra/posture/secure-demo.yaml`](../lab-infra/posture/secure-demo.yaml). Compare it against your own, then apply it:
```bash
kubectl delete -f ../lab-infra/posture/insecure-demo.yaml -n oss500-security
kubectl apply -f ../lab-infra/posture/secure-demo.yaml -n oss500-apps
```
It fixes every flagged control:
- `runAsNonRoot: true`, `runAsUser: 101` — non-root, matching the `nginxinc/nginx-unprivileged` image's expected uid.
- `seccompProfile: { type: RuntimeDefault }` and `allowPrivilegeEscalation: false`.
- `readOnlyRootFilesystem: true` and `capabilities: { drop: ["ALL"] }`.
- No `hostPath` — only `emptyDir` volumes (`cache`, `run`) for nginx's writable dirs.
- `resources.requests`/`limits` set (`cpu: 25m`, `memory: 32Mi`/`64Mi`).
- Patched image tag: `nginxinc/nginx-unprivileged:1.27-alpine`, replacing the pinned, CVE-laden `nginx:1.21.0`.

It is *admitted* to the restricted `oss500-apps` namespace precisely because it now complies — the same PSA that rejects `insecure-demo.yaml` outright.

**Verify the delta (step 15)**:
```bash
kubescape scan framework nsa --format pdf --output nsa-report-after.pdf
trivy image nginxinc/nginx-unprivileged:1.27-alpine --severity CRITICAL,HIGH
```
Compare the new report against your baseline: the previously-failing controls clear, the CVEs on the old pinned tag are gone from the new tag, and the compliance % rises (e.g. 61% → 84%) — the measure→fix→re-measure loop closes.

## Teardown
- `kubectl delete -f ../lab-infra/posture/insecure-demo.yaml -n oss500-security --ignore-not-found`
- `kubectl delete -f ../lab-infra/posture/secure-demo.yaml -n oss500-apps --ignore-not-found`
- `cd lab-infra/posture && ./down.sh` (removes the kube-bench/Kubescape Jobs and demo workloads).

## What the exam asks
- **Posture (config) vs vulnerability (CVE) scanning are different**: Kubescape finds misconfigurations/RBAC/admission risk; Trivy finds image/dependency CVEs. Don't conflate CSPM with vulnerability management.
- kube-bench audits the **CIS Kubernetes Benchmark** specifically; on a **managed control plane you can't benchmark the master** (shared responsibility). `[WARN]`/Manual ≠ PASS.
- A **framework is a lens** (NSA/CIS/MITRE) over the same findings; **secure score / compliance % is a trend to improve**, and "technically compliant" ≠ "certified compliant."
- **Prioritize by risk, not count**: severity × exploitability × fix-available × exposure. A CRITICAL with no fix is often deprioritized vs a fixable HIGH on an exposed, privileged workload — attack-path thinking. Remediation isn't done until re-scan verifies and admission gating prevents regression.
