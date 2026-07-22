## Context

Checkpoint quizzes are authored as `assessment/data/quiz-<n>.yaml` and rendered to `assessment/checkpoint-<n>.md` by `scripts/gen-md.mjs` (`npm run gen:md`); each checkpoint md opens "Generated from quiz-N.yaml." The banks are therefore the single source of truth. A read of the cited stems and their correct-answer explanations confirms **intent-level** duplication — the same idea and the same takeaway — in six pairs/clusters, both across banks and within a bank. Because D5/D6 carry only ~18–19 questions, spending multiple slots on one idea directly starves other objectives.

The quiz model (`study-data-format` → "Quiz banks conform to the study-hub quiz model") requires each question to have a unique `id`, `stem`, `options[]` (≥2), `type`, zero-based `answer` index(es) in range, `explanation`, `docUrl`, and `objectiveIds` that all resolve to `tracker.yaml` ids. Any repurpose must preserve those invariants. The floors from `assessment-tracking` (≥25 for `d1`–`d4`, ≥18 for `d5`–`d6`) must still hold.

## Goals / Non-Goals

**Goals**
- Each remaining question tests a **distinct intent** — no two questions across all six banks share the same idea + takeaway.
- Where a domain owns a genuine *delta* on a shared idea, keep a question there but rewrite it to test the delta **assuming** the fundamental (don't re-teach the fundamental).
- Reclaim freed slots for **under-covered** objectives; keep every currently-covered `objectiveId` covered.
- Keep the edits schema-valid (`objectiveIds` resolve; `answer` indices in range) and regenerate checkpoints from YAML.

**Non-Goals**
- **Not** reducing the total question count if that drops objective coverage — repurpose rather than merely delete. Domain floors must not regress.
- **Not** changing tracker objectives. The objective-level duplication (`gov-compliance` ↔ `vuln-compliance`, SVID/workload-identity reuse) is a separate change at the tracker layer; this change only deduplicates the quiz questions.
- **Not** editing `checkpoint-<n>.md` by hand — they are generated.

## Decisions

For each duplicate, which question is **kept** as the canonical carrier of the intent, and which is **repurposed** (and to what distinct intent):

| Pair / cluster | Shared intent | Keep | Repurpose |
| --- | --- | --- | --- |
| `q1-26` ↔ `q4-29` | A compliance **score** ≠ formal certification | **`q1-26`** (D1 governance: Kubescape tool-selection + the caveat) | **`q4-29`** → a D4-specific `vuln-compliance` delta (e.g. trending/prioritizing the highest-weighted failing controls in the image/cluster scan workflow), distinct from the "score ≠ cert" teach |
| `q1-15` ↔ `q6-01` (+`q6-15`) | An SVID identifies the **workload**, not authority | **`q1-15`** (D1: SPIFFE ID + SVID via node/workload attestation); **`q6-15`** kept (authn by SPIFFE ID, never by IP/subnet — distinct anti-pattern) | **`q6-01`** → assume the SPIFFE fundamental and test **SVID (workload identity) vs. delegated on-behalf-of token (user authority)** — the agent-specific delta |
| `q4-15` ↔ `q4-16` | Sigma is a **portable format, not an engine** | **`q4-15`** (write-once → convert-to-many; detection-as-code) | **`q4-16`** → a distinct `siem-detect` delta (the conversion pipeline / field-mapping / backend+pipeline mechanics), not restating "format not engine" |
| `q5-01` ↔ `q5-18` | Four-step method — **name the ATT&CK technique** | **`q5-01`** (the ordered four-step method) | **`q5-18`** → its `av-atomic` objective (Atomic Red Team test specifics), preserving `av-atomic` coverage |
| `q5-02` / `q5-05` / `q5-13` | "No alert / passed probe = a publishable **finding**" | **`q5-02`** (canonical honesty discipline, `pt-method`); **`q5-05`** kept as the AI-probe-specific instance (`av-ai-garak` / name the missing NeMo rail — a distinct delta) | **`q5-13`** → its `av-caldera-stratus` objective (multi-sensor Caldera/Stratus coverage specifics), preserving `av-caldera-stratus` / `av-atomic` coverage |
| `q5-13` ↔ `q6-18` | "Document the gap / name the missing control" | **`q6-18`** kept (D6 delta: action-gate + mcp-authz, ATLAS AML.T0053) | (`q5-13` already repurposed above) |

Rationale for the keep choices: the **domain that owns the fundamental** keeps the canonical teach (D1 for SPIFFE and for compliance-score nuance; the `pt-method` question for the honesty discipline); the **domain that owns a distinct delta** either keeps a delta-specific question (`q6-15`, `q6-18`, `q5-05`) or has its duplicate rewritten into that delta (`q6-01`, `q4-29`). Plain restatements with no delta (`q4-16`, `q5-18`, `q5-13`) are repurposed onto under-covered objectives they already reference, so coverage is preserved rather than lost.

## Risks / Trade-offs

- **Regenerating checkpoints:** `checkpoint-1/4/5/6.md` change as a side effect. They **regenerate from the YAML** via `npm run gen:md`; do not hand-edit them. Forgetting to regenerate would leave the md views stale — the tasks include the regen step and a validate/lint pass.
- **Repurpose drift:** a repurposed question could accidentally restate a *different* existing question. Mitigation: each repurpose is checked against the rest of the bank for intent overlap before landing.
- **Coverage regression:** deleting instead of repurposing could drop an objective below coverage or a bank below its floor. Mitigation: the non-goal forbids count reduction that drops coverage; repurposed questions retain (or move onto an under-covered) `objectiveId`, and the floors (≥25 / ≥18) are re-checked.
- **Schema breakage:** rewritten `options[]`/`answer` could put the answer index out of range or reference a non-existent objective. Mitigation: `lint:content` / `npm test` validates `answer` ranges and `objectiveIds` resolution; `openspec validate --strict` gates the change.
