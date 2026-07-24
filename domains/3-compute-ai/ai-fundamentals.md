# LLM fundamentals: the mechanics ai-security.md assumes

> **🆕 Concept-new.** This vocabulary — tokens, context windows, embeddings, vector stores, RAG — has no equivalent in AZ-500 or the rest of this course's compute/network material. It is new the same way the rest of Domain 3's AI-security content is new to SC-500. [`ai-security.md`](ai-security.md) reasons over these terms starting in its first paragraph; this note defines them first so the threat model reads as engineering, not incantation.

`ai-security.md` builds a real threat model — prompt injection, data leakage, RAG permission bypass — but it assumes you already know what a token is, what "the context window" refers to, and what happens when a query gets "embedded" and "retrieved." Those aren't security concepts; they're the plumbing an LLM application is built from, the same way you needed namespaces and cgroups before pod hardening made sense (`0-fundamentals/01-containers.md`). This note is that plumbing for AI. It teaches no security control — read it once, then read `ai-security.md` for the controls that sit on top of it.

## Tokens and tokenization

A language model doesn't read characters or whole words — it reads **tokens**, the atomic units its tokenizer splits text into. A tokenizer (most LLMs today use a byte-pair-encoding-family algorithm) learns a fixed vocabulary of common subword chunks from training data, then greedily re-encodes any input against that vocabulary. `"tokenization"` might split as `["token", "ization"]`; `"gpt-oss"` might split as `["g", "pt", "-", "oss"]` — the exact split is model-specific and often *not* whole words, which is why an LLM can stumble on character-level tasks ("how many letters in strawberry") despite fluent prose. Every model call has a token cost on **both** sides: the prompt you send and the completion you get back are each counted, and that count is what a provider bills and what a rate limiter should cap.

That last point is why `ai-access` insists on **token-based** rate limiting rather than request-count limiting: a one-line prompt and a 10,000-token document-summarization prompt are the same "one request" but wildly different cost, so counting requests undercounts abuse while counting tokens doesn't. It's also the unit `ai-observability`'s OpenTelemetry spans report — `gen_ai.usage.input_tokens` / `gen_ai.usage.output_tokens` are token counts, not request counts, per call, per identity.

## The context window

The **context window** is the maximum number of tokens a model can attend to in one call — prompt plus completion plus everything in between. Everything the model "knows" for a given call has to fit inside it: the system prompt, the conversation history, any retrieved document chunks, tool-call results, and the user's latest message all get concatenated into one token sequence up to that limit. There is no separate, protected channel for "instructions" versus "data" — a system prompt, a user question, and a chunk of a poisoned PDF are all just tokens in the same window, distinguished only by role labels and position, not by any enforced privilege boundary.

That single fact is the mechanical root of `ai-prompt`: prompt injection works *because* the model has no hard-walled instruction channel to defend — an attacker's text competes for influence in the exact same window as the developer's system prompt, and a sufficiently persuasive sequence of tokens can outweigh it. Context-window size is also why RAG (below) exists at all: a model can't have your entire document corpus loaded into its window on every call, so an application has to select which few chunks are worth the token budget for *this* query.

## System vs user prompts (and the roles in between)

Chat-tuned models are trained on a **role-structured** conversation format, not raw text. The common roles:

- **`system`** — the developer's standing instructions ("you are a support bot for X, refuse Y, always cite sources"), set once per session and meant to outrank everything that follows.
- **`user`** — the human's message.
- **`assistant`** — the model's own prior replies, fed back in on multi-turn calls so it has conversational memory.
- **`tool`** (or `function`) — the result of a tool/function call the model requested, fed back in as if it were part of the conversation.

The model is *trained* to weight `system` above `user`, which is where the term "instruction hierarchy" comes from — but that weighting is a learned tendency, not an enforced access-control boundary, because (per the context window above) all four roles ultimately collapse into one token sequence. That gap between *intended* hierarchy and *actual* enforcement is exactly what a jailbreak exploits: "ignore your previous instructions" is a user-role message trying to talk over a system-role one, and it sometimes works. `ai-security.md`'s direct-vs-indirect injection split maps onto this: **direct** injection abuses the `user` role trying to overrule `system`; **indirect** injection smuggles instruction-shaped text in through `tool`-role or retrieved-document content the model treats as data but reads as instructions.

## Embeddings

An **embedding** is a fixed-length vector of floating-point numbers (typically hundreds to a few thousand dimensions) that a separate embedding model produces from a piece of text, positioned so that texts with similar *meaning* land at similar *points* in that vector space — not similar spelling, similar meaning. `"kitten"` and `"cat"` embed close together; `"cat"` and `"cattle"` don't, despite sharing more letters. Closeness is measured with a distance metric, almost always **cosine similarity** (the cosine of the angle between two vectors — 1.0 for identical direction, 0 for unrelated, -1 for opposite). Embeddings are what let a system do *semantic* search — "find text about this concept" — instead of keyword matching.

