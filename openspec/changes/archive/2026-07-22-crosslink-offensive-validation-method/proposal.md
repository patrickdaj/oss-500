# Crosslink the offensive-validation purple-team method to its canonical note

## Why

The purple-team four-step method — **Build → Name → Fire → Confirm** — is canonically defined once, in `domains/5-offensive-validation/purple-team.md` (the "## The method — four steps, every time" section, lines 7–22, with the ASCII diagram and the "document the gap" loop).

The three Domain 5 track notes restate it in flavored form (`ai-redteam.md` "## Method (the four steps, AI flavor)", `infra-attack-simulation.md` "…infra flavor", `ztna-authz.md` "…ZTNA flavor"). Those are legitimate children that `purple-team.md` directly links to, so they stay.

The gap is in Domain 6: `domains/6-agentic-zero-trust/d6-validate.md` restates the same method — "## Method (the four steps, agent flavor)" (lines 22–26) — and even calls it "Same purple-team method" (line 5), yet **never back-links the canonical `purple-team.md`**. It links `d5-ai-redteam.md` for the boundary contrast, but not the method's home. A reader landing on `d6-validate` reads a standalone re-teach of the four steps with no signal that they are the reinforcement of an already-canonical method. That invites drift: if the canonical steps change, this restatement silently diverges.

## What Changes

- Add a back-link in `d6-validate.md` so its "four steps, agent flavor" section references `purple-team.md` as the canonical method and keeps only its agent-specific flavor — signaling reinforcement, not a standalone teach.
- (Optional, same spirit) Have the three D5 flavor headers name the canonical method too (e.g. "as defined in [`purple-team.md`](purple-team.md)"), so every flavored restatement points home.
- Do **not** delete any flavored restatement — each aids its own lab.
- The quiz-5 "method-cluster" near-duplicate is **out of scope here**; it is handled by the separate `dedup-quiz-question-intent` change.
- Add one new requirement to the `offensive-validation` capability: the purple-team method is defined once and every note that applies it cross-links the canonical note rather than restating it standalone.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `offensive-validation` — adds a requirement that the purple-team four-step method has a single canonical definition (`purple-team.md`) and that any note applying the method — including the beyond-blueprint `d6-validate` — cross-links that canonical note rather than restating it standalone.

## Impact

- Affected specs: `offensive-validation` (one ADDED requirement).
- Affected content (at implementation time, not in this proposal):
  - `domains/6-agentic-zero-trust/d6-validate.md` — add a canonical back-link to `domains/5-offensive-validation/purple-team.md` in/above the "four steps, agent flavor" section.
  - Optionally `domains/5-offensive-validation/{ai-redteam,infra-attack-simulation,ztna-authz}.md` — flavor headers reference the canonical method.
- Explicitly out of scope: `assessment` quiz-5 method-cluster trim — owned by `dedup-quiz-question-intent`.
- No tooling or behavioral change; this is a cross-linking and single-source-of-truth guardrail.
