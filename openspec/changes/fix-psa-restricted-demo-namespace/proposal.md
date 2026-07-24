## Why

`lab-infra/shared/namespaces.yaml` labels `oss500-apps` with `pod-security.kubernetes.io/enforce: restricted`. Built-in PodSecurity admission (PSA) runs *before* validating/mutating webhooks and short-circuits, so any bare `kubectl run`/`kubectl create` pod that isn't restricted-compliant is rejected by **PSS, not by the control the lab is demonstrating**. This one label breaks the headline observable of four admission/runtime labs at once — and it fails in the worst way for a Kubernetes-newcomer: the lab appears to "work" (the pod is rejected) but shows the wrong error, so Day-6 weak-spot review chases a control that is behaving correctly.

Affected observables:
- **D1 `d1-governance-policy` Part A** — the privileged demo pod is denied by PSS, never by Kyverno; the pivotal "flip to `Audit` → pod admitted → violation in a PolicyReport" step is impossible.
- **D3 `d3-pod-security` Part C** — the `evil` pod is PSS-rejected before the Kyverno `ValidatingAdmissionWebhook`, so the learner never sees "rejected by Kyverno with your custom message."
- **D3 `d3-runtime-detection`** — the victim pod is rejected at admission; and because `restricted` forces non-root, `cat /etc/shadow` fails with EACCES before a descriptor exists, so Falco's `Read sensitive file untrusted` rule (which needs a *successful* open) never fires.
- **D3 `d3-supply-chain` Part D** — the "signed image **admitted**" case is unreachable (Kyverno passes it, PSS then rejects it).

## What Changes

- Run the four admission/runtime demos in a dedicated **non-`restricted` demo namespace** (e.g. `gov-demo` / `runtime-demo`, carrying the standard `owner`/`oss500` labels for cleanup) rather than in `oss500-apps`, so the control under test — Kyverno, Falco, cosign verification — is the enforcement point the learner observes.
- Ship **restricted-compliant victim/target manifests** where a genuinely successful root read is the point (D3 `d3-runtime-detection`), so Falco's sensitive-file rule fires on a real successful `open`.
- Add **one sentence per affected lab** on admission-controller ordering: built-in PSA evaluates before validating/mutating webhooks, which is *why* the demo namespace is not `restricted` — turning the fix itself into the lesson.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `lab-infrastructure` — adds a requirement that admission/runtime demonstration namespaces are not labeled `enforce: restricted`, so built-in PSA does not pre-empt the webhook/runtime control the lab exists to prove.
- `hands-on-labs` — adds a requirement that a lab demonstrating an admission or runtime control surfaces its observable from *that* control, and teaches the admission-ordering reason the demo namespace is unrestricted.

## Impact

- Affected specs: `lab-infrastructure` (one ADDED requirement), `hands-on-labs` (one ADDED requirement).
- Affected content (at implementation time): `lab-infra/shared/namespaces.yaml` (add demo namespace[s]); `labs/d1-governance-policy.md`, `labs/d3-pod-security.md`, `labs/d3-runtime-detection.md`, `labs/d3-supply-chain.md` (target the demo namespace, add the admission-ordering sentence, ship a restricted-compliant victim where needed).
- Unblocks the positive/observable test in all four labs. This is the single highest learner-time-saved change in the curriculum audit.
