## Why

The checkpoint quiz banks (`assessment/data/quiz-1.yaml` .. `quiz-6.yaml`) contain questions that test the **same intent** — not just shared keywords, but the same underlying idea and the same correct-answer takeaway — both across banks and within a single bank. Redundant questions waste scarce checkpoint slots (D5/D6 have only ~18–19 questions), inflate the apparent coverage of a few ideas while leaving other objectives thin, and let a learner "pass" by re-answering one concept several times. The banks are the single source of truth (`checkpoint-<n>.md` are generated from them), so the fix belongs in the YAML.

Confirmed intent-level duplicate pairs (stem + correct-answer explanation read):

- **Cross-bank — score ≠ certification:** `quiz-1.yaml` `q1-26` and `quiz-4.yaml` `q4-29` both teach that a framework/technical-controls compliance **score** (Kubescape `scan framework nsa` / an "84% NSA" number) is a trend to improve, **not** formal certification.
- **Cross-bank — SPIFFE fundamental re-taught:** `quiz-1.yaml` `q1-15` establishes that a workload proves identity via attestation and gets a SPIFFE ID in an SVID. `quiz-6.yaml` `q6-01` re-teaches that same fundamental ("an SVID authenticates which process this is") instead of testing the agent-specific delta. `q6-15` (authenticate by SPIFFE ID, never by IP/subnet) is a distinct anti-pattern and is kept.
- **Intra-bank — Sigma is a format, not an engine:** `quiz-4.yaml` `q4-15` and `q4-16` both land on "Sigma is a portable format that must be converted to a backend query to detect anything."
- **Intra-bank — the four-step method:** `quiz-5.yaml` `q5-01` and `q5-18` both hinge on "name the exact ATT&CK/ATLAS technique" as the crux of the method.
- **Intra-bank — "no alert = a publishable finding":** `quiz-5.yaml` `q5-02`, `q5-05`, and `q5-13` all teach that silence/a passed probe IS the finding — document the gap. (~5 of quiz-5's 19 slots go to these two ideas.)
- **Cross-bank — "document the gap / name the missing control":** `quiz-5.yaml` `q5-13` and `quiz-6.yaml` `q6-18` both teach "record the finding and name the missing control"; `q6-18` carries the D6-specific delta (action-gate + mcp-authz, ATLAS AML.T0053) and is kept.

## What Changes

- **Remove or repurpose each duplicate** so every remaining question tests a **distinct intent**. Where the duplicate sits in a domain that owns a distinct *delta* on the shared idea, it is **repurposed** to test that delta assuming the fundamental; where it is a plain restatement it is repurposed onto an under-covered objective in the same bank. No question is simply deleted if that would drop objective coverage.
  - `q4-29`: repurpose to a D4-specific `vuln-compliance` delta (distinct from `q1-26`'s "score ≠ certification" teach).
  - `q6-01`: repurpose to assume the SPIFFE fundamental and test **SVID (workload identity) vs. delegated on-behalf-of token (user authority)** — the agent delta — rather than re-teaching what an SVID is.
  - `q4-16`: repurpose to a distinct `siem-detect` delta (the conversion pipeline / field-mapping), keeping `q4-15` as the single Sigma-portability question.
  - `q5-18`: repurpose onto its `av-atomic` objective (Atomic Red Team specifics), keeping `q5-01` as the canonical four-step-method question.
  - `q5-13`: repurpose onto its `av-caldera-stratus` objective (multi-sensor coverage specifics); keep `q5-02` as the canonical honesty-discipline question and `q5-05` as the AI-probe-specific instance (`av-ai-garak` / NeMo rail).
- **Reclaim the freed intent** for under-covered objectives while **preserving every objectiveId** currently covered, so the domain question floors (≥25 for `d1`–`d4`, ≥18 for `d5`–`d6`) and objective coverage do not regress.
- **Regenerate** the `checkpoint-<n>.md` views from the edited YAML (`npm run gen:md`). Checkpoint markdown is not hand-edited.

## Capabilities

### Modified Capabilities
- `assessment-tracking`: strengthen **Per-domain checkpoint quizzes** so that no two questions across the banks test the same intent — duplicates are removed or repurposed to test the domain-specific delta, and reclaimed slots map to under-covered objectives.

## Impact

- **Content (edited):** `assessment/data/quiz-1.yaml`, `quiz-4.yaml`, `quiz-5.yaml`, `quiz-6.yaml` (the cited questions). `quiz-2.yaml` / `quiz-3.yaml` are unchanged.
- **Generated (regenerated, not hand-edited):** `assessment/checkpoint-1.md`, `checkpoint-4.md`, `checkpoint-5.md`, `checkpoint-6.md` via `npm run gen:md` — the checkpoint md files open "Generated from quiz-N.yaml"; do not touch them directly.
- **Schema:** edits stay within the `study-data-format` quiz model — every `objectiveIds` entry keeps resolving to a `tracker.yaml` id, and every `answer` index stays zero-based and in range for its `options[]`.
- **Scope note:** the *objective-level* duplication (`gov-compliance` ↔ `vuln-compliance`, and the SVID/workload-identity reuse) is handled by its **own** change at the tracker/objective layer. This change handles the **quiz layer** only — deduplicating the questions themselves; it does not add, remove, or merge tracker objectives.
