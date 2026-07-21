# Lab d1: Governance & Policy-as-Code

Prove policy stops bad config at the door — a privileged pod rejected, a mislabeled namespace refused — then score the whole estate against a hardening framework, all delivered as reviewable code.

**Objectives covered**

| id | Objective |
|---|---|
| `gov-gatekeeper` | Enforce organizational policy with OPA Gatekeeper constraints |
| `gov-kyverno` | Enforce and mutate resources with Kyverno policies |
| `gov-compliance` | Evaluate compliance against frameworks and baselines |
| `gov-iac` | Implement and configure security controls by using infrastructure as code |

**SC-500 correspondence**: Azure Policy (Gatekeeper); Azure Policy for AKS (Kyverno — and Azure Policy for AKS is itself built on Gatekeeper); Defender secure score / regulatory compliance (Kubescape); security controls via IaC (Helm/manifests).

**Prerequisites**
- [`lab-infra/governance`](../lab-infra/governance/) up (`./up.sh`) — installs Kyverno + Gatekeeper and applies the lab policies.
- Kubescape CLI installed (see the component README).
- Notes read: [governance.md](../domains/1-identity-governance/governance.md).

**Estimated time**: 2–3 h · $0 (local)

## Steps

### Part A — Kyverno enforce & mutate (`gov-kyverno`)

1. Confirm the `disallow-privileged` ClusterPolicy is present and in **Enforce**:
   ```bash
   kubectl get clusterpolicy disallow-privileged -o jsonpath='{.spec.validationFailureAction}{"\n"}'   # Enforce
   ```
2. **Enforce blocks** — try to run a privileged pod; the admission webhook rejects it:
   ```bash
   kubectl -n oss500-apps run bad --image=nginx --privileged
   #  Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
   #  policy disallow-privileged/no-privileged-containers fail: Privileged containers are not allowed
   ```
3. **Audit vs Enforce** — flip the action to `Audit`, re-create the pod (now *allowed*), and read the PolicyReport that records the violation without blocking:
   ```bash
   kubectl patch clusterpolicy disallow-privileged --type=merge -p '{"spec":{"validationFailureAction":"Audit"}}'
   kubectl -n oss500-apps run bad --image=nginx --privileged      # succeeds under Audit
   kubectl -n oss500-apps get policyreport -o wide                # the fail is recorded, not blocked
   kubectl -n oss500-apps delete pod bad
   kubectl patch clusterpolicy disallow-privileged --type=merge -p '{"spec":{"validationFailureAction":"Enforce"}}'
   ```
4. **Mutate remediates** — the `add-default-securitycontext` policy patches a hardened default onto pods that omit one (the Modify/DINE analogue). Create a bare pod and read back the injected `securityContext`:
   ```bash
   kubectl -n oss500-apps run plain --image=nginx --command -- sleep 3600
   kubectl -n oss500-apps get pod plain -o jsonpath='{.spec.securityContext}{"\n"}{.spec.containers[0].securityContext}{"\n"}'
   #  runAsNonRoot:true, seccompProfile RuntimeDefault, allowPrivilegeEscalation:false, capabilities drop:[ALL]
   kubectl -n oss500-apps delete pod plain
   ```

### Part B — OPA Gatekeeper constraints (`gov-gatekeeper`)

5. Inspect the two-object model: the **ConstraintTemplate** (definition, Rego) and the **Constraint** (assignment: scope + action).
   ```bash
   kubectl get constrainttemplate k8srequiredlabels
   kubectl get k8srequiredlabels ns-must-have-owner -o jsonpath='{.spec.enforcementAction}{"\n"}'   # deny
   ```
6. **Deny blocks** — a namespace with no `owner` label is rejected at admission:
   ```bash
   kubectl create ns no-owner-test
   #  Error ... [ns-must-have-owner] missing required label(s): {"owner"}
   kubectl create ns owned-test --dry-run=client -o yaml | \
     kubectl label --local -f - owner=team-sec -o yaml | kubectl apply -f -   # succeeds with the label
   ```
