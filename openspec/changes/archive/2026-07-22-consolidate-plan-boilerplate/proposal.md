# Consolidate plan boilerplate

## Why

Two explanatory blocks are copy-pasted near-verbatim across `plan/` files, so a future wording change has to be made in several places and can drift out of sync:

- **The "beyond-blueprint" closing note** is stated near-verbatim in `plan/phase5-offensive-validation.md` (l.49) and `plan/phase6-agentic-zero-trust.md` (l.51). Both restate the same framing — "Checkpoint N gates this phase exactly as checkpoints 1–4 gate the exam domains, but Domain N carries no SC-500 weight … Proof-of-work is the per-lab observable; the checkpoint is the phase gate." — which `plan/overview.md` (l.18) already establishes for both phases at once.
- **The Falco "prove the control" teaching example** appears in `plan/overview.md` rule 4 (l.60, "Deploying Falco isn't done until you've *triggered* a Falco alert") and again as a standalone restatement in `plan/phase3-compute-ai.md` Day 2 (l.19, "This is the 'prove the control' moment — a fired alert, not just an installed tool"). The same specific example is used to explain the same rule in two places.

These are genuine copy-paste of a specific example / explanatory paragraph, not shared structure. Stating each once canonically and referencing it removes the drift risk without losing any information.

## What Changes

- Make the Falco "prove the control" example **canonical in `plan/overview.md` rule 4** (where the prove-the-control rule already lives). Phase 3 Day 2 keeps its lab step but **references the rule** instead of restating the Falco example verbatim.
- State the **beyond-blueprint checkpoint-gate framing once** — `plan/overview.md` already carries it (l.18). Phases 5 and 6 keep only their phase-specific clause (portfolio-grade enrichment vs. the frontier that follows Domains 1–4) and reference the shared framing rather than re-deriving the whole "gates exactly as checkpoints 1–4 … proof-of-work vs. phase gate" paragraph.
- **Explicitly out of scope — left exactly as-is:** the per-phase **parallel template** is intentional and stays. Each phase keeping its own footprint line, its own flex/last-day line, and its own teardown reminder (including the shared `kubectl get all -A -l app.kubernetes.io/part-of=oss500` label-selector command and the "#1 (overnight) resource killer" teardown phrasing) is deliberate standalone structure, **not** boilerplate to flatten. This change consolidates only the two copy-pasted *examples/paragraphs* above.

No plan files are edited by this proposal; edits above describe the implementation the change authorizes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `study-schedule` — adds a requirement that a shared teaching example or cross-phase note is stated once in a canonical location and referenced elsewhere, while the intentional per-phase template structure is preserved.

## Impact

- Affected specs: `study-schedule` (one ADDED requirement — chosen to avoid colliding with `fix-overview-objective-count`, which is modifying this spec's overview requirement).
- Affected content (at implementation time, not in this proposal): `plan/phase3-compute-ai.md` l.19, `plan/phase5-offensive-validation.md` l.49, `plan/phase6-agentic-zero-trust.md` l.51; canonical text in `plan/overview.md` (rule 4 l.60, beyond-blueprint framing l.18) is retained.
- No tooling or behavioral change; study-hub parsing, block conventions, and per-phase template structure are untouched.
