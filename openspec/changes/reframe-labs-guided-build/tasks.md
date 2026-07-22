## 1. Document the convention

- [x] 1.1 Add a "How labs teach" section to `labs/README.md`: the *challenge → guided build → verify → reference solution* template, "build it first, check after", and the `d6-*` labs as the exemplar. This is the spec the retrofit follows.

## 2. Domain 1 — identity, access, governance (10 labs)

For each: reshape `## Steps` into `## Challenge` + `## Build it (guided)` (withhold the finished artifact; keep the "why"), keep `## Verification` verbatim in substance, relocate the full solution to `## Reference solution` (or a `lab-infra/` pointer). Preserve objectives table, SC-500 line, and observables. Run `lint:links` after the batch.

- [x] 2.1 `d1-keycloak-sso-mfa.md`
- [x] 2.2 `d1-keycloak-conditional-access.md`
- [x] 2.3 `d1-kubernetes-rbac.md`
- [x] 2.4 `d1-workload-identity.md`
- [x] 2.5 `d1-privileged-access.md`
- [x] 2.6 `d1-governance-policy.md`
- [x] 2.7 `d1-ztna-boundary.md`
- [x] 2.8 `d1-ztna-openziti.md`
- [x] 2.9 `d1-ztna-pomerium.md`
- [x] 2.10 `d1-ztna-netbird.md`

## 3. Domain 2 — secrets, data, networking (7 labs)

- [x] 3.1 `d2-vault-dynamic-secrets.md`
- [x] 3.2 `d2-vault-k8s-injection.md`
- [x] 3.3 `d2-cert-manager.md`
- [x] 3.4 `d2-network-policy.md`
- [x] 3.5 `d2-network-fabric.md`
- [x] 3.6 `d2-ingress-waf.md`
- [x] 3.7 `d2-data-protection.md`

## 4. Domain 3 — compute & AI (4 labs)

- [x] 4.1 `d3-pod-security.md`
- [x] 4.2 `d3-runtime-detection.md`
- [x] 4.3 `d3-supply-chain.md`
- [x] 4.4 `d3-ai-security.md`

## 5. Domain 4 — posture & monitoring (4 labs)

- [x] 5.1 `d4-observability.md`
- [x] 5.2 `d4-siem-wazuh.md`
- [x] 5.3 `d4-network-detection.md`
- [x] 5.4 `d4-vuln-posture.md`

## 6. Domain 5 — offensive validation (3 labs)

Already partly guided (they name techniques and ask the learner to fire/record); tighten to the template — the challenge is the attack + expected control response, the reference is the tooling/config and the attack↔technique map. Keep the honesty notes.

- [x] 6.1 `d5-ai-redteam.md`
- [x] 6.2 `d5-infra-attack-simulation.md`
- [x] 6.3 `d5-ztna-authz.md`

## 7. Verify & finalize

- [x] 7.1 Every retrofitted lab has the four sections (Challenge, Build it, Verification, Reference solution); the full solution is present (in-lab or via a `lab-infra/` pointer) and nothing was deleted.
- [x] 7.2 Invariants hold: no objective id, Objectives table, SC-500/Standards line, observable, or `tracker.yaml` entry changed (diff-check).
- [x] 7.3 `npm run lint:links` passes; no dead or newly-generic links introduced by relocation.
- [x] 7.4 `openspec validate reframe-labs-guided-build` passes.
- [ ] 7.5 study-hub: bump the `content/oss-500` submodule, run `npm run lint:content` + `npm test` green, confirm the restructured labs render.
