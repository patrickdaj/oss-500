# Rank every learning link by necessity

## Why

This is the student's literal complaint. Across all six domains, each objective lists 4–6 resources with time estimates and sporadic `(reference)` tags, but **nothing tells the learner which link he must read to do the lab, which he must read to pass the quiz, and which is optional depth** (audit Part 2, lines 47–66; suggested change line 150). A careful engineer facing a six-link stack under `governance` cannot tell that OPA's Rego doc is load-bearing while the other five are enrichment — so he either reads all six (drowns) or skips the one that unblocks the lab.

The `resource-citation` spec already governs link *specificity* (deep-link, name the section, scope the time estimate, mark `(reference)`). It says nothing about *necessity ranking* — the missing piece. The good news the audit stresses: the genuinely mandatory links are few and nameable (audit table, lines 53–64), so most links resolve to optional depth, confirming how self-contained the notes already are. The fix is a one-word tag per link plus a lint rule, not new prose.

## What Changes

- Extend `resource-citation` with a **per-link necessity tag** required on every learning link in `domains/**` and `labs/**`: `[required-for-lab]` (must read before the lab is doable), `[required-for-quiz]` (in exam scope, under-taught in-note), or `[depth]` (enrichment). A link may already be marked `(reference)` (navigational/canonical) — those are exempt from the necessity tag because they are not learning resources.
- The load-bearing references named in the audit table (lines 53–64) SHALL carry a `required-*` tag: OPA/Rego, the ZTNA Terraform provider registry docs + NetBird self-host quickstart, the Vault policies doc, the ModSecurity Reference Manual, the Kubernetes "Encrypting data at rest" task page, OWASP LLM Top 10, the OTel GenAI semantic conventions, Prometheus PromQL querying-basics, the pySigma/sigma-cli backend docs, and the MCP authorization spec + Keycloak token-exchange doc + RFC 8693 §1.1. Everything not doing load-bearing work resolves to `[depth]`.
- Add the necessity tag to the content lint (`scripts/lint-links.mjs`): a learning link with no necessity tag and no `(reference)` marker fails the lint.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `resource-citation` — adds a requirement that every learning link carry a necessity tag (`[required-for-lab]` / `[required-for-quiz]` / `[depth]`), and extends the lint to enforce it. This is additive to the existing specificity requirements, not a change to them.

## Impact

- Affected specs: `resource-citation` (two ADDED requirements — the necessity tag, and its lint enforcement).
- Affected content (at implementation time): a necessity tag on every learning link across `domains/**` and `labs/**`; the load-bearing links from the audit table tagged `required-*`; a rule added to `scripts/lint-links.mjs`.
- Directly answers the "drowning in a link list not knowing which one is load-bearing" complaint that motivated the audit.
