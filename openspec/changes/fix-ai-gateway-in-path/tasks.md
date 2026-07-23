# Tasks — fix-ai-gateway-in-path

## 1. Deploy the gateway + guardrails in-path

- [x] 1.1 Added `lab-infra/ai/gateway/` — an `ai-gateway` FastAPI app (`app.py`) serving `/v1/chat/completions` (+ `/v1/chat` alias for the labs) and `/v1/models` on `:8080`, enforcing bearer auth (**401**) and a per-identity token-bucket (**429**); Deployment + Service in `oss500-apps`.
- [x] 1.2 NeMo Guardrails run **in-process** in the gateway (loads the mounted `guardrails/config.yml` + `prompts.yml`), so the input/output rails sit in the request path; the deploy mounts the `nemo-guardrails` ConfigMap.
- [x] 1.3 Re-pointed `open-webui/deployment.yaml` at the gateway (`OPENAI_API_BASE_URL=http://ai-gateway.oss500-apps:8080/v1`, `ENABLE_OLLAMA_API=false`, token from a new `GATEWAY_TOKEN` secret key), so model traffic traverses the rails.
- [x] 1.4 Tightened `ollama/deployment.yaml` NetworkPolicy: `:11434` now admits **only** `app: ai-gateway` (dropped the direct `open-webui`/`nemo-guardrails` allows).
- [x] 1.5 `up.sh` builds `ai-gateway:local`, `kind load`s it, applies the gateway (with an OPA sidecar running `gateway-policy.rego`), then Open WebUI; OTel endpoint wired so `guardrail.blocked` spans export.

## 2. Reconcile docs and lab text

- [x] 2.1 Corrected `lab-infra/ai/README.md`: the component table now shows the real gateway (Deployment: gateway + OPA sidecar, guardrails in-process) instead of nonexistent separate "Deployment" rows; file tree adds `gateway/`; "only the ai-gateway pod reaches Ollama".
- [x] 2.2 Fixed `labs/d3-ai-security.md` step 2 + verification wording: the Ollama policy gates by **podSelector label** `app: ai-gateway`, not ServiceAccounts.
- [x] 2.3 `labs/d5-ai-redteam.md` targets `http://ai-gateway.oss500-apps:8080/v1/chat` — now a real, running endpoint (the `/v1/chat` alias serves it); no lab text change needed.

## 3. Validation

- [x] 3.1 **OPA policy decisions verified with real `opa eval`**: unauthenticated → `allow=false`; authed + sanctioned model → `allow=true`; privileged model without the `ml` group → `allow=false` with the correct deny reason; `ml` user + privileged model → `allow=true`. `opa check` compiles the policy.
- [x] 3.2 `app.py` compiles (`py_compile`); `gateway/deployment.yaml` passes `kubectl apply --dry-run`; `up.sh`/`down.sh` pass `bash -n`; `down.sh` deletes the gateway.
- [ ] 3.3 (host) `cd lab-infra/ai && ./up.sh` on kind: port-forward `svc/ai-gateway`, confirm `401` without a token, a jailbreak refused, a seeded secret redacted by the output rail, and `guardrail.blocked` spans in the collector; confirm Ollama is unreachable except via the gateway.
- [x] 3.4 `npm run lint:links` OK; `npx openspec validate fix-ai-gateway-in-path --strict` passes.

## Note on runtime verification
The auth/rate-limit/OPA/OTel/NetworkPolicy layers are verified statically + by `opa eval`. The NeMo Guardrails rails and the model round-trip need a kind cluster with the `llama3.2:1b` model pulled — flagged (3.3) for host verification. The gateway loads NeMo lazily so the pod is Ready before the model finishes pulling.
