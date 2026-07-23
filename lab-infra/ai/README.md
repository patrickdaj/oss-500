# lab-infra/ai — Ollama + Open WebUI + NeMo Guardrails + OPA gateway

The AI-workload security stack (`d3-ai` → `ai-access`, `ai-prompt`, `ai-guardrails`, `ai-rag`, `ai-observability`, `ai-governance`). This subsection is **new to SC-500**. It mirrors the Azure AI security surface: **Azure OpenAI access control** (Entra + APIM AI gateway), **Azure AI Content Safety / Prompt Shields**, **secure RAG on Azure AI**, **Azure AI monitoring**, and **AI governance / Purview DSPM for AI**.

## What this brings up

| Component | Form | Role | Objective |
|---|---|---|---|
| Ollama | `ollama/ollama` (Helm or Deployment) | local model server (`llama3.2:1b`) | `ai-access`, `ai-rag` |
| Open WebUI | Deployment | chat UI + RAG (knowledge bases, per-user workspaces), routed through the gateway | `ai-rag`, `ai-guardrails` |
| AI gateway | Deployment (`gateway` + `opa` sidecar) | the enforced hop: bearer authn (401) + rate limit (429), **NeMo Guardrails** input/output rails run in-process, OPA governance/quota decision, OTel spans | `ai-access`, `ai-prompt`, `ai-guardrails`, `ai-governance`, `ai-observability` |
| OpenTelemetry | collector / SDK config | LLM traces + token metrics | `ai-observability` |

All in **`oss500-apps`**. **Ollama is `ClusterIP`-only — never exposed** (it has no built-in auth; `ai-access`). A NetworkPolicy restricts `:11434` so **only the `ai-gateway` pod** reaches it (Open WebUI and the guardrails both go through the gateway). Model choice is deliberately tiny (`llama3.2:1b`, ~1.3 GB; swap `qwen2.5:0.5b` for an even lighter host) so it fits the ~16 GB reference host with the rest of the phase-3 stack.

## Layout

```
ai/
├── README.md
├── up.sh                          # deploy ollama, pull model, open-webui, guardrails, gateway
├── down.sh                        # tear down (+ --purge removes the model volume)
├── ollama/deployment.yaml         # Ollama Deployment+Service (ClusterIP) + NetworkPolicy
├── open-webui/deployment.yaml     # Open WebUI Deployment+Service+Ingress
├── gateway/                       # the enforced hop (built + kind-loaded by up.sh)
│   ├── app.py                     #   FastAPI: authn/rate-limit, NeMo rails, OTel spans
│   ├── requirements.txt           #   pinned deps
│   ├── Dockerfile                 #   ai-gateway:local image
│   └── deployment.yaml            #   Deployment (gateway + OPA sidecar) + Service
├── guardrails/config.yml          # NeMo Guardrails: input/output rails wiring
├── guardrails/prompts.yml         # self-check-input / self-check-output prompts
├── opa/gateway-policy.rego        # ai-access authz + ai-governance allowed-models policy
├── otel/collector.yaml            # OpenTelemetry collector (GenAI spans/metrics)
└── open-webui.secret.example      # copy → .secret: WEBUI_SECRET_KEY, admin creds (gitignored)
```

## Usage

```bash
cd lab-infra/ai
cp open-webui.secret.example open-webui.secret     # set WEBUI_SECRET_KEY + admin creds
./up.sh                                            # pulls llama3.2:1b on first run (~1.3 GB)
# Open WebUI at http://ai.oss500.local (shared ingress). Do labs/d3-ai-security.md.
./down.sh                                          # add --purge to drop the model volume
```

## Security model (what each control proves)

- **`ai-access`**: Ollama is private (`ClusterIP` + NetworkPolicy); the OPA gateway authenticates (Keycloak OIDC) and **token**-rate-limits. Calling the model port directly is blocked.
- **`ai-prompt` / `ai-guardrails`**: every prompt/response passes through NeMo Guardrails — a jailbreak is refused (`self check input`), a leaking response is blocked (`self check output`).
- **`ai-rag`**: Open WebUI per-user knowledge bases isolate data; retrieval honors the user's permissions; pipeline secrets come from Vault (Domain 2), not env vars.
- **`ai-observability`**: the gateway/app emits OpenTelemetry GenAI spans (token counts, `enduser.id`, `guardrail.blocked`) to the collector → Domain 4 SIEM.
- **`ai-governance`** *(walkthrough)*: `opa/gateway-policy.rego` is the single central policy point — allowed models, per-group access, quotas, audited decisions.

## Secrets hygiene

`open-webui.secret` (session key + admin creds) is gitignored — only `.example` is committed. Any generated cosign/OIDC material stays out of git. Never log raw prompts/responses containing secrets (`ai-observability`): the OTel config redacts/hashes.
