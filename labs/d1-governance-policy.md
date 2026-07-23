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
- Tools for this lab: `kubescape` (compliance scan) — install per [`../TOOLS.md`](../TOOLS.md).

**Estimated time**: 2–3 h · $0 (local)

## Challenge

Prove four things about the live cluster, then check the exact language against **Verification** below. No solution here — you author the policies; the finished manifests are relocated to **Reference solution**, not handed to you up front.

1. **Kyverno enforces and mutates** (`gov-kyverno`) — a privileged pod is **rejected** at admission by a policy you write; flipped to `Audit`, the same pod is admitted but the violation lands in a PolicyReport; a second policy you write **mutates** a bare pod into a hardened one instead of merely rejecting it.
2. **Gatekeeper enforces via the two-object model** (`gov-gatekeeper`) — a namespace missing an `owner` label is **rejected** at admission by a ConstraintTemplate + Constraint you write; flipped to `dryrun`, it's admitted but recorded in `status.violations`.
3. **Kubescape scores compliance** (`gov-compliance`) — `kubescape scan framework nsa` prints a severity-weighted score and failed controls; remediating one control and re-scanning **moves the score**.
4. **Controls exist only as reviewable IaC** (`gov-iac`) — you can render/scan the Helm/YAML before it reaches the cluster, and the whole estate stands up and tears down via `up.sh`/`down.sh`.

## Build it (guided)

### Part A — Kyverno enforce & mutate (`gov-kyverno`)

**Goal:** two ClusterPolicies — one that *validates* (blocks) and one that *mutates* (remediates) — reaching the pass/fail language in Verification.

1. **Write the block first.** Draft a `ClusterPolicy` named `disallow-privileged`, `validationFailureAction: Enforce`, matching `Pod` resources, that rejects any container — main, `initContainers`, or `ephemeralContainers` — with `securityContext.privileged: true`. Kyverno's *conditional anchor* `=( )` lets a field be optional-but-checked, so a pod that never sets `privileged` still passes. Sketch the `validate.pattern` before you write YAML:
   ```
   spec.containers[*].securityContext.=(privileged): "false"
   ```
   Set `background: true` so already-running pods get scanned into PolicyReports too, not just new admissions.
2. **Confirm your policy is live and in Enforce:**
   ```bash
   kubectl get clusterpolicy disallow-privileged -o jsonpath='{.spec.validationFailureAction}{"\n"}'   # Enforce
   ```
3. **Enforce blocks — your turn.** Try to run a privileged pod; the admission webhook should reject it, naming your policy and rule:
   ```bash
   kubectl -n oss500-apps run bad --image=nginx --privileged
   #  Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
   #  policy disallow-privileged/no-privileged-containers fail: Privileged containers are not allowed
   ```
   If it isn't rejected, check whether your `pattern` matched the wrong path, or the policy is still `Audit`.
4. **Audit vs Enforce.** Flip `validationFailureAction` to `Audit`, re-create the same pod (it should now be *admitted*), and read the PolicyReport that records the violation without blocking:
   ```bash
   kubectl patch clusterpolicy disallow-privileged --type=merge -p '{"spec":{"validationFailureAction":"Audit"}}'
   kubectl -n oss500-apps run bad --image=nginx --privileged      # succeeds under Audit
   kubectl -n oss500-apps get policyreport -o wide                # the fail is recorded, not blocked
   kubectl -n oss500-apps delete pod bad
   kubectl patch clusterpolicy disallow-privileged --type=merge -p '{"spec":{"validationFailureAction":"Enforce"}}'
   ```
5. **Now write the remediation.** Draft a second `ClusterPolicy`, `add-default-securitycontext`, that *mutates* pods lacking a `securityContext` instead of merely rejecting them — the Modify/DINE analogue. Use Kyverno's *add-if-absent* anchor `+( )` in a `patchStrategicMerge` to inject `runAsNonRoot: true` and a `seccompProfile` of `RuntimeDefault` on the pod, plus `allowPrivilegeEscalation: false` and `capabilities.drop: [ALL]` on every container — without clobbering a value a pod already sets.
6. **Prove the mutation — your turn.** Create a bare pod and read back the injected fields:
   ```bash
   kubectl -n oss500-apps run plain --image=nginx --command -- sleep 3600
   kubectl -n oss500-apps get pod plain -o jsonpath='{.spec.securityContext}{"\n"}{.spec.containers[0].securityContext}{"\n"}'
   #  expect: runAsNonRoot:true, seccompProfile RuntimeDefault, allowPrivilegeEscalation:false, capabilities drop:[ALL]
   kubectl -n oss500-apps delete pod plain
   ```
   If a field is missing, you likely used the check-only anchor `=( )` where you needed the add-if-absent anchor `+( )`.

