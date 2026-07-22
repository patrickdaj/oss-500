# Implement governance to enforce security and compliance

Domain 1, subsection 5 (`d1-governance`). Governance is how you make security *stick*: policy that is evaluated automatically, denies non-compliant resources at the door, measures the estate against a framework, and is itself delivered as reviewable code. On Azure that stack is **Azure Policy**, **Azure Policy for AKS**, **Defender secure score / regulatory compliance**, and IaC. The open-source equivalents are **OPA Gatekeeper** and **Kyverno** (admission-time policy engines), **Kubescape** (framework compliance scoring), and **Helm/manifests** as the IaC delivery mechanism. A useful anchor: **Azure Policy for AKS is literally built on OPA Gatekeeper** — you're learning the actual engine Microsoft ships. Primary lab: [d1-governance-policy](../../labs/d1-governance-policy.md); lab-infra component: [`lab-infra/governance`](../../lab-infra/governance/) (Kyverno + Gatekeeper + Kubescape).

## Enforce organizational policy with OPA Gatekeeper constraints

*Objective: `gov-gatekeeper` · OSS: OPA Gatekeeper ≈ SC-500: Azure Policy · Lab: [d1-governance-policy](../../labs/d1-governance-policy.md)*

OPA **Gatekeeper** is a validating (and mutating) admission-webhook controller that evaluates every create/update against policies written in **Rego**. Its two-object model is the thing to internalize: a **ConstraintTemplate** defines a *policy type* (its parameter schema plus the Rego that decides a violation), and a **Constraint** is an *instance* of that template that says *where it applies* (`match` on kinds/namespaces/labels) and *how hard* (`enforcementAction`). This separation — reusable policy definition vs scoped assignment — is the direct parallel of an **Azure Policy definition** vs its **assignment**, which is unsurprising because Azure Policy for AKS *is* Gatekeeper.

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: { name: k8srequiredlabels }
spec:
  crd: { spec: { names: { kind: K8sRequiredLabels } } }
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          required := input.parameters.labels[_]
          not input.review.object.metadata.labels[required]
          msg := sprintf("missing required label: %v", [required])
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata: { name: ns-must-have-owner }
spec:
  enforcementAction: deny            # gov-gatekeeper: deny | dryrun | warn
  match: { kinds: [{ apiGroups: [""], kinds: ["Namespace"] }] }
  parameters: { labels: ["owner"] }
