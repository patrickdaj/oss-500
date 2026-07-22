# Tasks — fix-overview-objective-count

## 1. Correct the overview figure

- [x] 1.1 Update `plan/overview.md` line 51 to state `94 objectives` (from the stale `70 objectives`), matching the count in `assessment/data/tracker.yaml`.
- [x] 1.2 Grep the repo for other stale count references — `grep -rn "70 objectives" plan/ assessment/ domains/ study-hub/` and any "objectives" totals in overview/README-style prose — and correct any that also cite the SC-500-only figure. (At authoring time, only `plan/overview.md:51` matches.)

## 2. Validation

- [x] 2.1 Re-count objectives in `assessment/data/tracker.yaml` (`grep -c '^\s*text:' assessment/data/tracker.yaml`) and confirm the overview figure equals it.
- [x] 2.2 Run `npm run lint:links` and confirm no broken links were introduced.
- [x] 2.3 Run `openspec validate fix-overview-objective-count --strict` and confirm it passes.
