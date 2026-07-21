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

## Steps

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
13. **Prioritize** (the actual skill): combine Trivy severity + `Fixed Version` availability with Kubescape's exposure context. The pod that is *privileged, hostPath-mounted, AND running a CRITICAL-with-a-fix image* is top of the list — high severity × fixable × high blast radius. Use `--ignore-unfixed` to set aside CRITICALs with no patch yet.
14. **Remediate**: delete the insecure pod (`kubectl delete -f ../lab-infra/posture/insecure-demo.yaml -n oss500-security`) and apply the hardened manifest `kubectl apply -f ../lab-infra/posture/secure-demo.yaml -n oss500-apps` — non-root, `readOnlyRootFilesystem`, dropped capabilities, no hostPath, resource limits, and a **patched image tag**. It is *admitted* to the restricted `oss500-apps` namespace precisely because it now complies.
15. **Verify the delta**: re-run `kubescape scan framework nsa` and `trivy image` on the new tag. The failing controls clear and the compliance % rises (e.g. 61% → 84%). Confirm regression prevention: the Kyverno/PSA admission from earlier domains would now *reject* the insecure pod at admission.

## Verification
- **Posture**: Kubescape flags the insecure pod's config controls (privileged/root/hostPath) with named resources and remediations.
- **CIS**: kube-bench prints numbered CIS `[PASS]`/`[FAIL]`/`[WARN]` checks with sections and remediation for the node/control plane.
- **Compliance**: a Kubescape NSA (and/or MITRE) report artifact with a baseline compliance % and risk score.
- **Remediate**: after applying `secure-demo.yaml` + patched image, the previously-failing controls clear, Trivy shows the CVEs resolved on the new tag, and **the compliance score measurably improves on re-scan**. *(The score rising after remediation is the observable proof.)*

## Teardown
- `kubectl delete -f ../lab-infra/posture/insecure-demo.yaml -n oss500-security --ignore-not-found`
- `kubectl delete -f ../lab-infra/posture/secure-demo.yaml -n oss500-apps --ignore-not-found`
- `cd lab-infra/posture && ./down.sh` (removes the kube-bench/Kubescape Jobs and demo workloads).

## What the exam asks
- **Posture (config) vs vulnerability (CVE) scanning are different**: Kubescape finds misconfigurations/RBAC/admission risk; Trivy finds image/dependency CVEs. Don't conflate CSPM with vulnerability management.
- kube-bench audits the **CIS Kubernetes Benchmark** specifically; on a **managed control plane you can't benchmark the master** (shared responsibility). `[WARN]`/Manual ≠ PASS.
- A **framework is a lens** (NSA/CIS/MITRE) over the same findings; **secure score / compliance % is a trend to improve**, and "technically compliant" ≠ "certified compliant."
- **Prioritize by risk, not count**: severity × exploitability × fix-available × exposure. A CRITICAL with no fix is often deprioritized vs a fixable HIGH on an exposed, privileged workload — attack-path thinking. Remediation isn't done until re-scan verifies and admission gating prevents regression.