```

The **`enforcementAction`** is the exam-critical dial: `deny` blocks the request at admission (like an Azure Policy **Deny** effect), while **`dryrun`** and **`warn`** let it through but record it — the counterpart of an **Audit** effect and the way you roll a policy out safely before enforcing. Gatekeeper also runs a continuous **audit** loop that evaluates *existing* cluster resources against constraints and reports violations in each constraint's `status`, so you see pre-existing non-compliance — exactly like Azure Policy marking already-deployed resources non-compliant without deleting them. The community **Gatekeeper library** ships ready-made templates (no-privileged, allowed repos, required probes).

Exam gotchas:

- **ConstraintTemplate (definition) vs Constraint (assignment/scope+action)** — two objects, mirroring Azure Policy definition vs assignment. A template with no constraint enforces nothing.
- **`enforcementAction: deny` = Deny effect; `dryrun`/`warn` = Audit effect.** "Roll out a policy without breaking existing deployments" → dryrun/warn first, then deny.
- **Audit finds existing violations but never deletes** them — same as Azure Policy: pre-existing non-compliant resources are reported, not removed; remediation is separate.
- Policy logic is **Rego** — powerful but the learning cost is real; the exam contrast with Kyverno is "Rego expressiveness vs Kyverno YAML simplicity."
- **Webhook `failurePolicy` (fail-open vs fail-closed)**: if Gatekeeper's admission webhook is down, `Ignore` lets non-compliant resources through (fail-open) while `Fail` blocks all admissions (fail-closed, but can wedge the cluster). Getting this wrong is either a silent policy bypass or a self-inflicted outage — the availability/security trade-off the exam probes.
- **Namespace/label `match` scoping and exemptions**: Gatekeeper exempts `kube-system` and control-plane namespaces by default; a constraint that forgets to scope its `match` either misses workloads or breaks system pods.

**Resources:**
- [OPA Gatekeeper — How to use (ConstraintTemplates, Constraints)](https://open-policy-agent.github.io/gatekeeper/website/docs/howto/) (~25 min)
- [OPA Gatekeeper — Audit and enforcement actions](https://open-policy-agent.github.io/gatekeeper/website/docs/audit/) (~15 min)
- [OPA — Rego policy language](https://www.openpolicyagent.org/docs/latest/policy-language/) (~30 min)
- [Gatekeeper policy library (ready-made ConstraintTemplates)](https://open-policy-agent.github.io/gatekeeper-library/website/) (~15 min)
- [Microsoft Learn — Use Azure Policy to secure AKS (built on Gatekeeper)](https://learn.microsoft.com/en-us/azure/aks/use-azure-policy) (~20 min)

## Enforce and mutate resources with Kyverno policies

*Objective: `gov-kyverno` · OSS: Kyverno ≈ SC-500: Azure Policy for AKS · Lab: [d1-governance-policy](../../labs/d1-governance-policy.md)*

**Kyverno** is a Kubernetes-native policy engine that reaches the same admission-control outcome as Gatekeeper but expresses policy in **plain YAML** — no Rego — which is why teams often prefer it for AKS-style guardrails. A **ClusterPolicy** (or namespaced **Policy**) holds rules of four kinds: **validate** (allow/deny by pattern), **mutate** (patch resources on the way in — e.g. inject a default `securityContext`), **generate** (create companion resources like a default-deny NetworkPolicy in every new namespace), and **verifyImages** (enforce cosign signatures — the supply-chain link to Domain 3). One engine thus covers Azure Policy's Deny *and* Modify *and* DeployIfNotExists effects.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: { name: disallow-privileged }
spec:
  validationFailureAction: Enforce   # gov-kyverno: Enforce (block) | Audit (report only)
  background: true                    # also scan existing resources → PolicyReports
  rules:
    - name: no-privileged-containers
      match: { any: [{ resources: { kinds: ["Pod"] } }] }
      validate:
        message: "privileged containers are not allowed"
        pattern:
          spec:
            containers:
              - =(securityContext):
                  =(privileged): "false"
```

The enforcement dial is **`validationFailureAction: Enforce`** (block at admission) vs **`Audit`** (permit but record) — the same Deny-vs-Audit choice as Gatekeeper and Azure Policy. With **`background: true`**, Kyverno also scans *existing* resources and writes **PolicyReports** (viewable with Policy Reporter), so you get continuous compliance visibility over what's already running, not just new admissions. Kyverno's **mutate** and **generate** rules are its differentiator: they don't just reject bad config, they *fix* it (add read-only root FS, drop capabilities) or *provision* missing controls — the "remediate, don't just flag" capability that maps to Azure Policy Modify/DINE effects.

Exam gotchas:

- **Kyverno = YAML policies, no Rego; Gatekeeper = Rego.** Both are admission controllers doing Azure-Policy-for-AKS work; the exam-relevant trade-off is authoring simplicity (Kyverno) vs expressiveness (Gatekeeper/Rego).
- **`Enforce` blocks, `Audit` reports** — identical semantics to Gatekeeper's deny/dryrun and Azure Policy's Deny/Audit. Roll out with Audit, then Enforce.
- **mutate/generate = remediation**: injecting a secure default (mutate) or provisioning a missing control like a default-deny NetworkPolicy (generate) is the Modify/DeployIfNotExists analogue — validation alone can't do this.
- **`verifyImages`** ties governance to supply-chain signing (cosign) — a Kyverno policy can require signed images at admission, previewing Domain 3's `sc-admission`.
- **`background: true` can't evaluate request-time context**: background/existing-resource scanning has no `AdmissionRequest`, so rules referencing the requesting user, operation, or admission-only data are skipped on background scans and only fire at admission. "Policy passes background scan but blocks on create" traces to this.
- **PolicyExceptions are the escape hatch**: legitimate exemptions are modeled as `PolicyException` objects (auditable, in git), not by loosening the policy — the governance-friendly way to grant an exception, analogous to an Azure Policy exemption.

