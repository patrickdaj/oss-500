# Design — fix the plan view dropping non-checkbox content

## Context

`../study-hub/src/content/plan.ts` `parsePlanSection` builds a `PlanSection` by iterating the file's lines: each `##` heading opens a new `PlanGroup`; each `- [ ] ...` line under it becomes a `PlanBlock`. Any other line is ignored. `SectionView` (in `../study-hub/src/pages/Plan.tsx`) renders the section intro (prose before the first `##`, already handled by `sectionIntro`) plus each group's title and blocks, showing "No blocks — rest day" when a group has zero blocks.

The gap is only the *body* of a group when it is authored as something other than checkboxes — e.g. the `## Self-check (pass before Phase 1)` numbered list. That content is in the file (raw doc route shows it) but never reaches the parsed model, so the plan route drops it and mislabels the section "rest day".

## Goals / Non-Goals

**Goals**
- Preserve every authored line under a `##` heading through the parser.
- Render preserved non-checkbox content in the plan section view as markdown.
- Make the plan route non-lossy versus the raw doc route.
- Keep checkbox blocks and their progress roll-up, keys, and backlinks unchanged.

**Non-Goals**
- Interleaving prose between individual checkbox blocks in exact authored order (the parser keeps blocks and prose as two streams per group; in practice non-checkbox bodies are trailing or standalone).
- Making non-checkbox items checkable or tracked.
- Any oss-500 content edits, or changes to routes, nav labels, or the `localStorage` progress schema.

## Decisions

1. **Capture in the parser, not the view.** `parsePlanSection` accumulates each group's non-heading, non-checkbox lines into a raw markdown string. Rationale: single source of parsing; the view stays a renderer. Rejected: re-slicing `section.raw` inside `SectionView` (duplicates heading/fence logic, drifts from the parser).

2. **Model: add `prose: string` to `PlanGroup`** (`../study-hub/src/content/model.ts`), defaulting to `''` when a group has no non-checkbox body. Additive field; existing consumers (`sectionCompletion`, dashboard roll-ups) ignore it.

3. **Preserve raw markdown, trimmed at the edges.** Store the group's non-checkbox lines joined with newlines, with leading/trailing blank lines trimmed but internal structure (list numbering, blank lines between paragraphs) intact, so the `Markdown` component renders numbered lists and paragraphs correctly. Lines matching the `- [ ]` block pattern are excluded from `prose` (they render as interactive blocks).

4. **Render prose after the blocks in `SectionView`.** When `group.prose` is non-empty, render `<Markdown raw={group.prose} docPath={section.file} />` beneath the group's block list, reusing the existing in-app link/backlink resolution. Rationale: faithful for trailing/standalone sections (Self-check, Milestone); acceptable for the rare leading-prose case, and avoids the complexity of interleaving (a Non-Goal).

5. **"Rest day" gates on blocks *and* prose.** Show the "No blocks — rest day" placeholder only when `group.blocks.length === 0 && group.prose.trim() === ''`. A group with preserved prose renders that prose instead of the placeholder.

## Risks / Trade-offs

- **Ordering fidelity:** blocks-then-prose can reorder a group that authored prose *before* its checkboxes. Low risk — current plan files put non-checkbox bodies at the end (Self-check) or as whole sections; accepted per Non-Goals. If a real case needs interleaving, revisit with a per-group ordered node list.
- **Markdown safety:** reuse the existing `Markdown`/`InlineMd` sanitization path (DOMPurify) already used for section intros and doc bodies — no new rendering surface.

## Validation

TDD in `../study-hub/src/content/plan.test.ts`: a fixture with a `## Self-check` numbered-list section asserts the group has zero blocks and non-empty `prose` containing the list items; a checkbox-only group asserts empty `prose`. Then a visual check that `/#/oss-500/plan/phase0-fundamentals` renders the five self-check items, matching the doc route. Full `npm test`, `tsc -b`, `npm run lint`, and `npm run build` stay green.
