# Deploy the AI guardrails + gateway in the request path

## Why

The Domain 3 AI-security lab (`labs/d3-ai-security.md`) and the Domain 5 AI red-team lab (`labs/d5-ai-redteam.md`) both hinge on a **guardrailed AI gateway** — an enforcing hop in front of Ollama that authenticates callers, rate-limits, and runs NeMo Guardrails input/output rails. The lab's headline observables are: a `401`/`429` from the gateway, a jailbreak prompt refused, a seeded secret redacted by the output rail, and `guardrail.blocked` OpenTelemetry spans.

**None of that exists at runtime.** `lab-infra/ai/up.sh` deploys only Ollama, Open WebUI, and the OTel collector as real workloads; it creates `nemo-guardrails` and `ai-gateway-policy` **only as inert ConfigMaps** — there is no gateway/guardrails Deployment or Service. `lab-infra/ai/open-webui/deployment.yaml` points `OLLAMA_BASE_URL` straight at Ollama, and the Ollama NetworkPolicy even allows `app: open-webui` directly, so nothing sits in the request path. The lab then tells the student to `curl http://ai-gateway.oss500-apps:8080/v1/chat` (a Service that does not exist) and expect enforcement. `lab-infra/ai/README.md` compounds it by listing these as "Deployment," contradicting the manifests.

Result: every AI-security observable in D3 (Parts A–E) is unreachable, and the entire D5 AI red-team track — which fires garak at "the NeMo-fronted gateway" — attacks a target that never stands up. This is the single highest-impact instance of lab prose drifting from the deployed reality, and it blocks two domains.

## What Changes

- Ship a real **AI gateway** workload (Deployment + Service on `:8080` in `oss500-apps`) that sits in the request path and enforces: authentication (returns `401` without a valid token), rate limiting (`429`), and NeMo Guardrails input/output rails using the existing `guardrails/config.yml` + `prompts.yml`.
- Ship a **NeMo Guardrails** runtime (as its own Deployment or in-process in the gateway) so the rails actually execute, and re-point Open WebUI's model endpoint **through** the gateway.
- Tighten the Ollama `NetworkPolicy` so the gateway/guardrails are the **only** legitimate client (drop the direct `open-webui → ollama` allow once the gateway exists).
- Correct `lab-infra/ai/README.md` to describe what is actually deployed, and align `labs/d3-ai-security.md` step 2 wording ("podSelector labels," not "ServiceAccounts").
- Confirm the D5 target (`labs/d5-ai-redteam.md`) resolves to the now-running gateway; no D5 lab text change should be needed beyond the target being reachable.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `lab-infrastructure` — adds a requirement that the AI component deploys its enforcing guardrails/gateway **in the request path**, so the D3 and D5 AI observables are reproducible from `up.sh` as shipped.

## Impact

- Affected specs: `lab-infrastructure` (one ADDED requirement).
- Affected content (at implementation time): `lab-infra/ai/` (new gateway + guardrails manifests, `up.sh`, NetworkPolicy, `README.md`), `labs/d3-ai-security.md` (step-2 wording), and verification that `labs/d5-ai-redteam.md` now has a live target.
- Unblocks: all `ai-*` objectives in D3 and the AI track of D5 (`av-ai-garak`, `av-ai-pyrit`).