7. **dryrun = Audit** — switch the constraint to `dryrun`; the same bad namespace is now *allowed* but recorded in the constraint's `status.violations` by the audit loop:
   ```bash
   kubectl patch k8srequiredlabels ns-must-have-owner --type=merge -p '{"spec":{"enforcementAction":"dryrun"}}'
   kubectl create ns no-owner-test        # succeeds under dryrun
   kubectl get k8srequiredlabels ns-must-have-owner -o jsonpath='{.status.violations}{"\n"}' | head
   kubectl delete ns no-owner-test owned-test --ignore-not-found
   kubectl patch k8srequiredlabels ns-must-have-owner --type=merge -p '{"spec":{"enforcementAction":"deny"}}'
   ```
   *Exam anchor:* this is the exact engine behind **Azure Policy for AKS** — `deny`/`dryrun` map to Azure Policy **Deny**/**Audit**, and the audit loop reports pre-existing violations without deleting them.

### Part C — Compliance scoring with Kubescape (`gov-compliance`)

8. Score the live cluster against a hardening framework — the secure-score analogue:
   ```bash
   kubescape scan framework nsa --format pretty-printer     # NSA-CISA Kubernetes hardening
   kubescape scan framework cis                             # CIS Kubernetes Benchmark
   ```
9. Read the output: per-**control** pass/fail, a **severity-weighted compliance score**, and remediation for each failure (e.g. "Applications credentials in configuration files," "Cluster-admin binding"). Remediate one high-severity control and re-scan to watch the score move — the same mechanic as driving down Defender secure score.

### Part D — Controls as IaC (`gov-iac`)

10. **Review before apply** — render the controls and read them rather than trusting a black-box install:
    ```bash
    helm template gatekeeper gatekeeper/gatekeeper | grep -A5 securityContext | head
    kubectl kustomize lab-infra/governance 2>/dev/null || cat lab-infra/governance/*.yaml | head -40
    ```
11. **Shift-left** — scan the manifests/Helm *before* they reach the cluster, so misconfigurations are caught in CI, not in production:
    ```bash
    kubescape scan lab-infra/governance/                    # scan the YAML in this repo
    kubescape scan framework cis --compliance-threshold 80  # exit non-zero below 80% → a CI gate
    ```
12. Note the loop itself: every control here exists only as version-controlled YAML/values, stands up via `up.sh`, and tears down via `down.sh` — the deploy→verify→destroy discipline *is* the IaC objective.

## Verification

- A privileged pod is **rejected** at admission by the Kyverno webhook (`policy disallow-privileged ... denied the request`); under `Audit` the same pod is admitted and the violation appears in a PolicyReport.
- A namespace missing the `owner` label is **rejected** by Gatekeeper (`missing required label(s): {"owner"}`); under `dryrun` it is admitted and recorded in the constraint's `status.violations`.
- `kubescape scan framework nsa` prints a compliance **score** and a list of failed controls; remediating a control and re-scanning **raises the score**.

## Teardown

- `cd lab-infra/governance && ./down.sh` (removes policies, uninstalls Kyverno + Gatekeeper, cleans Gatekeeper CRDs; shared namespaces stay).

## What the exam asks

- **ConstraintTemplate (definition/Rego) vs Constraint (scope + action)** — two objects, mirroring Azure Policy *definition* vs *assignment*. **Azure Policy for AKS is built on Gatekeeper.**
- **`deny`/`Enforce` = Azure Policy Deny; `dryrun`/`Audit` = Azure Policy Audit.** Roll out with Audit/dryrun, confirm reports, then Enforce/deny. Audit finds pre-existing violations but never deletes.
- **Kyverno (YAML, no Rego) vs Gatekeeper (Rego)** — same admission-control job; the trade-off is authoring simplicity vs expressiveness.
- **mutate/generate = remediation** (Modify / DeployIfNotExists); validation alone only rejects. `verifyImages` (cosign) links governance to supply-chain signing.
- **Kubescape *measures* posture** against NSA-CISA/CIS frameworks (secure-score, detective) — it does not enforce; admission policy enforces. A passing score is control coverage, not certification.
- **IaC** makes controls reviewable (`helm template`), reproducible, versioned, and testable (shift-left scanning) — why "define the control as code" beats click-ops.
