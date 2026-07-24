## ADDED Requirements

### Requirement: Shipped mesh policy and demo app agree on one workload principal
The shipped Istio authorization policy and demo application SHALL use a single, consistent workload principal, and the client pod SHALL run under a ServiceAccount that the "allow" policy actually permits, so an authorized call produces the intended 200.

#### Scenario: Client pod runs as the permitted principal
- **WHEN** a reader inspects `lab-infra/network/mesh/authorizationpolicy.yaml` and `demo-app.yaml`
- **THEN** the client pod sets `serviceAccountName` to the same ServiceAccount named in the "allow" policy (and that ServiceAccount exists), so the authorized call is permitted rather than denied as `default`

### Requirement: Mesh control-plane egress is allowed under default-deny
When a lab enforces namespace-wide default-deny egress alongside an injected Istio sidecar, `lab-infra/` SHALL ship a NetworkPolicy that allows egress to istiod (e.g. `istio-system` on `15012`) so sidecars can complete xDS and certificate issuance and STRICT mTLS can succeed.

#### Scenario: Sidecars reach istiod for certs
- **WHEN** the mesh lab is brought up with default-deny egress in force
- **THEN** an `allow-egress-to-istiod` policy permits the sidecars to reach istiod on `15012`, the sidecars obtain certificates, and STRICT mTLS calls succeed instead of failing silently

### Requirement: SIEM manager ships a complete config with a working telemetry and response path
`lab-infra/siem/` SHALL mount a complete Wazuh manager configuration (including `<ruleset>` so decoders and rules load), and SHALL provide the agent with the capability and tooling to generate the lab's telemetry and active response — a crafted-log or sshd path producing the exact expected file/line format and `cap_add: [NET_ADMIN]` for the `firewall-drop` response.

#### Scenario: Manager loads rules and the brute-force alert fires
- **WHEN** the SIEM stack is brought up and the documented brute-force telemetry is generated on the agent
- **THEN** the manager has loaded its decoders/rules, rule 5710 fires and 100100 correlates, and the `firewall-drop` active-response can run because the agent has `NET_ADMIN`

### Requirement: Dependent cert issuer is available when a lab requires it
When a lab hard-requires a specific cert-manager issuer, `lab-infra/` and the plan SHALL ensure that issuer exists at that point — either by a bring-up block that re-applies the issuer chain (matching the name the lab expects) or by the lab targeting the issuer that `certs/up.sh` actually ships.

#### Scenario: Day 6 ingress-WAF Certificate reaches Ready
- **WHEN** the Phase 2 Day 6 ingress-WAF lab requests its Certificate
- **THEN** the issuer it references exists (the issuer chain was re-applied or the lab targets the shipped issuer name) and the Certificate reaches `Ready=True` rather than `Ready=False` forever

### Requirement: Provisioned dashboards are actually shipped and applied
When a lab opens a Grafana dashboard described as "already loaded," `lab-infra/` SHALL commit the dashboard as a `grafana_dashboard`-labelled ConfigMap and apply it in the component's `up.sh`, so the sidecar loads it.

#### Scenario: Posture dashboard is present after bring-up
- **WHEN** the observability stack is brought up and the learner opens Grafana for the D4 observability Part D drill-down
- **THEN** the four-panel posture dashboard is present (its ConfigMap was committed and applied), rather than absent because only the sidecar was enabled