### Part B — OPA Gatekeeper constraints (`gov-gatekeeper`)

**Goal:** the two-object model — a reusable `ConstraintTemplate` (Rego) plus a scoped `Constraint` (assignment) — enforcing that every `Namespace` carries an `owner` label.

7. **Write the ConstraintTemplate.** Its Rego lives in a package matching the template's kind and computes a set difference between `input.parameters.labels` (required) and the labels actually present on `input.review.object`; a non-empty difference is a `violation`. Sketch it before coding:
   ```
   missing := {required labels} - {labels present on the object}
   count(missing) > 0  =>  violation, msg names the missing set
   ```
   Give it a `crd.spec.names.kind` (e.g. `K8sRequiredLabels`) and a `parameters.labels` array in its schema so the same template is reusable for any label, on any resource kind, by different Constraints.
8. **Write the Constraint** that instantiates the template for `Namespace` with `parameters.labels: ["owner"]` and `enforcementAction: deny`. Confirm both objects:
   ```bash
   kubectl get constrainttemplate k8srequiredlabels
   kubectl get k8srequiredlabels ns-must-have-owner -o jsonpath='{.spec.enforcementAction}{"\n"}'   # deny
   ```
9. **Deny blocks — your turn.** A namespace with no `owner` label should be rejected at admission; one with the label should succeed:
   ```bash
   kubectl create ns no-owner-test
   #  Error ... [ns-must-have-owner] missing required label(s): {"owner"}
   kubectl create ns owned-test --dry-run=client -o yaml | \
     kubectl label --local -f - owner=team-sec -o yaml | kubectl apply -f -   # succeeds with the label
   ```
   The rejection message should name the exact missing-label set your Rego computed — if it doesn't, check the direction of your set subtraction.
