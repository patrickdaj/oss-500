# Tasks — rank-learning-references

## 1. Define the necessity tag

- [ ] 1.1 Fix the tag vocabulary to `[required-for-lab]`, `[required-for-quiz]`, `[depth]`, with `(reference)` reserved for navigational/canonical links (not learning resources). Document it where the `resource-citation` conventions live so contributors know the three values and when each applies.
- [ ] 1.2 State the placement convention (tag adjacent to the link text or its time estimate) so the lint can detect it and it reads cleanly in-note.

## 2. Tag the load-bearing references

- [ ] 2.1 Tag `required-*` on every reference named in the audit's load-bearing table (`assessment/curriculum-path-gap-audit.md` lines 53–64): OPA/Rego (`governance`), the ZTNA Terraform provider registry docs + NetBird self-host quickstart (D1 ZTNA labs), the Vault policies doc (`secrets-management`), the ModSecurity Reference Manual (`waf-rules`), the Kubernetes "Encrypting data at rest" task page (`data-protection`), OWASP LLM Top 10 and the OTel GenAI semantic conventions (`ai-security`), Prometheus PromQL querying-basics (`observability`), the pySigma/sigma-cli backend docs (`siem-detect`), and the MCP authorization spec + Keycloak token-exchange doc + RFC 8693 §1.1 (D6).
- [ ] 2.2 Tag `[depth]` (or confirm `(reference)`) on every remaining learning link across `domains/**` and `labs/**`, so each objective's stack tells the learner exactly which one link is load-bearing.

## 3. Extend the lint

- [ ] 3.1 Add a rule to `scripts/lint-links.mjs` that fails a learning link in `domains/**` or `labs/**` when it carries no necessity tag and is not marked `(reference)`; the message SHALL name the file, link, and reason.
- [ ] 3.2 Run the content lint and confirm it passes with every learning link tagged (or `(reference)`-marked).

## 4. Validation

- [ ] 4.1 Run `openspec validate rank-learning-references --type change --strict` and fix until it passes.
