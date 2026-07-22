# Design — crosslink-offensive-validation-method

## Context

`purple-team.md` is the canonical home of the offensive-validation method: **Build the control → Name the technique → Fire it (locally) → Confirm the defense holds**, with the "if it doesn't hold: document the gap" loop. It links out to its three D5 track children (`ai-redteam`, `infra-attack-simulation`, `ztna-authz`), each of which restates the four steps in a track-specific flavor. That restatement-with-back-context is fine: the parent links the child, and the child's flavor earns its place in its own lab.

`domains/6-agentic-zero-trust/d6-validate.md` is a beyond-blueprint Domain 6 note that red-teams the agentic controls. It reuses the identical method — its line 5 explicitly says "Same purple-team method, different surface" — and its lines 22–26 spell out the four steps in "agent flavor." But it back-links only `d5-ai-redteam.md` (for the chat-vs-agent boundary), never `purple-team.md` where the method actually lives. So the method reads as re-taught from scratch, and there is no structural link keeping it in sync with the canonical steps.

This is a documentation single-source-of-truth issue, not a logic change. The fix is a cross-link plus a spec guardrail.

## Goals / Non-Goals

- Goal: `d6-validate.md` references `purple-team.md` as the canonical method, so its four-step section reads as reinforcement of an established method, not a standalone re-teach.
- Goal: Encode the "defined once, cross-linked everywhere it is applied" invariant in the `offensive-validation` spec so future validation notes follow it.
- Goal (optional): the three D5 flavor headers also name the canonical method, for uniformity.
- Non-Goal: **Do not delete** the flavored method restatements. Each flavor (AI / infra / ZTNA / agent) concretizes the abstract steps for its own lab and aids the learner mid-exercise; removing them would hurt, not help. The requirement is to *reference* the canonical note, not to collapse the restatements into a link.
- Non-Goal: Touch the quiz-5 method-cluster near-duplicate — that belongs to `dedup-quiz-question-intent`.
- Non-Goal: Any change to attack tooling, lab-infra, or the D1–D4 "validate it" callouts.

## Decisions

- Canonical anchor is `purple-team.md`, because it (a) holds the diagram + the gap-documentation loop, (b) already owns the D5 children, and (c) is the capability's named capstone note. `d6-validate` is a downstream applier of the method, so it links up to the anchor.
- The back-link is prose/heading level (e.g. "The four steps — as defined canonically in [`purple-team.md`](../5-offensive-validation/purple-team.md); here in agent flavor"), preserving the agent-specific numbered list beneath it. Minimal edit, maximal signal.
- Add the requirement to the existing `offensive-validation` capability rather than a new capability, since it is the same capability's single-source-of-truth concern.
- Requirement is phrased around "any note that applies the method cross-links the canonical note," so it covers the D6 applier and any future ones, not just today's file.

## Risks / Trade-offs

- Risk: The flavored restatements can still drift from the canonical steps even with a back-link (a link is not a transclusion). Mitigated by the spec requirement making "defined once, referenced everywhere applied" an explicit, reviewable invariant, and by keeping the canonical steps in exactly one authoritative place.
- Trade-off: We keep four flavored restatements rather than one shared block. Accepted deliberately — pedagogical value per lab outweighs the small duplication, and the back-link plus spec guardrail address the sync concern.
- Risk: A relative link from `domains/6-agentic-zero-trust/` to `domains/5-offensive-validation/purple-team.md` must be correct (`../5-offensive-validation/purple-team.md`). Mitigated by running `lint:links` in the tasks.
