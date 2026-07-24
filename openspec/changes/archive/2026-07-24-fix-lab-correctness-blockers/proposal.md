## Why

Six per-lab correctness blockers each strand a careful reader at a point where the stated observable cannot be produced from what is shipped. They are distinct from the systemic PSA-namespace issue (`fix-psa-restricted-demo-namespace`) and from the note-vs-lab contradictions (`fix-note-lab-contradictions`); these are places where the lab's infrastructure or environment physically can't yield the result the lab claims.

- **3.8 Mesh authorization principal mismatch** — `labs/d2-network-policy.md` Part B reference uses principal `…/sa/frontend-sa`; the shipped `lab-infra/network/mesh/authorizationpolicy.yaml` uses `…/sa/client`, and the `client` pod in `demo-app.yaml` sets no `serviceAccountName` (runs as `default`), so even the shipped policy denies it — the "authorized call → 200" observable is unreachable on both paths.
- **3.9 Istio default-deny egress starves sidecars of istiod** — with namespace-wide default-deny egress in force (kindnet enforcing, per Part A), injected Envoy sidecars can't reach istiod on `15012` for xDS/cert issuance; no egress allowance to `istio-system` is shipped. Sidecars come up 2/2 but never get certs; STRICT mTLS fails for everything.
- **3.10 WebAuthn passkey lab runs over plain HTTP** — `labs/d1-keycloak-sso-mfa.md` Part C drives passkey registration at `http://keycloak.oss500.local:8080`; a plain-HTTP non-`localhost` origin is not a browser secure context, so `navigator.credentials.create` is unavailable and both the passwordless observable and the RP-ID-mismatch exercise are unreachable.
- **3.11 Cert-issuer lifecycle** — Phase 2 Day 4 ends with `certs/down.sh` (deletes cert-manager + the hand-built `oss500-ca-issuer`); Day 6 ingress-WAF hard-requires `oss500-ca-issuer` but the plan gives Day 6 no certs bring-up block, and `certs/up.sh` ships a differently named `ca-issuer`. Day 6's Certificate sits `Ready=False` forever.
- **3.12 SIEM hands-on spine broken at three points** — (a) the mounted `lab-infra/siem/config/ossec.conf` is a study excerpt (no `<ruleset>`) that replaces the manager's whole config at boot, so no decoders/rules load and no alerts fire; (b) the agent container has no sshd/ssh client and no `NET_ADMIN`, so neither brute-force telemetry nor the `firewall-drop` active-response can occur; (c) the Sigma rule uses deprecated v1 aggregation on a linux/sshd rule with a Windows pipeline.
- **3.13 Provisioned Grafana posture dashboard not shipped** — `labs/d4-observability.md` Part D opens a dashboard "already loaded via the sidecar," but no `grafana_dashboard`-labelled ConfigMap exists and `up.sh` applies none; the metrics→logs→traces drill-down deliverable is undoable.

## What Changes

- **Mesh (3.8)** — add the `client` (or `frontend-sa`) ServiceAccount to `demo-app.yaml`, set `serviceAccountName` on the client pod, and make lab + reference use that one principal.
- **Istio egress (3.9)** — ship and *teach* an `allow-egress-to-istiod` NetworkPolicy (open the L4 path to istiod on `15012`), framed as opening the management-plane path, so the "NetworkPolicy + mesh defense-in-depth" lesson holds.
- **WebAuthn (3.10)** — front Keycloak with TLS for Part C, or port-forward to literal `localhost` with RP ID = `localhost`, and state which.
- **Cert-issuer lifecycle (3.11)** — add a Day 6 certs bring-up block (`certs/up.sh` + re-apply the issuer chain) or retarget the lab to the shipped `ca-issuer`, so the Day 6 Certificate reaches `Ready=True`.
- **SIEM (3.12)** — ship a complete `ossec.conf` (with `<ruleset>`), add `cap_add: [NET_ADMIN]` and a crafted-log or sshd-sidecar path with exact file/line format, and simplify the Sigma rule to a `-p`-less keyword selection; verify one alert end-to-end.
- **Grafana dashboard (3.13)** — commit the four-panel posture dashboard ConfigMap and apply it in `up.sh`, or reword Part D to "build these panels in Explore."

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `lab-infrastructure` — adds requirements that shipped infra actually provisions what labs depend on: the mesh ServiceAccount/principal, the istiod egress allowance, a complete SIEM manager config with a working telemetry+active-response path, the cert-issuer chain the dependent lab needs, and the provisioned Grafana dashboard.
- `hands-on-labs` — adds a requirement that a lab's environment can physically produce its stated observable (secure-context WebAuthn, an end-to-end SIEM alert, a mesh authorized-call 200, a Ready certificate, a loaded dashboard) before the lab is marked valid.

## Impact

- Affected specs: `lab-infrastructure` (ADDED requirements), `hands-on-labs` (one ADDED requirement).
- Affected content (at implementation time): `lab-infra/network/mesh/authorizationpolicy.yaml` + `demo-app.yaml`, an `allow-egress-to-istiod` policy, `labs/d1-keycloak-sso-mfa.md` (+ TLS/localhost front), `lab-infra/certs/*` + Phase 2 Day 6 plan, `lab-infra/siem/config/ossec.conf` + `agent-compose.yml` + `labs/d4-siem-wazuh.md`, the Grafana dashboard ConfigMap + `lab-infra/observability/up.sh`.
- Unblocks the observables in `labs/d2-network-policy.md` Part B, the Istio STRICT-mTLS lab, `labs/d1-keycloak-sso-mfa.md` Part C, the Day 6 ingress-WAF Certificate, the SIEM `siem-*` stages, and `labs/d4-observability.md` Part D.
