## 1. Deduplicate the cited question pairs (edit YAML only)

- [x] 1.1 `quiz-1.yaml` `q1-26` ↔ `quiz-4.yaml` `q4-29` — keep `q1-26` as the canonical "compliance score ≠ formal certification" question; repurpose `q4-29` to a distinct D4 `vuln-compliance` delta (e.g. trending/prioritizing the highest-weighted failing controls). Keep `vuln-compliance` covered.
- [x] 1.2 `quiz-1.yaml` `q1-15` ↔ `quiz-6.yaml` `q6-01` — keep `q1-15` as the SPIFFE fundamental (SPIFFE ID + SVID via attestation); repurpose `q6-01` to assume that fundamental and test **SVID (workload identity) vs. delegated on-behalf-of token (user authority)**. Leave `q6-15` (authn by SPIFFE ID, not IP) as a distinct question. Keep `agent-workload` covered.
- [x] 1.3 `quiz-4.yaml` `q4-15` ↔ `q4-16` — keep `q4-15` as the single Sigma-portability question; repurpose `q4-16` to a distinct `siem-detect` delta (conversion pipeline / field-mapping / backend+pipeline mechanics). Keep `siem-detect` covered.
- [x] 1.4 `quiz-5.yaml` `q5-01` ↔ `q5-18` — keep `q5-01` as the canonical four-step method; repurpose `q5-18` onto its `av-atomic` objective (Atomic Red Team specifics). Keep `pt-method` and `av-atomic` covered.
- [x] 1.5 `quiz-5.yaml` "no alert = a finding" cluster `q5-02` / `q5-05` / `q5-13` — keep `q5-02` (honesty discipline, `pt-method`) and `q5-05` (AI-probe delta, `av-ai-garak` / missing NeMo rail); repurpose `q5-13` onto its `av-caldera-stratus` objective (multi-sensor coverage specifics). Keep `av-caldera-stratus` / `av-atomic` covered.
- [x] 1.6 `quiz-5.yaml` `q5-13` ↔ `quiz-6.yaml` `q6-18` — confirm the cross-bank overlap is resolved by 1.5; keep `q6-18` as the D6 delta (action-gate + mcp-authz, ATLAS AML.T0053).

## 2. Preserve coverage and schema validity

- [x] 2.1 Verify each edited/repurposed question keeps all `objectiveIds` resolving to `tracker.yaml` ids, `answer` indices zero-based and in range for its `options[]`, and `type`/`explanation`/`docUrl` present (per `study-data-format`).
- [x] 2.2 Verify each edited bank still meets its floor (≥25 for `d1`–`d4`, ≥18 for `d5`–`d6`) and that no `objectiveId` previously carried by an edited bank lost its coverage; reclaimed slots map to under-covered objectives.
- [x] 2.3 Re-scan the edited banks for any remaining intent-level overlap introduced by a repurpose.

## 3. Regenerate views, validate, finalize

- [x] 3.1 Run `npm run gen:md` to regenerate `assessment/checkpoint-1.md`, `checkpoint-4.md`, `checkpoint-5.md`, `checkpoint-6.md` from the edited YAML — do not hand-edit the checkpoint md files.
- [x] 3.2 Run the quiz validation / lint (`npm test` and/or `npm run lint:content` / `npm run lint:links` as available) — green.
- [x] 3.3 `cd /Users/patrick/Development/oss-500 && openspec validate dedup-quiz-question-intent --strict` passes.
- [x] 3.4 study-hub: bump the `content/oss-500` submodule and confirm `lint:content` + tests stay green with the deduplicated banks.
