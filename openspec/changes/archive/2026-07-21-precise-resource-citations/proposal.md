## Why

OSS-500 is a **curriculum meant to get a learner through an exam and a set of hands-on labs** — every external resource it cites is a claim on the learner's time, and a vague claim wastes it. Today ~409 external links carry a `(~NN min)` estimate but many still point at a **whole doc site, framework home, or landing page** — `[Helm — documentation](https://helm.sh/docs/)`, `[Kubernetes — Concepts](https://kubernetes.io/docs/concepts/)`, `[Terraform — Intro](…/terraform/intro)` — with no indication of *what on that page to actually read*. 37 links are host-only or one path-segment deep. "Go read the Terraform docs" is a wild-goose-chase: the learner burns time hunting for the relevant part, over-reads, or gives up. A curriculum's job is to say **exactly** what to read/watch and no more.

## What Changes

- **New citation standard** (`resource-citation`): a documented convention for how every learning resource is cited — deep-link to the exact page/section/anchor; name the specific heading, chapter/page range, or subsection to read; for multi-part or long resources, give the **range** (e.g., "§4–7", "chapters 2–3", video "12:00–24:00"); keep the `(~NN min)` estimate scoped to *that* slice; and distinguish a **learning resource** (must be specific) from a **canonical/navigational reference** (a tool/framework home, cited once, explicitly marked `(reference)`).
- **Audit and fix every existing external link** in `domains/**` and `labs/**` to meet the standard — replacing landing-page links with deep links + a "read this" pointer, adding section/chapter/timestamp scoping where a resource is only partially needed, and marking true look-it-up references as `(reference)` so they're not mistaken for required reading.
- **A `lint:content` check** (in the study-hub `scripts/lint-content.mjs`, mirrored as a repo pre-commit-style script) that **flags generic links** — host-only, or a landing page with no section descriptor and not marked `(reference)` — so the standard is enforced going forward, not just fixed once.
- **`domains/standards-map.md` guidance updated** so the framework/tool homepages it lists are explicitly the `(reference)` navigational kind, keeping the standard honest about when a bare home link is acceptable.

## Capabilities

### New Capabilities
- `resource-citation`: The curriculum's standard for citing external learning resources so each tells the learner precisely what to read/watch (specific page/section/anchor, chapter/page or timestamp range, scoped time estimate) and distinguishes required learning resources from navigational references — plus the lint check that enforces it.

### Modified Capabilities
<!-- The build-oss-500-course capabilities are not archived to openspec/specs/, so this
     change carries its requirements as a new capability rather than a delta. It touches
     shared content (every note/lab's links) and the study-hub lint script at apply time. -->
- None (no archived specs to delta).

## Impact

- **Content (bulk)**: external links across `domains/**` (notes, incl. the `0-fundamentals/` "Primary sources" blocks — the worst offenders) and `labs/**` are rewritten to be specific. High-link files (`identity-provider.md`, `ai-security.md`, `secrets-management.md`, `siem-incident-response.md`, `supply-chain.md`, `network-security.md`) carry the most edits; `standards-map.md` gets the `(reference)` framing.
- **Tooling**: `study-hub/scripts/lint-content.mjs` gains a link-specificity rule; a repo-side script (or `gen:md`-adjacent check) mirrors it so `oss-500` CI catches generic links. `npm run lint:content` must stay green after the audit.
- **study-hub**: content-only from its side — after the audit, bump the `content/oss-500` submodule and confirm `lint:content` + tests stay green and pages still render.
- **No behavior change to labs/tracker/quiz**: this is a resource-quality and enforcement change; objective ids, lab steps, and assessments are untouched except where a link inside them is made specific.
