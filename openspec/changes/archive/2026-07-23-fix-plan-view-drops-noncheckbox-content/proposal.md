# Fix the plan view dropping non-checkbox content

## Why

A plan file's authored content silently disappears in the plan view. study-hub's plan parser (`../study-hub/src/content/plan.ts`, `parsePlanSection`) starts a group at every `##` heading but keeps **only** lines matching the `- [ ]` checkbox convention as blocks — every other line under a heading (numbered lists, prose, plain bullets) is discarded.

The visible symptom: `plan/phase0-fundamentals.md` ends with a `## Self-check (pass before Phase 1)` section that is a **numbered list** (five items), not checkboxes. The raw doc route renders it in full (`/#/oss-500/doc/plan/phase0-fundamentals.md`), but the parsed plan route (`/#/oss-500/plan/phase0-fundamentals`) shows an empty **"Self-check — No blocks — rest day"** and drops all five items. The two routes render the same file inconsistently, and the plan view — the primary study surface — is lossy.

This is **not** caused by the Blueprint restyle (`plan.ts` was untouched by it) and is **not** specific to Phase 0: it drops the non-checkbox content of every plan file with a `## Self-check`, `## Milestone`, or under-heading prose section, across every course. It surfaced now because the plan view is being read closely against the doc view.

## What Changes

- The plan parser SHALL **preserve** each group's authored non-checkbox lines (numbered lists, prose, plain bullets) as raw markdown, alongside the `- [ ]` blocks it already extracts, so no authored content under a heading is discarded.
- The plan section view SHALL **render** that preserved content as markdown (via the existing `Markdown` component), so self-check lists, milestones, and under-heading prose appear in the plan route exactly as they do in the raw doc route.
- The **"No blocks — rest day"** placeholder SHALL show only when a group has *neither* checkbox blocks *nor* preserved content — a genuinely empty group — instead of masking a section that carried non-checkbox content.
- `- [ ]` checkbox blocks remain interactive and their behavior (keys, progress roll-up, backlinks) is unchanged; this change is **additive** to what already renders.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `study-data-format` — extends the "Plan and reference conventions match study-hub parsing" requirement so the parser/plan-view preserves and renders non-checkbox authored content under a heading, making the plan route non-lossy versus the raw doc route.

## Impact

- Affected specs: `study-data-format` (one modified requirement, adds scenarios for non-checkbox content preservation).
- Affected code (at implementation time, in `../study-hub`): `src/content/plan.ts` (capture non-checkbox lines), `src/content/model.ts` (add a `prose` field to `PlanGroup`), `src/pages/Plan.tsx` (`SectionView` renders the preserved markdown; "rest day" gates on blocks *and* prose being empty), `src/content/plan.test.ts` (TDD coverage). No oss-500 content changes; no route, nav-label, or `localStorage`/progress-schema changes.
- Fixes: the `## Self-check` sections in `plan/phase0-fundamentals.md` and every other phase/course plan file with non-checkbox content now render in the plan view.