**Resources:**
- [Kyverno — Writing policies (validate/mutate/generate)](https://kyverno.io/docs/writing-policies/) (~25 min)
- [Kyverno — Policy reports and background scanning](https://kyverno.io/docs/policy-reports/) (~15 min)
- [Kyverno — Introduction & how it compares to Gatekeeper](https://kyverno.io/docs/introduction/) (~15 min)
- [Kyverno — Mutate rules (Modify/DINE analogue)](https://kyverno.io/docs/writing-policies/mutate/) (~15 min)
- [Kyverno — Sample policy library](https://kyverno.io/policies/) (~15 min)

## Evaluate compliance against frameworks and baselines

*Objective: `gov-compliance` · OSS: Kubescape compliance frameworks ≈ SC-500: Defender secure score / regulatory compliance · Lab: [d1-governance-policy](../../labs/d1-governance-policy.md)*

Admission policy stops bad config going *in*; **compliance scanning** is the other half of the governance loop — it **measures the whole estate** against a recognized framework and gives you a score to drive down, the **detective** counterpart to the **preventive** enforcement of Gatekeeper/Kyverno (`deny`/`Enforce`). In governance, **Kubescape's framework scan is an instrument, not the subject**: you **measure, then enforce** — scan to see where the estate stands against a framework, close the gaps with admission policy, and wire the same scan into the `gov-iac` shift-left `--compliance-threshold` gate so a non-compliant change fails CI before it can ever reach admission control. It is the open-source analogue of driving down Defender for Cloud's **secure score** and acting on the **regulatory compliance** dashboard.

The **mechanics** of the scan itself — which frameworks Kubescape ships, how the compliance %/secure-score is computed and severity-weighted, the output/report formats, and the caveat that a passing score is technical-control coverage and **not** a formal certification — are taught canonically under `vuln-compliance` in [`domains/4-posture-monitoring/vulnerability-posture.md`](../4-posture-monitoring/vulnerability-posture.md#produce-compliance-and-secure-score-style-reports). Read them there; here the point is the *governance application* — the measure you act on with policy.

Exam gotchas:

- **Compliance scanning ≠ admission enforcement.** Kubescape *measures and scores* posture against a framework (detective, like secure score); Kyverno/Gatekeeper *prevent* non-compliant admission (preventive, like Deny). The exam pairs them: **measure, then enforce.**
- **The measure feeds the gate.** The same compliance scan is the shift-left signal for `gov-iac`: a `--compliance-threshold` that fails the pipeline keeps a non-compliant change from ever landing, so measurement and enforcement are one loop, not two disconnected activities.
- **Same tool, different lens.** Kubescape reappears in Domain 4 (`vuln-*`) for posture management and reporting; in governance the interest is *policy* — you scan to decide *what to enforce*, not to produce the audit artifact (that scoring/reporting mechanic is `vuln-compliance`).

**Resources:**
- [Kubescape — Frameworks and controls](https://kubescape.io/docs/frameworks-and-controls/) (~20 min)
- [Kubescape — Scanning and compliance score](https://kubescape.io/docs/scanning/) (~15 min)
- [CIS Kubernetes Benchmark (the headline hardening baseline)](https://www.cisecurity.org/benchmark/kubernetes) (~20 min)
- [MITRE ATT&CK — Containers matrix](https://attack.mitre.org/matrices/enterprise/containers/) (~15 min)
- [Microsoft Learn — Defender for Cloud secure score (the SC-500 mapping)](https://learn.microsoft.com/en-us/azure/defender-for-cloud/secure-score-security-controls) (~20 min)

## Implement and configure security controls by using infrastructure as code

*Objective: `gov-iac` · OSS: Helm / Kubernetes manifests ≈ SC-500: Security controls via IaC · Lab: [d1-governance-policy](../../labs/d1-governance-policy.md)*

The final governance objective is *how the controls themselves are delivered*: as **infrastructure as code**, not click-ops. In this curriculum every control — namespaces with Pod Security labels, RBAC, Gatekeeper/Kyverno policies, Keycloak realms — is a manifest or **Helm** values file in version control, applied by an `up.sh` wrapper. That yields the SC-500 IaC properties: controls are **reviewable** (diff the YAML, `helm template` to render before applying), **reproducible** (a clean clone rebuilds the identical hardened cluster), **version-controlled** (every change is an auditable commit), and **testable** (scan the code *before* it's live). Comments in the manifests name the objective each security setting implements, so the code teaches while it deploys — the whole `lab-infra/` tree is the worked example.

```bash
helm template governance ./lab-infra/governance -f values.yaml   # gov-iac: review the rendered controls before applying
kubescape scan ./lab-infra/governance --format pretty-printer    # scan IaC pre-deploy — shift-left
kubectl apply -f lab-infra/shared/namespaces.yaml                # declarative, idempotent, in git
```

Two ideas the exam frames as "security via IaC": **policy-as-code** (the Gatekeeper/Kyverno objects above are themselves IaC — your guardrails are versioned and PR-reviewed) and **shift-left scanning** (run Kubescape/Trivy against manifests and Helm charts *in CI* so misconfigurations are caught before deployment, not after — the equivalent of scanning ARM/Bicep/Terraform with Azure Policy's IaC integration or Defender for DevOps). The deploy→verify→destroy loop every lab uses *is* the IaC discipline in miniature: the environment exists only as code, stands up reproducibly, and tears down cleanly.

Exam gotchas:

- **IaC makes controls reviewable, reproducible, versioned, and testable** — the reasons the exam prefers "define the control as code" over portal/CLI clicks. `helm template` (render-before-apply) is the reviewability lever.
- **Policy-as-code**: Gatekeeper/Kyverno policies are IaC too — guardrails in git, PR-reviewed, rolled out with Audit-then-Enforce. Governance and IaC reinforce each other.
- **Shift-left**: scanning manifests/Helm in CI (Kubescape/Trivy) catches misconfigurations *before* deploy — the open-source analogue of IaC/DevOps security scanning; "prevent the drift from ever landing."
- Declarative apply is **idempotent** — re-applying converges to desired state, the property that makes drift correction and reproducibility possible (vs imperative one-off commands).
- **IaC scanning ≠ secret scanning ≠ drift detection** — shift-left covers misconfiguration (Kubescape/Trivy config), hard-coded secrets (gitleaks/Trivy secret), and post-deploy drift separately; a CI gate that only checks one leaves the others open.
- **A gate is only as good as its enforcement**: a `--compliance-threshold` or Trivy exit code must actually *fail the pipeline* (block merge) to matter — a scan whose findings are ignored is theatre, the same "policy in Audit forever" trap as governance.

**Resources:**
- [Helm — Chart templates and `helm template`](https://helm.sh/docs/chart_template_guide/) (~20 min)
- [Kubescape — Scanning your environment (CLI/CI/operator)](https://kubescape.io/docs/scanning/) (~15 min)
- [Trivy — Misconfiguration scanning (IaC/Helm/K8s manifests)](https://trivy.dev/latest/docs/scanner/misconfiguration/) (~15 min)
- [OWASP — Infrastructure as Code Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Infrastructure_as_Code_Security_Cheat_Sheet.html) (~15 min)
- [Microsoft Learn — Azure Policy overview (controls-as-code / IaC governance)](https://learn.microsoft.com/en-us/azure/governance/policy/overview) (~15 min)

## Summary

| Objective | Takeaway |
|---|---|
| `gov-gatekeeper` | ConstraintTemplate (definition/Rego) + Constraint (scope+action); `deny` vs `dryrun`/`warn` = Azure Policy Deny vs Audit; audit finds existing violations without deleting; *is* the engine behind Azure Policy for AKS |
| `gov-kyverno` | YAML policies (no Rego); validate/mutate/generate/verifyImages; Enforce vs Audit; mutate/generate = Modify/DINE remediation; verifyImages = cosign supply-chain gate |
| `gov-compliance` | Compliance scanning is the **detective/measure** half that pairs with preventive admission enforcement — measure the estate against a framework, then enforce (Gatekeeper/Kyverno) and gate CI (`gov-iac` `--compliance-threshold`); scoring/report mechanics live canonically in `vuln-compliance` |
| `gov-iac` | Controls as Helm/manifests in git: reviewable/reproducible/versioned/testable; policy-as-code + shift-left CI scanning; deploy→verify→destroy is the IaC loop |
