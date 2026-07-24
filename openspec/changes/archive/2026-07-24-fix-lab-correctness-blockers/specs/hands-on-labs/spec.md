## ADDED Requirements

### Requirement: A lab's environment can physically produce its stated observable
Before a lab is marked valid, its environment SHALL be able to produce the observable the lab claims. In particular, a lab exercising a browser security-context API SHALL run in a secure context, and every lab with a positive/observable check SHALL have that check verified end-to-end at least once.

#### Scenario: WebAuthn runs in a secure context
- **WHEN** the D1 Keycloak SSO/MFA Part C passkey exercise is run
- **THEN** the origin is a browser secure context (Keycloak fronted with TLS, or port-forwarded to literal `localhost` with RP ID `localhost`, and the lab states which), so `navigator.credentials.create` is available and the passwordless and RP-ID-mismatch observables are reachable

#### Scenario: One SIEM alert is verified end-to-end
- **WHEN** the SIEM lab is validated
- **THEN** at least one alert is confirmed from generated telemetry through to a parsed alert before the lab is marked valid, rather than the stages producing zero alerts with zero errors

#### Scenario: Mesh authorized call returns 200
- **WHEN** the D2 network-policy Part B authorized call is made using the single agreed principal
- **THEN** it returns 200, confirming the "authorized call → 200" observable is reachable on both the lab and reference paths
