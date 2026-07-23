# Tasks — fix-ai-gateway-in-path

## 1. Deploy the gateway + guardrails in-path

- [ ] 1.1 Add an `ai-gateway` Deployment + Service (`:8080`, namespace `oss500-apps`) under `lab-infra/ai/gateway/` that proxies chat requests to Ollama and enforces auth (`401` when the bearer token is missing/invalid) and rate limiting (`429`).
- [ ] 1.2 Run NeMo Guardrails in the request path — either a `nemo-guardrails` Deployment the gateway calls, or the rails in-process in the gateway — loading the existing `lab-infra/ai/guardrails/config.yml` and `prompts.yml` (mount the ConfigMaps rather than leaving them inert).
- [ ] 1.3 Re-point `lab-infra/ai/open-webui/deployment.yaml` `OLLAMA_BASE_URL` to the gateway, so all model traffic traverses the rails.
- [ ] 1.4 Tighten `lab-infra/ai/ollama/deployment.yaml` NetworkPolicy so only the gateway/guardrails pods may reach `:11434` (remove the direct `app: open-webui` ingress allow once the gateway is in place).
- [ ] 1.5 Update `lab-infra/ai/up.sh` to apply the new manifests (keep the `llama3.2:1b` pull and OTel collector as-is) and confirm `guardrail.blocked` spans are emitted to the collector.

## 2. Reconcile docs and lab text

- [ ] 2.1 Correct `lab-infra/ai/README.md` so the component table matches the shipped workloads (no "Deployment" rows for things that are ConfigMap-only).
- [ ] 2.2 Fix `labs/d3-ai-security.md` step 2 wording to say the Ollama policy gates by **podSelector labels**, not ServiceAccounts, and confirm Parts A–E now describe reachable observables.
- [ ] 2.3 Verify `labs/d5-ai-redteam.md` Part B targets the now-running gateway (`http://ai-gateway.oss500-apps:8080/...`); adjust only if the Service name/port differs.

## 3. Validation

- [ ] 3.1 `cd lab-infra/ai && ./up.sh`; then `curl` the gateway with no token → `401`, with a valid token and a jailbreak prompt → refused, with a benign prompt → answered.
- [ ] 3.2 Seed a fake secret in context, ask the model to repeat it, confirm the **output rail** redacts it; confirm a `guardrail.blocked` span appears for the attacking identity.
- [ ] 3.3 Confirm Ollama is reachable **only** via the gateway (a direct `curl` to `ollama:11434` from an unauthorized pod is denied).
- [ ] 3.4 Run `npm run lint:links` and `npx openspec validate fix-ai-gateway-in-path --strict`.
