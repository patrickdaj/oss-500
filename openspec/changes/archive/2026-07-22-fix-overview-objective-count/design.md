# Design — fix-overview-objective-count

## Context

`plan/overview.md` cites the objective tracker as "(70 objectives)". `assessment/data/tracker.yaml` is the declared source of truth and now contains 94 objective entries (one `text:` field per objective, summed across domains `d1`–`d6`). The `70` predates the beyond-blueprint domains `d5` and `d6`. This is a one-line factual correction plus a spec guardrail; no logic or generated output changes.

## Goals / Non-Goals

- Goal: Make the overview's stated objective total equal the tracker's actual count (94).
- Goal: Encode the "overview aggregates match source data" invariant in the `study-schedule` spec.
- Non-Goal: Change tracker content, objective definitions, or any domain/phase plan.
- Non-Goal: Automate the count (no generator or lint rule is added here; the requirement is verified against the source file).

## Decisions

- Use the tracker as the authority and correct the prose figure to 94, rather than reducing the tracker.
- Count method: number of `text:` entries in `assessment/data/tracker.yaml` (each objective has exactly one), which totals 94.
- Add the requirement to `study-schedule` (the capability that owns `plan/`), not a new capability.

## Risks / Trade-offs

- Risk: Future objective additions re-stale the figure. Mitigated by the new requirement making the match an explicit, checkable invariant.
- Trade-off: The count stays manually maintained rather than generated; acceptable given the low churn and single occurrence.
