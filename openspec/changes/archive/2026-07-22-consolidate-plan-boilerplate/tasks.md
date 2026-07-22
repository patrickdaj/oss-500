# Tasks — Consolidate plan boilerplate

## 1. Falco "prove the control" example (canonical in overview)

- [x] 1.1 Confirm `plan/overview.md` rule 4 (l.60) is the canonical statement of the Falco prove-the-control example ("Deploying Falco isn't done until you've *triggered* a Falco alert"); keep it as-is.
- [x] 1.2 In `plan/phase3-compute-ai.md` Day 2 (l.19), keep the lab step (trigger the Terminal-shell alert) but replace the restated "prove the control … a fired alert, not just an installed tool" example with a reference to the overview's prove-the-control rule, so the example is stated once.

## 2. Beyond-blueprint closing note (stated once)

- [x] 2.1 Confirm `plan/overview.md` (l.18) already carries the shared beyond-blueprint checkpoint-gate framing; keep it as the canonical statement.
- [x] 2.2 In `plan/phase5-offensive-validation.md` (l.49), reduce the closing note to its phase-specific clause (portfolio-grade enrichment) and reference the shared framing instead of restating it near-verbatim.
- [x] 2.3 In `plan/phase6-agentic-zero-trust.md` (l.51), reduce the closing note to its phase-specific clause (the frontier that follows Domains 1–4) and reference the shared framing instead of restating it near-verbatim.

## 3. Preserve intentional template (do NOT change)

- [x] 3.1 Leave every phase's footprint line, flex/last-day line, and teardown reminder untouched — including the shared `kubectl get all -A -l app.kubernetes.io/part-of=oss500` selector command and the "#1 (overnight) resource killer" phrasing. This is intentional parallel structure, not boilerplate to flatten.
- [x] 3.2 Verify each edited phase file still reads standalone (the gating rule and prove-the-control discipline are still discoverable via the added references).

## 4. Validate

- [x] 4.1 Run `npm run lint:links` and confirm all references added in tasks 1–2 resolve.
- [x] 4.2 Run `openspec validate consolidate-plan-boilerplate --strict` and confirm it passes.
