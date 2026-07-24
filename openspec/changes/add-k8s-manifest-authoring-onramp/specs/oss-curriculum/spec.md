## ADDED Requirements

### Requirement: Phase 0 teaches authoring a hardened pod manifest
The Phase-0 Kubernetes fundamentals note SHALL teach the learner to *author* a pod manifest — a complete hardened pod YAML carrying `runAsNonRoot`, `runAsUser`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, resource `limits`, and a probe — applied with `kubectl apply` and verified, rather than teaching only imperative `kubectl create`/`kubectl run`. It SHALL also show the learner how to read a generated spec (for example `kubectl get deploy nginx -o yaml`) so they can connect an imperative command to the declarative object it produces.

#### Scenario: The learner writes a hardened pod spec before the admission labs
- **WHEN** a learner completes the Phase-0 Kubernetes fundamentals note
- **THEN** they have authored and applied a pod manifest with a hardened `securityContext`, resource limits, and a probe, before Phase 1 Days 3/5 and the pod-security/admission labs require that skill

#### Scenario: The hardening is demonstrated as enforced, not just declared
- **WHEN** the learner applies the hardened pod and runs the note's verification step
- **THEN** a write to the read-only root filesystem is denied, so the learner sees the `securityContext` settings take effect rather than only reading them in YAML

#### Scenario: The learner can read a generated spec
- **WHEN** the learner runs an imperative `kubectl` command and then inspects it with `-o yaml`
- **THEN** the note shows the full declarative spec the command generated, bridging imperative use to manifest authoring

### Requirement: Phase 0 has a short RBAC preview backing the Day-4 block
The Phase-0 Kubernetes fundamentals note SHALL contain a short "RBAC in 10 minutes" section covering Roles and ClusterRoles, RoleBindings and ClusterRoleBindings, subjects (ServiceAccount and user), verb/resource rules, and a `kubectl auth can-i` check, so the plan's Day-4 RBAC-preview block has backing content in Phase 0 rather than forward-referencing the full Phase-1 RBAC deep-dive the learner reaches weeks later.

#### Scenario: The Day-4 RBAC-preview block has something to read
- **WHEN** a learner reaches the plan's Day-4 RBAC-preview block
- **THEN** the Phase-0 Kubernetes note provides a short RBAC preview (Roles/ClusterRoles, bindings, subjects, verb/resource rules, and `kubectl auth can-i`) that the block can point at, instead of the block only forward-referencing the Phase-1 deep-dive

#### Scenario: The preview does not duplicate the Phase-1 deep-dive
- **WHEN** the RBAC preview is authored
- **THEN** it is scoped as a 10-minute orientation and cross-links the canonical Phase-1 RBAC note for depth, rather than re-teaching the full RBAC objective in Phase 0
