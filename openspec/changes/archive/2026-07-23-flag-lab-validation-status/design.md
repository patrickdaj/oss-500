# Design — flag-lab-validation-status

## The marker

A single, greppable line placed just under a lab's `## Verification` heading (or the prove-it observable), using the existing blockquote-callout style the labs already use:

```markdown
> **Validation status.** Host-validated: the observable below was run end-to-end on a kind host. ✅
```

or, for a step not yet run on a host:

```markdown
> **Validation status — host-pending.** The `<specific step>` has not yet been run end-to-end on a kind host by the author; the surrounding logic is verified (`<what was verified>`). If it doesn't behave as written, treat it as a finding to report, not a mistake.
```

Rationale for a prose blockquote rather than YAML frontmatter or a tracker field:
- The labs are rendered by study-hub's markdown/doc route; a blockquote renders everywhere with no parser change (unlike frontmatter, which would need study-hub support).
- It sits with the observable it qualifies, so the learner reads it exactly when it matters.
- It's greppable (`Validation status`) for later back-fill and for a CI check if desired.

## Course-level disclosure

A short section near the top of `labs/README.md` (the catalog the learner reads first), stating: the curriculum is newly authored; `lab-infra` is real and reviewable and much is verified as far as a laptop allows; some observables await an author host-run; per-lab "Validation status" lines mark which. Framed with the Domain-5 honesty ethic ("a step that doesn't fire is a finding").

## Scope decision

This change does **not** back-fill a positive marker onto all ~34 labs (noise, and it would assert host-validation we haven't done). It:
1. Adds the honest course-level disclosure (covers the whole catalog at once).
2. Defines the marker convention in `guided-lab-pedagogy`.
3. Applies the **host-pending** marker to the seven labs the recent fixes touched with deferred runtime (the specific, known-pending observables).

Positive per-lab markers can be added incrementally as observables are validated on-host while working the track — the convention supports it, but it is not required by this change.

## Alternatives considered

- **A `validated:` field in `assessment/data/tracker.yaml`** — more structured, but the tracker tracks the learner's own progress, not author-validation status; conflating them is confusing, and it wouldn't render in the lab body where it's needed.
- **A single STATUS.md** — one place is easy to miss; the point is to warn at the step. The course-level disclosure covers the "one place" need; the per-lab line covers the "at the step" need.
