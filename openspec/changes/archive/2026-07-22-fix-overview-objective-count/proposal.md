# Fix overview objective count

## Why

`plan/overview.md` states the tracker holds "70 objectives". That figure is stale: 70 was the SC-500-only total, counted before the beyond-blueprint domains (`d5` offensive validation, `d6` agentic zero trust) were added to `assessment/data/tracker.yaml`. The tracker — the declared source of truth — now defines **94** objectives across domains `d1`–`d6` (d1: 24, d2: 24, d3: 16, d4: 16, d5: 6, d6: 8). The overview understates the true scope of the course and contradicts its own cited source file.

## What Changes

- Correct the objective total in `plan/overview.md` from `70` to `94` to match `assessment/data/tracker.yaml`.
- Add a `study-schedule` requirement that the overview's stated aggregate figures SHALL match the counts in the source data, so this drift is caught going forward.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `study-schedule` — adds a requirement that the plan overview's aggregate objective total match `assessment/data/tracker.yaml`.

## Impact

- Affected specs: `study-schedule` (one ADDED requirement).
- Affected content (at implementation time, not in this proposal): `plan/overview.md` line 51.
- No behavioral or tooling change; this is a factual correction plus a guardrail requirement.
