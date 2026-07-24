# resource-citation Specification

## Purpose

OSS-500 is a curriculum meant to get a learner through an exam and a set of hands-on labs, so every external resource it cites is a claim on the learner's time. This capability defines the standard for how each external learning resource is cited: deep-link to the exact page/section/anchor, name the specific heading, chapter/page range, or subsection to read, scope the `(~NN min)` estimate to just that slice, and distinguish a required learning resource (must be specific) from a navigational/canonical reference (a tool/framework home marked `(reference)`). A `lint:content` check enforces the standard going forward.
## Requirements
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

### Requirement: Every learning link carries a necessity tag

Each external link in `domains/**` and `labs/**` that is presented as a **learning resource** SHALL carry a necessity tag stating why the learner would open it: `[required-for-lab]` (the link must be read to complete or verify the lab), `[required-for-quiz]` (the link is in exam scope and the objective under-teaches it in-note), or `[depth]` (enrichment the learner can skip without being blocked). A link already marked `(reference)` (a navigational/canonical lookup, not required reading) is exempt, since it is not a learning resource. The tag is additive to the specificity requirements already governing learning links; it ranks *necessity*, not *specificity*.

Where the audit's load-bearing table (`assessment/curriculum-path-gap-audit.md`, Part 2, lines 53–64) names a reference as the one the note under-teaches, that reference SHALL carry a `[required-for-lab]` or `[required-for-quiz]` tag, and links doing no load-bearing work SHALL resolve to `[depth]`.

#### Scenario: A load-bearing reference is tagged required

- **WHEN** a learner opens the resource list for an objective whose note under-teaches a skill the lab or quiz needs — e.g. `governance` (OPA/Rego), the ZTNA labs (Terraform provider registry docs + NetBird self-host quickstart), `secrets-management` (Vault policies doc), `waf-rules` (ModSecurity Reference Manual), `data-protection` (Kubernetes "Encrypting data at rest"), `ai-security` (OWASP LLM Top 10, OTel GenAI semantic conventions), `observability` (Prometheus PromQL querying-basics), `siem-detect` (pySigma/sigma-cli backend docs), or the D6 MCP objectives (MCP authorization spec, Keycloak token-exchange doc, RFC 8693 §1.1)
- **THEN** that reference is tagged `[required-for-lab]` or `[required-for-quiz]`, so the learner can tell at a glance which single link in the stack is the one he must read

#### Scenario: Enrichment links resolve to depth

- **WHEN** a learner reads a multi-link resource list in which only one link is load-bearing
- **THEN** every link that is not required to do the lab or pass the quiz carries `[depth]` (or `(reference)` if it is a canonical lookup), so the learner can skip the rest without fear of missing something required

#### Scenario: Necessity is distinct from specificity

- **WHEN** a link is already specific and time-scoped per the existing citation requirements
- **THEN** it still carries a necessity tag, because specificity ("what to read") and necessity ("whether you must read it") are separate signals and both are required on a learning link

### Requirement: A lint check enforces the necessity tag

The content lint (`scripts/lint-links.mjs`) SHALL fail when a learning link in `domains/**` or `labs/**` carries no necessity tag (`[required-for-lab]`, `[required-for-quiz]`, or `[depth]`) and is not marked `(reference)`. The check SHALL run in the repo's content-lint entry point and SHALL pass after the audit's tags are applied.

#### Scenario: Lint rejects an untagged learning link

- **WHEN** a contributor adds a learning link to a note or lab with no necessity tag and no `(reference)` marker
- **THEN** the content lint fails and names the offending file, link, and the missing-necessity-tag reason

#### Scenario: Lint passes once every learning link is ranked

- **WHEN** every learning link in `domains/**` and `labs/**` carries a necessity tag or is marked `(reference)`
- **THEN** the content lint passes with no missing-necessity-tag violations

