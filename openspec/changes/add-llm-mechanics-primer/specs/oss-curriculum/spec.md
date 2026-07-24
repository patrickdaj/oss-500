## ADDED Requirements

### Requirement: LLM mechanics are taught in an AI on-ramp before ai-security.md assumes them
The curriculum SHALL contain an LLM-mechanics primer — as a `0-fundamentals` note or a D3 preamble placed ahead of `domains/3-compute-ai/ai-security.md` — that teaches token and tokenization, the context window, the system-vs-user prompt split, embeddings, vector stores, and the RAG retrieve→augment→generate loop. The primer SHALL define this vocabulary sufficiently for the learner to follow `ai-security.md`'s threat model from course materials alone, SHALL be flagged concept-new (consistent with the AI-security notes), and SHALL be cross-linked from `ai-security.md` and the secure-RAG objective rather than duplicated. The change SHALL NOT remove or rewrite the existing `ai-security.md` threat-model content, which the audit judged strong.

#### Scenario: The assumed AI vocabulary is defined before it is used
- **WHEN** a learner opens `ai-security.md`, which reasons over tokens, context windows, prompts, embeddings, vector stores, and RAG
- **THEN** a linked LLM-mechanics primer has already defined each of those terms, so the AI-newcomer persona can follow the threat model without leaving the course

#### Scenario: The RAG loop is walked before secure-RAG uses it
- **WHEN** a learner reaches the secure-RAG objective
- **THEN** the primer has already walked the retrieve→augment→generate loop, and the secure-RAG note cross-links it rather than re-explaining RAG

#### Scenario: The existing threat model is preserved
- **WHEN** the primer is added
- **THEN** `ai-security.md`'s threat-model teaching is left intact and the primer sits beneath it as the missing mechanics substrate
