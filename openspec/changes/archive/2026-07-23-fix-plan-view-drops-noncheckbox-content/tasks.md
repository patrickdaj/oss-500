# Tasks — fix-plan-view-drops-noncheckbox-content

All code lives in the `../study-hub` app (sourced by this repo's Pages build). Work on a study-hub branch, TDD, and keep `npm test`, `tsc -b`, `npm run lint`, and `npm run build` green.

## 1. Failing test (RED)

- [x] 1.1 In `../study-hub/src/content/plan.test.ts`, add a fixture plan with a `## Self-check` section authored as a numbered list (no checkboxes) plus a normal `## Day N` with `- [x]` blocks; assert `parsePlanSection` yields the Self-check group with `blocks.length === 0` and a non-empty `prose` containing the numbered items, and the Day group with the expected blocks and empty `prose`.
- [x] 1.2 Run `npx vitest run src/content/plan.test.ts` and confirm it FAILS (no `prose` field yet).

## 2. Parser + model (GREEN)

- [x] 2.1 Add `prose: string` to `PlanGroup` in `../study-hub/src/content/model.ts`.
- [x] 2.2 In `../study-hub/src/content/plan.ts` `parsePlanSection`, accumulate each group's non-heading, non-`- [x]` lines into `prose` (raw markdown, leading/trailing blank lines trimmed, internal structure preserved); exclude checkbox lines (they remain blocks). Set `prose: ''` for groups with no non-checkbox body.
- [x] 2.3 Run `npx vitest run src/content/plan.test.ts` and confirm it PASSES.

## 3. Render in the plan view

- [x] 3.1 In `SectionView` (`../study-hub/src/pages/Plan.tsx`), render `group.prose` (when non-empty) via the `Markdown` component with `docPath={section.file}`, beneath the group's block list, so links/backlinks resolve as elsewhere.
- [x] 3.2 Gate the "No blocks — rest day" placeholder on `group.blocks.length === 0 && group.prose.trim() === ''` (show preserved prose instead of the placeholder when prose exists).

## 4. Verify

- [x] 4.1 Run the full suite `npm test`, plus `tsc -b`, `npm run lint`, and `npm run build` — all green (the render smoke set already covers `oss-500`).
- [x] 4.2 Run the app and confirm `/#/oss-500/plan/phase0-fundamentals` renders the five `## Self-check` items (matching `/#/oss-500/doc/plan/phase0-fundamentals.md`), and that a genuinely empty group still shows "rest day".
- [x] 4.3 `npx openspec validate fix-plan-view-drops-noncheckbox-content --strict`.
- [x] 4.4 Merge the study-hub branch to `main` and push to trigger the oss-500 Pages redeploy.
