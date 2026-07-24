## ADDED Requirements

### Requirement: A note's enforcement story matches the lab it prepares
A prerequisite note SHALL describe the enforcement point (which component installs, which enforces, which is optional) exactly as the lab and `lab-infra/` actually implement it, so a reader who reads the note before the lab is not left unsure whether the control is even enforced.

#### Scenario: CNI/Calico story agrees across note, lab, and infra
- **WHEN** a reader compares `domains/2-secrets-data-networking/network-security.md` against `labs/d2-network-policy.md` and `lab-infra/network/up.sh`
- **THEN** the note states that no CNI is installed, that kindnet enforces the Part A NetworkPolicy, and that Calico is optional/manual — matching the lab — rather than claiming the course "installs Calico" and that kindnet is limited

### Requirement: The note teaches the PromQL constructs its flagship example uses
The `obs-alerting` note SHALL teach the PromQL constructs it relies on — instant vs range vectors and vector matching — before or where it presents its headline security alert, and its worked example SHALL be syntactically valid and reference a metric the lab actually exposes.

#### Scenario: Vector matching is taught and the example parses
- **WHEN** a zero-Prometheus learner reads the `obs-alerting` headline alert in `domains/4-posture-monitoring/observability.md`
- **THEN** the note has introduced instant-vs-range vectors and `on(...) group_left` vector matching, the garbled `unless` expression is repaired to valid PromQL, and the privileged-pod metric (`kube_pod_spec_containers_security_context_privileged`) is confirmed exposed by the lab's kube-state-metrics (or the example uses one that is)

### Requirement: The note connects the log-derived metric to the alert
Where a lab builds a detection as a LogQL expression in one part and evaluates it as a Prometheus rule in another, the note SHALL teach the mechanism that bridges them (log-derived metric / Loki ruler), so a learner following the earlier part writes a rule that actually evaluates.

#### Scenario: LogQL rate and Prometheus alert connect
- **WHEN** a learner reads `obs-alerting` after building the Part B LogQL rate and reaches the Part E `authlog_failed_logins_total` alert
- **THEN** the note explains the log-derived-metric / Loki-ruler mechanism that turns the LogQL detection into an evaluable counter, rather than the alert silently switching data sources with no bridge

### Requirement: The note teaches Vault KV-v2 path and template dualities
The Vault notes SHALL explain KV-v2's `data/` path infix (why the policy uses `secret/data/app/*` while CLI reads use `secret/app/...`) and the KV-v2-vs-dynamic response shape with a short Go-template primer, so the policy, CLI, and injector-template examples are internally consistent and a first-time user does not fail on the mismatch.

#### Scenario: Path duality and template shape are taught
- **WHEN** a learner reads `secrets-management.md` (`vault-access` / `vault-k8s`) alongside `labs/d2-vault-k8s-injection.md`
- **THEN** the note explains the `secret/data/` vs `secret/app` path duality and the KV-v2 response shape (`{{ .Data.data.username }}` vs `{{ .Data.username }}`), so the policy, CLI, and injector-template examples agree

### Requirement: The note teaches static-pod editing safety and recovery
Where a lab has the learner hand-edit a static-pod manifest on the node (e.g. `kube-apiserver.yaml`), the note SHALL teach the static-pod model, kubelet's manifest-watch, and how to recover when the apiserver will not return (no `kubectl`; `docker exec` + revert).

#### Scenario: Static-pod recovery is covered before the edit
- **WHEN** a learner reads `data-protection.md` `data-encrypt` before editing `/etc/kubernetes/manifests/kube-apiserver.yaml`
- **THEN** the note explains that the file is a static-pod manifest the kubelet watches and applies, and gives a recovery path for when the apiserver does not come back, rather than leaving the learner with no safety net
