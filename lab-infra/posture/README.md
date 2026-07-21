# lab-infra/posture — Kubescape, kube-bench, Trivy

Vulnerability & posture management for Domain 4 (`vuln-*`): **Kubescape** (configuration/posture scanning + compliance frameworks), **kube-bench** (CIS Kubernetes Benchmark), and **Trivy** (image/dependency CVEs). Mostly CLI + short-lived Jobs against the kind cluster; in-cluster Jobs land in `oss500-security`. Backs the [d4-vuln-posture](../../labs/d4-vuln-posture.md) lab.

**SC-500 correspondence:** Microsoft Defender for Cloud — CSPM posture & recommendations (Kubescape) · CIS benchmark auditing in the regulatory-compliance dashboard (kube-bench) · secure score / regulatory compliance (Kubescape frameworks) · vulnerability management & risk-based prioritization / attack paths (Trivy + Kubescape).

## Footprint

Light (~1–2 GB) — scans are short Jobs/CLI runs. Fine to run against a cluster that has other small workloads (you need something to scan). Deploy the insecure demo first so the tools have real findings.

## Layout

| File | Purpose | Objective |
|---|---|---|
| `up.sh` / `down.sh` | Install the Kubescape/Trivy CLIs + apply/remove the kube-bench Job | — |
| `insecure-demo.yaml` | Deliberately-insecure workload (root/privileged/hostPath/old image) | `vuln-cluster`, `vuln-remediate` |
| `secure-demo.yaml` | Hardened, patched replacement (the remediation) | `vuln-remediate` |
| `kube-bench-job.yaml` | CIS benchmark audit Job (host mounts, `oss500-security`) | `vuln-cis` |
| `kubescape-job.yaml` | In-cluster Kubescape scan Job (read-only SA) | `vuln-cluster`, `vuln-compliance` |

## Usage

```bash
./up.sh                                              # installs kubescape + trivy CLIs, applies kube-bench Job

# Something to find (privileged namespace — restricted PSA on oss500-apps would REJECT it):
kubectl apply -f insecure-demo.yaml -n oss500-security

# Posture (config) scan:
kubescape scan --format json --output baseline.json
# CIS benchmark:
kubectl logs -f job/kube-bench -n oss500-security
# Compliance report + score:
kubescape scan framework nsa --format pdf --output nsa-report.pdf
# CVEs + prioritize:
trivy image --severity CRITICAL,HIGH nginx:1.21.0
trivy k8s --include-namespaces oss500-security --report summary

# Remediate + prove the delta:
kubectl delete -f insecure-demo.yaml -n oss500-security
kubectl apply  -f secure-demo.yaml -n oss500-apps      # ADMITTED because it complies
kubescape scan framework nsa                            # score rises

./down.sh
```

## Why the insecure demo goes to `oss500-security`

`oss500-apps` enforces the **restricted** Pod Security Standard, which would reject a
privileged/root/hostPath pod at admission — that rejection is itself the point
(admission gating prevents this from running). To let the scanners evaluate a *live*
insecure pod we place it in the **privileged** `oss500-security` namespace. The
hardened `secure-demo` is admitted to `oss500-apps` normally, demonstrating the
before/after and the regression-prevention story.

## Tools / images

`quay.io/kubescape/kubescape-cli` (CNCF Kubescape), `aquasec/kube-bench`, and Trivy
(`aquasec/trivy` / the `trivy` CLI). All in-cluster resources carry
`app.kubernetes.io/part-of: oss500`.
