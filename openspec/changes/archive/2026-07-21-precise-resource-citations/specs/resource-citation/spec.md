## ADDED Requirements

### Requirement: Every learning resource cites specifically what to read or watch
Each external link in `domains/**` and `labs/**` that is presented as a **learning resource** (something the learner is expected to read or watch to gain a skill, pass the exam, or complete a lab) SHALL point the learner to the specific content to consume, not a whole site or landing page. Specifically it SHALL: (a) deep-link to the exact page/section/anchor rather than a documentation root or homepage; and (b) name, in the link text or an adjacent phrase, the specific section, heading, chapter/page range, or subsection to read. A bare host or a landing page with no indication of what to read is not permitted for a learning resource.

#### Scenario: A generic landing-page link is made specific
- **WHEN** a note or lab cites a resource such as `[Helm — documentation](https://helm.sh/docs/)` or `[Kubernetes — Concepts](https://kubernetes.io/docs/concepts/)`
- **THEN** it is replaced by a deep link to the specific page/anchor plus a "read this" pointer (e.g., the specific concept page and the heading that covers the objective), so the learner knows exactly what to open and read

#### Scenario: Learning resource names its target
- **WHEN** any learning-resource link is read
- **THEN** the learner can tell, without opening it, which section/heading/chapter to read — the link text or adjacent text names it

### Requirement: Partially-needed resources state the range to consume
When a cited resource is longer than what the objective requires (a multi-section page, a book, a video, a multi-part tutorial), the citation SHALL state the **bounded portion** to consume — the section range, chapter/page range, or video timestamp range — and its `(~NN min)` estimate SHALL reflect that bounded portion, not the whole resource.

#### Scenario: A video cites the needed timestamps
- **WHEN** a video is cited but only part of it is needed
- **THEN** the citation gives the timestamp or section range to watch (e.g., "watch 12:00–24:00" or "sections 4–7") and the time estimate covers only that range

#### Scenario: A book or long doc cites the needed chapters/sections
- **WHEN** a book or a long multi-section document is cited
- **THEN** the citation names the specific chapters/pages or sections to read, not the entire work, with a matching time estimate

### Requirement: Required learning is distinguished from navigational references
The curriculum SHALL distinguish a **learning resource** (required reading/watching, must be specific per the requirements above) from a **navigational/canonical reference** (a tool's home page, a framework's site, or an API index cited for lookup or provenance, not as required reading). Canonical references MAY be a homepage/root but SHALL be explicitly marked `(reference)` (optionally with a scope note) so a learner does not mistake them for required reading. `domains/standards-map.md`'s framework/tool homepages SHALL be treated as such references.

#### Scenario: A canonical reference is marked
- **WHEN** a homepage or framework-root link is retained because it is a lookup/provenance reference rather than required reading (e.g., a tool's main site, an ATT&CK/D3FEND/CIS home)
- **THEN** it is annotated `(reference)` so it is not counted as a required learning resource

### Requirement: A lint check enforces link specificity
The content lint (`study-hub/scripts/lint-content.mjs`, mirrored by an `oss-500` repo-side check) SHALL fail when a link in `domains/**` or `labs/**` is generic — a host-only URL, or a known documentation-root/landing-page pattern — unless the link is explicitly marked `(reference)`. The check SHALL run in `npm run lint:content` and SHALL pass after the audit.

#### Scenario: Lint rejects a new generic link
- **WHEN** a contributor adds a host-only or documentation-root link that is not marked `(reference)`
- **THEN** `npm run lint:content` fails and names the offending file, link, and reason

#### Scenario: Lint passes after the audit
- **WHEN** the audit is complete and all learning resources are specific (or marked `(reference)`)
- **THEN** `npm run lint:content` passes with no link-specificity violations
