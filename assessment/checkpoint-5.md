# Checkpoint 5 — Prove it: offensive validation

Generated from `assessment/data/quiz-5.yaml` — study-hub runs this interactively (Tests page). Pass bar: 80%. 19 questions.

### 1. You built a Falco rule in Domain 3 and want to treat it the purple-team way. What is the correct four-step method, in order?

- A. Fire a random exploit, see what breaks, then write a rule to match it
- B. Build the control, name the specific ATT&CK/ATLAS technique, fire it locally, confirm the defense holds (alert fires / request denied)
- C. Scan the internet for the technique, run it against a live target, then report the CVE
- D. Deploy the control, mark it done, and move on — deployment is the proof

<details><summary>Answer</summary>

**B** — The method is build → name the technique → fire it (locally) → confirm the defense holds. Naming the exact ATT&CK/ATLAS technique in step 2 is what makes the test repeatable and the report legible; a control you have never attacked is a hypothesis, not a defense.

[Documentation](https://attack.mitre.org/) · objectives: `pt-method`

</details>

### 2. You fire T1611 (escape to host) at your local cluster and Falco does NOT alert. How should this outcome be treated under the domain's honesty discipline?

- A. As a lab failure to hide or retry until it passes
- B. As a successful, publishable finding — document the coverage gap honestly, then optionally write the rule that closes it and re-fire
- C. As proof the technique is broken and should be discarded
- D. As irrelevant, since the control was already deployed

<details><summary>Answer</summary>

**B** — "The alert did not fire" is a real result, not a failure: it surfaces a genuine gap (a missing rule, a mis-scoped policy) that would otherwise stay hidden. Honesty over spectacle — record executed vs. directions and report the gap rather than fabricating a clean pass.

[Documentation](https://d3fend.mitre.org/) · objectives: `pt-method`

</details>

### 3. Which single rule of engagement makes this whole domain safe to run on a laptop, and matters legally as well as technically?

- A. Always run attacks with root so they behave realistically
- B. Target only the local kind/Compose stack you built — never an external host or shared infrastructure, ever
- C. Only fire techniques that you are sure will be blocked
- D. Run every attack through a VPN to a cloud target

<details><summary>Answer</summary>

**B** — Local-only is non-negotiable: every attack targets the local stack, wired to 127.0.0.1/in-cluster targets by design. Firing techniques at hosts you don't own is both unsafe and unlawful; teardown of the attack tooling is part of the lab.

[Documentation](https://attack.mitre.org/) · objectives: `pt-method`

</details>

### 4. You run a garak jailbreak probe against the local NeMo-Guardrails gateway and garak reports the probe as "defended." What have you actually proven, and how should it be recorded?

- A. That garak is broken, since a real jailbreak always gets through
- B. That the input rail blocked the attack — record it against its OWASP LLM id (LLM01) and ATLAS technique (AML.T0051) so the pass is reproducible and legible
- C. That the model has no guardrail and is safe by default
- D. Nothing, because only a passing probe is worth recording

<details><summary>Answer</summary>

**B** — A "defended" result means the NeMo input/jailbreak rail caught the probe. The value is mapping it to LLM01 Prompt Injection ↔ AML.T0051 so the test is repeatable and reportable — a jailbreak isn't "it said a bad thing," it's a named technique against a named rail.

[Documentation](https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/) · objectives: `av-ai-garak`

</details>

### 5. A garak probe PASSES — the jailbreak gets through the gateway. Under the four-step method, what is the correct next action?

- A. Delete the probe so the report stays clean
- B. Record it as the finding against its OWASP LLM / ATLAS id and name the specific NeMo rail that should have caught it
- C. Conclude the whole gateway is worthless and remove it
- D. Re-run until the probe happens to be blocked, then report a pass

<details><summary>Answer</summary>

**B** — Where a probe passes (gets through), that IS the finding: record it against the OWASP/ATLAS id and note the missing rail. Naming the rail that should have caught it turns a vague "it jailbroke" into an actionable, remediable gap.

[Documentation](https://atlas.mitre.org/) · objectives: `av-ai-garak`

</details>

### 6. When reporting the NeMo guardrail's effectiveness, why is the migrated "garak against undefended Ollama" run kept as a baseline?

- A. Because the undefended run is the only trustworthy result
- B. Because it measures the delta the guardrail adds — undefended vs. NeMo-fronted — so the rail's value is quantified, not asserted
- C. Because you should always ship models with no guardrail
- D. Because garak cannot run against a guarded model

<details><summary>Answer</summary>

**B** — The undefended-Ollama baseline is the control group: comparing it to the NeMo-fronted gateway makes the guardrail's effect measurable rather than a claim. That prior run is executed evidence; anything you haven't run yourself is labeled directions.

[Documentation](https://github.com/NVIDIA/garak) · objectives: `av-ai-garak`

</details>

### 7. garak fires dozens of single-shot probes automatically. What does PyRIT add that garak's probe library does not cover?

- A. It blocks attacks inline like an IPS
- B. Multi-turn attack orchestration and scorers — scripted, stateful attacks that build across a conversation
- C. It replaces the need for any guardrail
- D. It only tests the HTTP surface, not the model

<details><summary>Answer</summary>

**B** — PyRIT is Microsoft's automated risk-identification toolkit: multi-turn orchestration and scorers let you script attacks that develop over several turns — a different class from garak's automated single-probe sweep. Use both.

[Documentation](https://github.com/Azure/PyRIT) · objectives: `av-ai-pyrit`

</details>

### 8. Why red-team the gateway with BOTH Burp/PortSwigger and garak — what does each find that the other misses?

- A. They find the same bugs; running both is redundant
- B. Burp tests the HTTP surface (auth, IDOR on the API in front of the model); garak tests the model itself (jailbreak, injection, leakage) — different bug classes
- C. Burp tests the model and garak tests the network
- D. Only garak matters; the HTTP layer is out of scope

<details><summary>Answer</summary>

**B** — The web layer and the model are distinct attack surfaces. Burp finds auth/IDOR bugs on the API fronting the model; garak finds prompt-injection, jailbreak, and data-leakage bugs in the model's behavior. A bug in one is invisible to the other.

[Documentation](https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/) · objectives: `av-ai-pyrit`, `av-ai-garak`

</details>

### 9. You want a precise "did T1611 (escape to host) alert?" check against your runtime detection stack. Which tool fits, and which detector should fire?

- A. Caldera; the Suricata scan signature
- B. Atomic Red Team (one technique, one command); Falco's container-drift/breakout rule (D3-CI Container Isolation)
- C. Stratus; the Wazuh auth-success correlation
- D. garak; the NeMo output rail

<details><summary>Answer</summary>

**B** — Atomic Red Team runs one technique as one command — ideal for a precise "did T1611 alert?" test. The container-breakout attempt should trip Falco's drift/breakout rule (or Tetragon), implementing D3FEND D3-CI Container Isolation. Suricata/Wazuh cover network/auth, not container escape.

[Documentation](https://github.com/redcanaryco/atomic-red-team) · objectives: `av-atomic`

</details>

### 10. A technique needs root/--privileged to run. Under the domain's honesty & safety rules, where do you fire it?

- A. On your daily-driver host so results are realistic
- B. In a disposable pod/VM you destroy afterward — never your daily driver — and record executed vs. directions
- C. Against a colleague's cluster for a second opinion
- D. Nowhere; privileged techniques can never be tested

<details><summary>Answer</summary>

**B** — Privileged/root techniques run in a throwaway pod or VM that comes down after, keeping the blast radius contained. Record what was executed vs. directions — "T1611 fired, Falco did not alert — rule gap in X" is a good, publishable result.

[Documentation](https://github.com/redcanaryco/atomic-red-team) · objectives: `av-atomic`

</details>

### 11. You need to exercise a multi-step adversary operation (a chain of abilities) to test whether your detection covers a whole attack path, not one atom. Which tool is designed for that?

- A. Atomic Red Team, because atoms chain themselves
- B. Caldera — autonomous adversary emulation that runs multi-step ability chains
- C. garak, via its probe sequencing
- D. kube-bench, via its scored checks

<details><summary>Answer</summary>

**B** — Caldera does autonomous adversary emulation: multi-step operations that chain abilities, giving ability-to-alert coverage across a path. Atomic Red Team is the single-technique precision tool; Caldera is the chained-operation tool.

[Documentation](https://github.com/mitre/caldera) · objectives: `av-caldera-stratus`

</details>

### 12. You want to exercise cloud/k8s-native TTPs against your detection stack, but you have no cloud account and no cloud bill to spend. Which tool solves this?

- A. Caldera, by emulating a cloud provider
- B. Stratus Red Team — cloud-native TTPs as local detonations (`stratus detonate`), so cloud techniques run without a cloud account
- C. Atomic Red Team, which only covers Windows
- D. Suricata in IPS mode

<details><summary>Answer</summary>

**B** — Stratus Red Team detonates cloud-native TTPs locally, specifically so you can exercise cloud/k8s technique coverage without a cloud account or bill. Atomic is per-technique atoms; Caldera is chained emulation; Stratus is the cloud-TTP detonator.

[Documentation](https://github.com/DataDog/stratus-red-team) · objectives: `av-caldera-stratus`

</details>

### 13. You fire an ATT&CK technique and NOTHING alerts in Falco, Suricata, or Wazuh. Walk the correct next steps.

- A. Assume the tool misfired and move on
- B. Treat the silence as the finding: document the coverage gap, write the Sigma/Falco rule that closes it, then re-fire to confirm the new rule catches it
- C. Lower the detection thresholds until something fires
- D. Delete the technique from your test set

<details><summary>Answer</summary>

**B** — No alert = the finding. Document the coverage gap, optionally author the Sigma/Falco rule that closes it, then re-fire to prove the rule now catches the technique. This is continuous validation — Detect/Respond exercised, not assumed.

[Documentation](https://d3fend.mitre.org/) · objectives: `av-caldera-stratus`, `av-atomic`

</details>

### 14. ZTNA validation differs from every other domain's testing. What is the property you are actually proving, and why does it need a negative test?

- A. That the broker is fast — measured by a load test
- B. That the control REFUSES what it should — an over-granted policy silently over-permits without crashing, so only attempting unauthorized access surfaces it
- C. That the broker allows all authenticated users in
- D. That the network route to the host is always open

<details><summary>Answer</summary>

**B** — Every other domain proves a control does something; ZTNA proves a control refuses something. The dangerous failure — an over-broad Boundary role, a wrong-domain Pomerium policy, a bidirectional NetBird rule — doesn't crash, it quietly over-grants. Only the negative test (attempt access you shouldn't have) catches it.

[Documentation](https://csrc.nist.gov/pubs/sp/800/207/final) · objectives: `av-ztna-authz`

</details>

### 15. Testing the OpenZiti model, from an un-enrolled machine you try to dial the service and port-scan the underlay. What result proves the model holds?

- A. The dial succeeds but is logged for review
- B. The dial is refused and the underlay shows no listening port — there is nothing to hit without a valid enrolled identity
- C. The port scan finds an open port you then authenticate to
- D. The service responds with a 200 to prove availability

<details><summary>Answer</summary>

**B** — OpenZiti's proof is a refused dial from an un-enrolled identity AND an underlay with no listening port — the service is dark to anything without a valid `#client` identity. Mesh reachability is never standing network access.

[Documentation](https://csrc.nist.gov/pubs/sp/800/207/final) · objectives: `av-ztna-authz`

</details>

### 16. Against the Pomerium model you reach the route unauthenticated, then as a valid user OUTSIDE the policy domain, then try to reach `internal-app` directly. What is the expected sequence of results?

- A. 200, 200, 200 — Pomerium logs but allows
- B. 302→IdP (unauthenticated), then 403 (authenticated but out of policy), and no direct ingress to the app at all
- C. 403, 302, 200
- D. The app answers directly because it has its own ingress

<details><summary>Answer</summary>

**B** — Unauthenticated access is redirected to the IdP (302); a valid user outside the policy domain is authenticated but denied (403) — authentication is not authorization; and `internal-app` has no ingress of its own, so the broker is the only path. That's the PEP enforcing per-request.

[Documentation](https://csrc.nist.gov/pubs/sp/800/207/final) · objectives: `av-ztna-authz`

</details>

### 17. You want a Boundary session-denied event to be observable, closing the attack→deny→alert loop the way NIST 800-207 and CISA ZTMM intend. How?

- A. Nothing — a denial is self-evident and needs no logging
- B. Feed the broker's denial log into the Domain 4 Wazuh SIEM so the refusal is detected and alertable
- C. Disable logging so denials don't create noise
- D. Route the denial to Prometheus as a metric only

<details><summary>Answer</summary>

**B** — Confirming the denial is step 4; making it observable closes the loop — forward the broker's session-denied event to Wazuh (D4) so attack → deny → alert is a detected chain. "Continually verify" (CISA ZTMM) means the refusal is not just enforced but seen.

[Documentation](https://www.cisa.gov/zero-trust-maturity-model) · objectives: `av-ztna-authz`

</details>

### 18. Why does the domain insist you NAME the exact ATT&CK technique and its D3FEND countermeasure for each infra test, rather than just "running an attack"?

- A. To make the report longer
- B. Because naming the technique makes the test repeatable and maps offense to the exact defensive countermeasure (ATT&CK ↔ D3FEND), producing a legible, re-runnable coverage claim
- C. Because ATT&CK ids are required by law
- D. Because unnamed attacks are automatically blocked

<details><summary>Answer</summary>

**B** — Naming the technique (step 2) is what turns a one-off into a repeatable test and lets you pair it with the precise D3FEND countermeasure that should catch it. The offense↔defense mapping (ATT&CK ↔ D3FEND) is the legible evidence a hiring manager and a re-run both need.

[Documentation](https://d3fend.mitre.org/) · objectives: `av-atomic`, `pt-method`

</details>

### 19. Under the AI RMF governance frame, which two functions does the AI red-teaming track exercise?

- A. Govern and Map only
- B. Measure (you are measuring the guardrail's risk) and Manage (you remediate the gaps you find)
- C. Detect and Respond
- D. Identify and Recover

<details><summary>Answer</summary>

**B** — NIST AI RMF Measure = quantifying the risk (running garak/PyRIT and recording pass/fail against OWASP-LLM/ATLAS ids); Manage = remediating the gaps (adding the missing rail). The track is literally those two functions in practice.

[Documentation](https://www.nist.gov/itl/ai-risk-management-framework) · objectives: `av-ai-pyrit`

</details>