10. **dryrun = Audit** — switch the constraint to `dryrun`; the same bad namespace should now be *allowed* but recorded in the constraint's `status.violations` by the audit loop:
    ```bash
    kubectl patch k8srequiredlabels ns-must-have-owner --type=merge -p '{"spec":{"enforcementAction":"dryrun"}}'
    kubectl create ns no-owner-test        # succeeds under dryrun
    kubectl get k8srequiredlabels ns-must-have-owner -o jsonpath='{.status.violations}{"\n"}' | head
    kubectl delete ns no-owner-test owned-test --ignore-not-found
    kubectl patch k8srequiredlabels ns-must-have-owner --type=merge -p '{"spec":{"enforcementAction":"deny"}}'
    ```
    *Exam anchor:* this is the exact engine behind **Azure Policy for AKS** — `deny`/`dryrun` map to Azure Policy **Deny**/**Audit**, and the audit loop reports pre-existing violations without deleting them.

### Part C — Compliance scoring with Kubescape (`gov-compliance`)

11. **Score the live cluster** against a hardening framework — the secure-score analogue:
    ```bash
    kubescape scan framework nsa --format pretty-printer     # NSA-CISA Kubernetes hardening
    kubescape scan framework cis                             # CIS Kubernetes Benchmark
    ```
12. **Read and act on the output — your turn.** Find a per-**control** pass/fail line, the **severity-weighted compliance score**, and the remediation text for one high-severity failure (e.g. "Applications credentials in configuration files," "Cluster-admin binding"). Remediate that control yourself and re-scan — watch the score move. This is the same mechanic as driving down Defender secure score.

### Part D — Controls as IaC (`gov-iac`)

13. **Review before apply** — render the controls and read them rather than trusting a black-box install:
    ```bash
    helm template gatekeeper gatekeeper/gatekeeper | grep -A5 securityContext | head
    kubectl kustomize lab-infra/governance 2>/dev/null || cat lab-infra/governance/*.yaml | head -40
    ```
14. **Shift-left** — scan the manifests/Helm *before* they reach the cluster, so misconfigurations are caught in CI, not in production:
    ```bash
    kubescape scan lab-infra/governance/                    # scan the YAML in this repo
    kubescape scan framework cis --compliance-threshold 80  # exit non-zero below 80% → a CI gate
    ```
15. **Name the loop yourself.** Every control here exists only as version-controlled YAML/values, stands up via `up.sh`, and tears down via `down.sh` — the deploy→verify→destroy discipline *is* the IaC objective. Write one sentence connecting this to why "define the control as code" beats click-ops — you'll want that framing for `gov-iac` on the exam.

## Verification

- A privileged pod is **rejected** at admission by the Kyverno webhook (`policy disallow-privileged ... denied the request`); under `Audit` the same pod is admitted and the violation appears in a PolicyReport.
- A namespace missing the `owner` label is **rejected** by Gatekeeper (`missing required label(s): {"owner"}`); under `dryrun` it is admitted and recorded in the constraint's `status.violations`.
- `kubescape scan framework nsa` prints a compliance **score** and a list of failed controls; remediating a control and re-scanning **raises the score**.

## Reference solution

Build it yourself first; check after. The complete, deployed manifests live in [`../lab-infra/governance/`](../lab-infra/governance/):

- [`kyverno-policies.yaml`](../lab-infra/governance/kyverno-policies.yaml) — both ClusterPolicies: `disallow-privileged` (`validationFailureAction: Enforce`, `background: true`, the `=( )` conditional-anchor pattern across `containers`/`initContainers`/`ephemeralContainers`) and `add-default-securitycontext` (the `+( )` add-if-absent mutation injecting `runAsNonRoot: true`, `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`).
- [`gatekeeper-templates.yaml`](../lab-infra/governance/gatekeeper-templates.yaml) — the `k8srequiredlabels` ConstraintTemplate: the CRD schema (`parameters.labels`) plus the Rego `violation` rule (set difference of required vs. provided labels).
- [`gatekeeper-constraints.yaml`](../lab-infra/governance/gatekeeper-constraints.yaml) — the `ns-must-have-owner` Constraint: scoped to `Namespace`, `parameters.labels: ["owner"]`, `enforcementAction: deny`.
- [`values.yaml`](../lab-infra/governance/values.yaml) and [`up.sh`](../lab-infra/governance/up.sh) — the Helm install values and the script that applies all of the above; this *is* `gov-iac` — the controls exist only as this version-controlled YAML.

If your Kyverno `validate.pattern` used a bare field instead of the `=( )` conditional anchor, it fail-rejects pods that never set `privileged` at all — invert to the anchor form. If your mutate policy used `=( )` instead of `+( )`, it only checks instead of adding, and nothing gets injected. If your Rego computed `provided - required` instead of `required - provided`, the violation never fires.

## Teardown

- `cd lab-infra/governance && ./down.sh` (removes policies, uninstalls Kyverno + Gatekeeper, cleans Gatekeeper CRDs; shared namespaces stay).

## What the exam asks

- **ConstraintTemplate (definition/Rego) vs Constraint (scope + action)** — two objects, mirroring Azure Policy *definition* vs *assignment*. **Azure Policy for AKS is built on Gatekeeper.**
- **`deny`/`Enforce` = Azure Policy Deny; `dryrun`/`Audit` = Azure Policy Audit.** Roll out with Audit/dryrun, confirm reports, then Enforce/deny. Audit finds pre-existing violations but never deletes.
- **Kyverno (YAML, no Rego) vs Gatekeeper (Rego)** — same admission-control job; the trade-off is authoring simplicity vs expressiveness.
- **mutate/generate = remediation** (Modify / DeployIfNotExists); validation alone only rejects. `verifyImages` (cosign) links governance to supply-chain signing.
- **Kubescape *measures* posture** against NSA-CISA/CIS frameworks (secure-score, detective) — it does not enforce; admission policy enforces. A passing score is control coverage, not certification.
- **IaC** makes controls reviewable (`helm template`), reproducible, versioned, and testable (shift-left scanning) — why "define the control as code" beats click-ops.
