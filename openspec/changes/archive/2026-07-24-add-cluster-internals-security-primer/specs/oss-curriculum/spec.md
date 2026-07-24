## ADDED Requirements

### Requirement: A cluster-internals security primer teaches the control-plane trust model as attack surface
The curriculum SHALL include a short cluster-internals *security* primer, positioned in or adjacent to the Phase-0 Kubernetes note (`domains/0-fundamentals/02-kubernetes.md`) and reachable before the notes that assume these internals. The primer SHALL cover, at minimum: the cluster **CA / PKI mesh** (every control-plane and node component authenticates with a certificate chained to the cluster CA, so the CA is the root of cluster trust); the **API server** as the single authenticated front door; **etcd** as the store of all cluster state and its unencrypted-at-rest default; the **kubelet** as a network-reachable API (port 10250, the `--anonymous-auth` and `--authorization-mode` settings) and therefore an attack surface; the **CRI / containerd** boundary as where runtime instrumentation (Falco/Tetragon) hooks; and the **CNI** as the seam where NetworkPolicy is or is not enforced. The primer SHALL frame all of this as a security lens on the existing `kind` cluster, SHALL state that the course keeps `kind` rather than adopting a from-scratch build, and SHALL name *Kubernetes The Hard Way* (kubeadm/containerd/CNI bootstrap) as optional depth rather than a required step. The notes that rely on these internals (Kubernetes RBAC, runtime-security, NetworkPolicy, etcd/data encryption) SHALL cross-link the primer.

#### Scenario: The learner meets the cluster trust model before the notes that assume it
- **WHEN** a learner reaches the RBAC, runtime-security, or NetworkPolicy notes that reason about the kubelet, the CRI boundary, or component-to-component trust
- **THEN** the cluster-internals security primer has already defined the CA/PKI mesh, the kubelet API surface, the CRI boundary, and the CNI enforcement seam, so those notes read standalone

#### Scenario: The kubelet is presented as attack surface, not just a node agent
- **WHEN** the primer describes the kubelet
- **THEN** it identifies the kubelet as a reachable API (10250) whose exposure is governed by `--anonymous-auth` and `--authorization-mode`, so the learner can reason about what a misconfigured kubelet leaks

#### Scenario: From-scratch build is offered as optional depth, not the critical path
- **WHEN** a learner wants the full kubeadm/containerd/CNI bootstrap experience
- **THEN** the primer points to *Kubernetes The Hard Way* as optional external depth while stating the course itself stays on `kind`, so cluster bootstrap never becomes a prerequisite

#### Scenario: No new tracked objective is introduced
- **WHEN** the primer is added and `assessment/data/tracker.yaml` is compared before and after
- **THEN** no objective is added or changed, because the primer is ramp material citing external sources under the `resource-citation` standard
