# Tasks — fix-psa-restricted-demo-namespace

## 1. Provision the demo namespace(s)

- [ ] 1.1 In `lab-infra/shared/namespaces.yaml`, add a non-`restricted` demo namespace (e.g. `gov-demo` / `runtime-demo`) carrying the standard `owner`/`oss500` labels; keep `oss500-apps` restricted for real workloads.
- [ ] 1.2 Ship a restricted-compliant victim manifest for D3 runtime-detection where a successful root read of `/etc/shadow` is the observable.

## 2. Retarget the four labs

- [ ] 2.1 `labs/d1-governance-policy.md` Part A — run the privileged demo pod in the demo namespace so Kyverno (not PSS) decides admission; verify the `Audit` → admitted → PolicyReport flow.
- [ ] 2.2 `labs/d3-pod-security.md` Part C — run the `evil` pod in the demo namespace so the Kyverno `ValidatingAdmissionWebhook` rejects it with the custom message.
- [ ] 2.3 `labs/d3-runtime-detection.md` — run the victim in the demo namespace with the restricted-compliant manifest so the read succeeds and Falco fires.
- [ ] 2.4 `labs/d3-supply-chain.md` Part D — run the signed image in the demo namespace so the "admitted" case is reachable.

## 3. Teach the reason

- [ ] 3.1 Add one sentence per affected lab on admission-controller ordering (built-in PSA before validating/mutating webhooks) explaining why the demo namespace is not `restricted`.

## 4. Validation

- [ ] 4.1 Bring up the affected stacks and confirm each lab's positive/observable test now fires from the intended control (Kyverno / Falco / cosign).
- [ ] 4.2 Run `openspec validate fix-psa-restricted-demo-namespace --type change --strict`.
