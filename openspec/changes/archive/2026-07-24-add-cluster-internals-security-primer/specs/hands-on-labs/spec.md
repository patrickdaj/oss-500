## ADDED Requirements

### Requirement: Optional enrichment labs are supported and marked as non-tracked
The lab catalog SHALL support an **optional enrichment lab** category: a lab that follows the standard lab format (objectives, prerequisites, estimated time, steps, a concrete verification, teardown) and exercises the existing `lab-infra/` stack, but is **explicitly not mapped to a `tracker.yaml` objective** and is marked as optional/enrichment in `labs/README.md`. Enrichment labs SHALL be exempt from the objective-coverage requirement (they add depth beyond the skills outline, not coverage of it), and the catalog index SHALL distinguish them from tracked hands-on and walkthrough labs so a learner can tell required coverage from optional depth. The first enrichment lab SHALL be a **kubelet attack-surface** lab that probes the kubelet API on the existing `kind` cluster, observes that authentication/authorization is enforced, ties the observed behavior to the `--anonymous-auth` / `--authorization-mode` settings, and connects the CRI/containerd boundary to what Falco/Tetragon observe in Domain 3.

#### Scenario: Enrichment lab is labeled distinctly in the catalog
- **WHEN** a reader opens `labs/README.md`
- **THEN** the kubelet attack-surface lab appears marked as an optional enrichment lab, visually distinct from tracked hands-on and walkthrough labs

#### Scenario: Enrichment labs do not distort objective coverage
- **WHEN** the catalog is compared against `assessment/data/tracker.yaml`
- **THEN** the enrichment lab is not required to map to any objective subsection, and its presence neither adds nor is counted toward objective coverage

#### Scenario: The kubelet enrichment lab has a concrete observable
- **WHEN** a learner runs the kubelet attack-surface lab against the `kind` cluster
- **THEN** the verification step gives an observable check — e.g. an unauthenticated request to the kubelet API returning 401/403, contrasted with the kubelet flags that enforce it — proving the kubelet's authn/authz posture rather than merely describing it

#### Scenario: Enrichment lab follows the standard format and tears down cleanly
- **WHEN** a reader opens the kubelet attack-surface lab
- **THEN** it contains objectives, prerequisites, estimated time, steps, verification, and teardown, and its teardown leaves no residual resources on the shared `kind` cluster
