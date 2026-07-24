# Tasks — fix-lab-correctness-blockers

## 1. Mesh authorization principal (3.8)

- [ ] 1.1 Add the `client` (or `frontend-sa`) ServiceAccount to `lab-infra/network/mesh/demo-app.yaml` and set `serviceAccountName` on the client pod.
- [ ] 1.2 Make `labs/d2-network-policy.md` Part B and `authorizationpolicy.yaml` use that one principal; verify the authorized call returns 200.

## 2. Istio istiod egress (3.9)

- [ ] 2.1 Ship an `allow-egress-to-istiod` NetworkPolicy (egress to `istio-system` on `15012`) in `lab-infra/network/`.
- [ ] 2.2 Teach it in the lab as opening the management-plane L4 path; verify sidecars get certs and STRICT mTLS succeeds.

## 3. WebAuthn secure context (3.10)

- [ ] 3.1 Front Keycloak with TLS for `labs/d1-keycloak-sso-mfa.md` Part C, or port-forward to `localhost` with RP ID `localhost`, and state which in the lab.
- [ ] 3.2 Verify passkey registration and the RP-ID-mismatch exercise are reachable.

## 4. Cert-issuer lifecycle (3.11)

- [ ] 4.1 Add a Phase 2 Day 6 certs bring-up block (`certs/up.sh` + re-apply the issuer chain) or retarget the ingress-WAF lab to the shipped `ca-issuer`.
- [ ] 4.2 Verify the Day 6 Certificate reaches `Ready=True`.

## 5. SIEM spine (3.12)

- [ ] 5.1 Ship a complete `lab-infra/siem/config/ossec.conf` including `<ruleset>` so decoders/rules load.
- [ ] 5.2 Add `cap_add: [NET_ADMIN]` and a crafted-log or sshd-sidecar path to the agent, with the exact expected file/line format.
- [ ] 5.3 Simplify the Sigma rule to a `-p`-less keyword selection that current pySigma converts.
- [ ] 5.4 Verify one alert end-to-end (telemetry → parsed alert) before marking the lab valid.

## 6. Grafana posture dashboard (3.13)

- [ ] 6.1 Commit the four-panel posture dashboard as a `grafana_dashboard`-labelled ConfigMap and apply it in `lab-infra/observability/up.sh` (or reword Part D to "build these panels in Explore").
- [ ] 6.2 Verify the dashboard is present after bring-up.

## 7. Validation

- [ ] 7.1 Run `openspec validate fix-lab-correctness-blockers --type change --strict`.