## Vector stores

A **vector store** (vector database) is a database purpose-built to hold embeddings and answer "which of my millions of stored vectors are closest to this query vector" fast, using an approximate-nearest-neighbor index rather than a brute-force scan. Two things matter for security, both surfaced in `ai-security.md`:

- **Metadata filtering** — a vector store lets you attach metadata (owner, tenant, sensitivity label) to each stored vector and filter a search by it *before* or *during* the nearest-neighbor lookup. `ai-rag`'s core rule — retrieval must honor the requesting user's permissions — is implemented exactly here: a correctly built RAG pipeline filters the vector search by "documents this caller may read," not just "documents most similar to this query."
- **What's actually exposed** — OWASP's **LLM08: Vector and Embedding Weaknesses** (linked from `ai-security.md`'s `ai-rag` section) is about this layer specifically: unfiltered collections, embedding-inversion risk, and cross-tenant data bleeding into a shared index.

## The RAG loop: retrieve → augment → generate

**Retrieval-Augmented Generation** is the three-step pipeline that grounds a model's answer in documents it wasn't trained on, without retraining it:

```
 user query
     │
     ▼
 1. RETRIEVE  — embed the query, search the vector store, return the top-k closest chunks
     │
     ▼
 2. AUGMENT   — stuff those chunks into the prompt as context, ahead of the user's question
     │
     ▼
 3. GENERATE  — the model answers using the context it was just handed, in its one context window
```

Concretely: the user's question is run through the same embedding model used to index the corpus, the resulting query vector is compared against every stored document-chunk vector in the vector store, the top-*k* nearest chunks come back as plain text, and that text is concatenated into the prompt (typically right after the system prompt, ahead of the user's actual question) before the model ever generates a token. The model then answers as if those chunks were simply part of what it was told — which is precisely why RAG inherits every context-window and role problem above: retrieved text lands in the same undifferentiated token stream as everything else, so a chunk containing instruction-shaped text is indirect prompt injection (`ai-prompt`), and a chunk the caller shouldn't have been allowed to read is a permissions bypass the model will happily summarize (`ai-rag`). Open WebUI's document-upload/knowledge-base feature, exercised in [d3-ai-security](../../labs/d3-ai-security.md), is this loop end to end: upload builds the embeddings and vector store, a chat question triggers retrieve → augment → generate.

## Why this matters once you're in ai-security.md

Every mechanism above is a load-bearing wall under a specific `ai-security.md` objective:

| Mechanic | Objective it underpins |
|---|---|
| Tokens, token counting | `ai-access` (token-based rate limits), `ai-observability` (token metrics as the abuse signal) |
| Context window, no instruction/data separation | `ai-prompt` (why injection is possible at all) |
| System/user/tool roles, instruction hierarchy | `ai-prompt` (direct vs indirect injection) |
| Embeddings, vector stores, metadata filtering | `ai-rag` (retrieval must honor permissions), OWASP LLM08 |
| The retrieve→augment→generate loop | `ai-rag` (secure RAG architecture), `ai-prompt` (indirect injection via ingested documents) |

## Self-check

1. Why is token-based rate limiting the correct control for `ai-access` when request-count limiting is not?
2. In mechanical terms — not policy terms — why can't a model simply "refuse to obey" text that arrives via a retrieved document the way it might refuse an obviously malicious user message?
3. What's the difference between what an embedding captures and what a keyword search captures?
4. Walk through what happens, step by step, from a user's RAG question to the model's answer — and name the exact step where a permissions check has to happen for `ai-rag`'s core rule to hold.

## Primary sources

- [Hugging Face — Byte-Pair Encoding tokenization](https://huggingface.co/learn/nlp-course/en/chapter6/5) (~15 min)
- [OpenAI — Tokenizer (interactive)](https://platform.openai.com/tokenizer) (~10 min, hands-on)
- [OWASP Top 10 for LLM Applications (2025)](https://genai.owasp.org/llm-top-10/) (~30 min — intro section defines context window/prompt roles before the risks)
- [OpenAI — Embeddings guide](https://platform.openai.com/docs/guides/embeddings) (~15 min)
- [Pinecone — What is a vector database?](https://www.pinecone.io/learn/vector-database/) (~15 min)
- [NVIDIA — What is retrieval-augmented generation?](https://blogs.nvidia.com/blog/what-is-retrieval-augmented-generation/) (~10 min)
