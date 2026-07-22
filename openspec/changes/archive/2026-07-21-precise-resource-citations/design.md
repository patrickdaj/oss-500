## Context

OSS-500 cites ~409 external links across `domains/**` and `labs/**`. Convention today: a `**Resources:**` bullet list per note subsection, each `- [text](url) (~NN min)`, plus inline links in prose and labs. 354/409 already have a time hint, so **time budgeting is largely solved**; **content specificity is not**. Concrete failures: `[Helm — documentation](https://helm.sh/docs/)`, `[Kubernetes — Concepts](https://kubernetes.io/docs/concepts/)`, `[Terraform — Intro](https://developer.hashicorp.com/terraform/intro)`, `[kubectl reference](https://kubernetes.io/docs/reference/kubectl/)` — 37 links are host-only or one segment deep, and the `0-fundamentals/*` "Primary sources" blocks are the densest offenders. There are currently **no video citations**, so the timestamp rule is forward-looking (codify it now so the first video added obeys it).

A wrinkle: some homepage links are legitimate — `standards-map.md` cites the ATT&CK/D3FEND/CIS/NIST homes as the *canonical* source of a framework, not as "read this to learn." The standard must not force fake deep-links onto those; it must let them be marked as references.

This is authored as a repo-local change; `resource-citation` requirements are carried as a new capability (the `build-oss-500-course` specs are not archived to `openspec/specs/`).

## Goals / Non-Goals

**Goals:**
- Make every **learning resource** tell the learner exactly what to read/watch and no more — deep link + named section/chapter/timestamp range, with the time estimate scoped to that slice.
- Codify the rule once (`resource-citation` standard) and **enforce it in `lint:content`** so it stays true.
- Preserve legitimate homepage/framework references by an explicit `(reference)` marker.
- Zero change to objectives, lab steps, or assessments — only the resources get sharper.

**Non-Goals:**
- Not re-timing the whole corpus — keep existing `(~NN min)` values unless the scope narrows.
- Not removing resources or adding new ones wholesale — this is precision, not curation (add a deeper link only when the current one is unusably generic).
- Not link-rot / URL-liveness checking (a separate concern; this is about *specificity*, though obviously-dead links found in passing get fixed).
- Not a design change to the study-hub renderer.

## Decisions

**D1 — The citation format.** A learning-resource citation is:
`- [Resource — the specific thing](deep-url#anchor) (~NN min[, §range])`
where the link text names the section/heading, the URL deep-links to it (with `#anchor` when the page supports it), and — when only part is needed — a range is stated: sections (`§4–7`), chapters/pages (`ch. 2–3`), or video timestamps (`12:00–24:00`). The `(~NN min)` covers only the cited slice. Prose/inline links follow the same "name what to read" rule in the sentence.

**D2 — `(reference)` is a first-class marker.** A link cited for lookup/provenance rather than required reading is suffixed `(reference)` (optionally `(reference — <scope>)`). This is the escape hatch that keeps homepage/framework links honest: they're allowed *because* they're marked non-required. The lint (D4) treats `(reference)` links as exempt from the deep-link rule. `standards-map.md`'s framework homes are converted to this form.

**D3 — Audit unit is the file, ordered by offender density.** Work file-by-file (each note/lab), fixing every link to satisfy D1/D2, starting with the shallow-link-dense files (`standards-map.md`, `supply-chain.md`, the `0-fundamentals/*` primary-source blocks, `ai-security.md`, `siem-incident-response.md`, `network-security.md`, `identity-provider.md`, `secrets-management.md`). Each link is verified to actually deep-link to the named content (open it, confirm the section exists) — the fix is worthless if the anchor is wrong. A per-file checklist keeps the ~409-link sweep tractable and reviewable.

**D4 — Enforcement lives in `lint:content`.** Extend `study-hub/scripts/lint-content.mjs` with a rule that, for links in `domains/**` and `labs/**`, flags: (a) host-only URLs (no path or `/` only), and (b) a denylist of known landing-page/doc-root patterns (e.g., `/docs/$`, `/docs/concepts/$`, `.../intro$`) — **unless** the link line is marked `(reference)`. Mirror the same rule in an `oss-500` repo-side script (invocable in CI) so the content repo catches violations without depending on study-hub. The denylist is pragmatic (catches the real offenders) rather than a perfect URL classifier; false positives are silenced by the honest `(reference)` marker or by making the link specific.

**D5 — Scope the estimate to the slice, and prefer stable anchors.** When narrowing to a range, adjust `(~NN min)` down to match. Prefer official, stable doc anchors over blog posts; where a doc has no anchor for the exact subsection, name the heading in the link text and point at the closest addressable page.

## Risks / Trade-offs

- **Volume (~409 links) risks a shallow pass.** → File-by-file checklist with per-link verification (open, confirm the section); the lint (D4) is the backstop that proves the end state, so completeness is checkable, not vibes.
- **Deep anchors rot faster than homepages.** → Prefer official docs with durable anchors; keep the link text descriptive so a moved anchor still tells the learner what to search for; this change explicitly is not a liveness checker, but the lint can later grow a link-check.
- **Over-marking `(reference)` to dodge the rule.** → `(reference)` is only for genuine lookup/provenance (tool home, framework index, API reference); a resource the learner must actually read to pass/complete stays a specific learning resource. Reviewed during the audit.
- **Lint false positives on legit deep links.** → The denylist targets known roots, not all shallow URLs; anything mis-flagged is fixed by a real anchor or the `(reference)` marker, both of which are improvements.
- **study-hub coupling.** → The lint change lands in study-hub; the content audit lands in oss-500. Apply order: fix content → add/adjust lint → bump submodule → `lint:content` + tests green.
