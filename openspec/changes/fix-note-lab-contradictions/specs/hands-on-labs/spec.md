## ADDED Requirements

### Requirement: The Sigma conversion step is completable from course materials
A lab that requires converting a Sigma rule SHALL teach how to discover the right pipeline (`sigma list pipelines`) and name the correct pipeline for the rule's `product`/`service`, and every reference solution SHALL show a pipeline that matches the rule (not a mismatched one).

#### Scenario: Linux/sshd rule uses a matching pipeline
- **WHEN** a learner completes `labs/d4-siem-wazuh.md` Part C converting a `product: linux, service: sshd` rule
- **THEN** the lab teaches `sigma list pipelines`, names the correct opensearch/linux pipeline, and both the lab reference solution and the `siem-incident-response.md` `siem-detect` note example use that pipeline rather than `-p ecs_windows`

### Requirement: The WAF reference configuration loads without error
A lab's WAF reference configuration SHALL load cleanly — no duplicate rule IDs — and where custom `SecRule` authoring is in exam scope the materials SHALL show a minimal `SecRule` example (or explicitly mark it beyond-lab).

#### Scenario: WAF reference loads and SecRule anatomy is shown
- **WHEN** a learner applies the `labs/d2-ingress-waf.md` Part C reference configuration
- **THEN** it uses a single combined `SecAction` (no duplicate `id:900110`) so ModSecurity loads it without a config-load error, and a minimal `SecRule ARGS "@rx …" "id:…,phase:2,deny"` example is provided or the gotcha is marked beyond-lab
