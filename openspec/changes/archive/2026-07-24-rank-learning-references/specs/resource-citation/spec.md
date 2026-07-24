## ADDED Requirements

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
