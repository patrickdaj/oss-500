## ADDED Requirements

### Requirement: The AI lab deploys enforcing guardrails and gateway in the request path
The `lab-infra/ai/` component SHALL deploy an AI gateway and NeMo Guardrails as running workloads that sit in the request path in front of Ollama, so that every prove-it observable in the Domain 3 AI-security lab and the Domain 5 AI red-team lab is reproducible from `up.sh` as shipped. Guardrail and policy configuration SHALL be loaded by a running workload, not left as inert ConfigMaps, and Ollama SHALL be reachable only through the gateway.

#### Scenario: The gateway is a real, reachable workload
- **WHEN** a learner runs `lab-infra/ai/up.sh` and issues a request to the gateway Service on its documented port
- **THEN** an `ai-gateway` Deployment and Service are running in `oss500-apps` and answer the request (rather than returning a name-resolution error for a Service that does not exist)

#### Scenario: Authentication and rate limiting are enforced
- **WHEN** a learner calls the gateway with no valid token, and separately floods it past its rate limit
- **THEN** the gateway returns `401` for the unauthenticated call and `429` for the rate-limited call

#### Scenario: Input and output rails execute in-path
- **WHEN** a learner sends a jailbreak prompt, and separately asks the model to repeat a seeded secret
- **THEN** the input rail refuses the jailbreak, the output rail redacts the secret, and a `guardrail.blocked` OpenTelemetry span is emitted — while a benign prompt is answered normally

#### Scenario: Ollama is only reachable through the gateway
- **WHEN** a pod that is not the gateway or guardrails attempts to reach Ollama on `:11434`
- **THEN** the Ollama NetworkPolicy denies it, so the gateway is the only legitimate path to the model

#### Scenario: The Domain 5 AI red-team target stands up
- **WHEN** the Domain 5 AI red-team lab fires garak at the guardrailed gateway
- **THEN** the gateway target is running and reachable, so the defended-vs-baseline comparison can be performed rather than attacking a target that was never deployed
