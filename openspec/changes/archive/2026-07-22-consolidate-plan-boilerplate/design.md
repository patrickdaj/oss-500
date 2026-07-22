# Design — Consolidate plan boilerplate

## Context

The `plan/` files share a deliberate parallel template: every phase file has a footprint line, a flex/last-day line, and an end-of-day teardown reminder. That repetition is a feature — it lets a reader open any single phase and get the whole rhythm without cross-referencing. Distinct from that template, two *specific explanatory blocks* have been copy-pasted:

- The beyond-blueprint closing note (`phase5` l.49, `phase6` l.51) restates framing already given once in `overview.md` l.18.
- The Falco "prove the control" example lives in `overview.md` rule 4 (l.60) and is restated in `phase3` Day 2 (l.19).

This change draws the line between the two: consolidate the copied examples/paragraphs; leave the template alone.

## Goals / Non-Goals

**Goals**

- Each shared *teaching example* (the Falco prove-the-control example) and each cross-phase *explanatory note* (the beyond-blueprint checkpoint-gate framing) exists in exactly one canonical place, referenced from elsewhere.
- Add a `study-schedule` requirement that captures this rule so the pattern is enforced going forward.

**Non-Goals**

- **Not** flattening the intentional per-phase template / parallel structure. Each phase's own footprint line, flex/last-day line, and teardown reminder (including the shared `kubectl get all -A -l app.kubernetes.io/part-of=oss500` selector command and the "#1 (overnight) resource killer" phrasing) stays. These are standalone-readability scaffolding, not copy-paste to remove.
- Not touching study-hub parsing, block conventions, or any assessment data.
- Not modifying existing `study-schedule` requirements (the `fix-overview-objective-count` change is editing the overview requirement; this change only ADDs).

## Decisions

**What is canonical vs. what is template.**

| Block | Classification | Canonical home | Action |
|---|---|---|---|
| Falco "prove the control" / triggered-alert example | Copy-pasted example | `overview.md` rule 4 (l.60) | Phase 3 Day 2 references the rule; keeps its lab step, drops the restated example |
| Beyond-blueprint checkpoint-gate framing ("gates exactly as checkpoints 1–4 … proof-of-work vs. phase gate") | Copy-pasted explanatory paragraph | `overview.md` l.18 | Phases 5 & 6 keep only their phase-specific clause and reference the shared framing |
| Per-phase footprint line | Intentional template | each phase | Leave |
| Per-phase flex / last-day line | Intentional template | each phase | Leave |
| Per-phase teardown reminder + `part-of=oss500` selector + "resource killer" phrasing | Intentional template | each phase | Leave |

**Why the overview is canonical for both.** The overview already introduces the prove-the-control rule (rule 4) and already states that phases 5 and 6 gate on their checkpoint exactly as the SC-500 phases do (l.18). The phase files were duplicating what the overview owns; pointing back to it keeps a single source of truth for each idea.

## Risks / Trade-offs

- **Over-consolidation hurts standalone readability.** A reader opening only Phase 5 or only Phase 3 should still understand the gating rule and the prove-the-control discipline without jumping to the overview. Mitigation: phases keep a short phase-specific sentence (Phase 5's "portfolio-grade enrichment", Phase 3's lab observable) and add a lightweight reference, rather than deleting the idea outright. The reference must resolve under `lint:links`.
- **Ambiguous boundary.** Someone applying this change could over-read it and start collapsing the intentional template. Mitigation: the non-goal and the decision table above name exactly which blocks are template and off-limits.
