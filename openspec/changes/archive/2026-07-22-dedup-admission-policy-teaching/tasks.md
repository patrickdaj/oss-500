## 1. Trim pod-security.md to the pod-specific delta

- [x] 1.1 In `domains/3-compute-ai/pod-security.md`, `pod-admission` section ("Enforce workload security at admission time"), remove the re-taught engine internals that duplicate `governance.md`: the near-duplicate `disallow-privileged` Kyverno `ClusterPolicy` YAML, the Kyverno-vs-Gatekeeper authoring recap, `validationFailureAction: Enforce`/`Audit`, the `failurePolicy` `Fail`/`Ignore` fail-closed/open explanation, the `kube-system`/engine-namespace exemption mechanics, and the second copy of the "Azure Policy for AKS *is* Gatekeeper" anchor.
- [x] 1.2 Keep and sharpen the pod-specific delta: (a) the PSA-vs-policy-engine boundary — PSA = three fixed profiles at namespace scope; Kyverno/Gatekeeper = custom rules, per-workload exceptions, image/signature policy; layer, don't choose; (b) mutation runs before validation, so a mutate rule can auto-harden a bare pod into compliance *before* PSA judges it.
- [x] 1.3 Add a cross-link from the trimmed section to `domains/1-identity-governance/governance.md`'s `gov-gatekeeper`/`gov-kyverno` sections as the canonical source for engine internals.
- [x] 1.4 Prune the section's `**Resources:**` / gotchas so remaining items serve the pod delta (PSA interplay, mutation-ordering), not the now-cross-linked engine mechanics.

## 2. Verify no pod-specific content is lost

- [x] 2.1 Diff the removed prose against `governance.md`; confirm each removed sentence has an equivalent in the canonical `gov-gatekeeper`/`gov-kyverno` sections. Any statement unique to pods (PSA boundary, mutation auto-harden) is retained, not deleted.
- [x] 2.2 Confirm `governance.md` is untouched (canonical content unchanged).
- [x] 2.3 Confirm the `pod-admission` objective still reads coherently standalone: a learner gets the PSA-vs-engine decision and the mutation-before-validation insight inline, and knows where to go for engine internals.

## 3. Validate

- [x] 3.1 Run `npm run lint:links` — no broken or generic links introduced (the new cross-link resolves).
- [x] 3.2 Run `openspec validate dedup-admission-policy-teaching --strict` — passes.
