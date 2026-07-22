## Context

OSS-500 has 28 hands-on labs across Domains 1–5 (Domain 0 is notes-only). Each lab today: intro framing, an Objectives-covered table, an SC-500/Standards line, Prerequisites (incl. "Notes read"), a `## Steps` section that walks the learner through with the **complete artifact inline** (full YAML/commands), a `## Verification` observable, and Teardown. The explanations and the verification-first ethos are strong; the gap is that the solution is handed over — no build-it-yourself step, no separate reference to check against. Domain 6's labs (`d6-*`, just shipped) already use the target pattern: a guided build that withholds the finished artifact, then a `## Reference solution` section pointing at `lab-infra/agentic/`. They are the exemplar. The user chose a **deep rework** (max fidelity), one change covering all 28 labs, tasks grouped per domain for reviewable batches.

## Goals / Non-Goals

**Goals:**
- Every Domain 1–5 lab teaches as *challenge → guided build → verify → reference solution*: the learner produces the artifact and reaches the observable before seeing a full solution.
- Preserve the course's strengths verbatim — the "why" explanations and the concrete prove-it observable at the end of every lab.
- Preserve every solution: relocate it (to an end-of-lab Reference solution section, or to `lab-infra/` where the artifact belongs), never delete it.
- Codify the template once so it is the durable lab convention.

**Non-Goals:**
- Not changing *what* is taught: objective ids, SC-500 mappings, observables, `lab-infra` components, and `tracker.yaml` are untouched.
- Not a content-accuracy or link audit (a separate concern); relocated links must still pass `lint:links`, but we are not re-verifying every command.
- Not touching `d6-*` labs (already compliant) or Domain 0 (no labs).
- Not adding new labs or new objectives.

## Decisions

**D1 — The lab template (the `d6-*` shape, generalized).** Each lab is restructured to: *(unchanged header)* Title + intro · Objectives table · SC-500/Standards line · Prerequisites → **`## Challenge`** (what to achieve + the observable to reach, no solution) → **`## Build it (guided)`** (hints, checkpoints, partial scaffolding, explicit "your turn" prompts; keep the WHY, withhold the finished artifact) → **`## Verification`** (the prove-it observable, kept) → **`## Reference solution`** (the full solution, marked "build it first, check after") → **`## Teardown`** *(unchanged)* → Honesty note where the lab isn't fully executed. *Alternative considered:* a lighter "try first" reframing that leaves solutions inline — rejected by the user in favor of full fidelity.

**D2 — Where the solution goes.** Default: an end-of-lab `## Reference solution` section holding the complete artifact that used to be inline. Exception: when the artifact is a deployable manifest/policy that already lives (or naturally belongs) in a `lab-infra/<component>/`, the Reference solution *points there* (the `d6` pattern) rather than duplicating it — and the artifact is added to that component if not already present. Either way the full solution stays in-repo and checkable; nothing is deleted.

**D3 — Preserve the observable as the spine.** The `## Verification` section is sacrosanct — it is the course's proof-the-control-works ethos and the definition of "done." The guided build leads *to* that observable; the reference solution is what the learner compares against *after* reaching (or failing to reach) it. A retrofit that loses or weakens an observable is wrong.

**D4 — Codify the convention once.** `labs/README.md` gains a short "How labs teach" section describing the four-part shape and citing the `d6-*` labs as the exemplar, so new labs inherit it and the pattern doesn't drift.

**D5 — Batch by domain, keep diffs mechanical-per-lab.** Tasks are grouped per domain (d1…d5). Each lab's edit is self-contained: reshape its own Steps into Challenge + Build + Reference solution, preserving its header/objectives/observable. This keeps the ~28-lab sweep reviewable and lets it pause between domains.

## Risks / Trade-offs

- **Volume (28 labs) risks an uneven pass.** → Per-domain task batches with a fixed template checklist per lab; the `d6-*` labs are the concrete reference for tone and structure.
- **Losing an observable or an objective mapping while reshuffling.** → Treat Verification + the Objectives table as read-only anchors; every lab keeps its exact observable and ids. A post-pass diff confirms no objective id or SC-500 line changed.
- **Over-withholding hurts a genuinely hard lab.** → Guided ≠ abandoned: give enough scaffolding/hints that a motivated learner can build it; the reference solution is always there to unblock. Calibrate per lab difficulty.
- **Relocated links breaking `lint:links`.** → Moving a link within a file doesn't change its URL; run `lint:links` after each domain batch as the backstop.
- **study-hub coupling.** → Content *shape* is unchanged (same domains/objectives/paths), so study-hub tests stay green; the only study-hub step is the submodule bump + render check at the end.

## Migration Plan

Additive/relocating only. Order: (1) add the "How labs teach" convention to `labs/README.md`; (2) retrofit labs per domain (d1 → d5), running `lint:links` after each batch; (3) `openspec validate`; (4) bump the study-hub `content/oss-500` submodule, confirm `lint:content` + tests green and labs render. Rollback is reverting the lab edits — objectives/observables/tracker were never touched.

## Open Questions

- For a handful of labs whose "solution" is mostly reading/observing (e.g. a SIEM hunt), the "build it yourself" framing is lighter — resolved per lab during authoring (the challenge becomes "form the hypothesis / write the query" rather than "author a manifest").
- Whether any inline solution is better extracted into `lab-infra/` vs. kept in an in-lab Reference solution section — decided per lab by whether the artifact is deployable and component-shaped.
