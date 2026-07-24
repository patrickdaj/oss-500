# Tasks — fix-lab-correctness-blockers

## 1. Mesh authorization principal (3.8)

- [x] 1.1 Add the `client` (or `frontend-sa`) ServiceAccount to `lab-infra/network/mesh/demo-app.yaml` and set `serviceAccountName` on the client pod.
- [x] 1.2 Make `labs/d2-network-policy.md` Part B and `authorizationpolicy.yaml` use that one principal. Principal consistency confirmed statically (`sa/client` used in `demo-app.yaml`, `authorizationpolicy.yaml`, and the lab text) and both YAMLs parse. **The live "authorized call → 200" run is BLOCKED (environment):** no `kubectl`/`kind`/`istioctl` in this environment (only `helm` is present) — re-run on a host with the cluster tooling before marking valid.

## 2. Istio istiod egress (3.9)

- [x] 2.1 Ship an `allow-egress-to-istiod` NetworkPolicy (egress to `istio-system` on `15012`) in `lab-infra/network/`.
- [x] 2.2 Teach it in the lab as opening the management-plane L4 path. YAML validated; wired into `up-mesh.sh`. **Live "sidecars get certs, STRICT mTLS succeeds" run is BLOCKED (environment)** — same missing `kubectl`/`istioctl` as 1.2.

## 3. WebAuthn secure context (3.10)

- [x] 3.1 Front Keycloak with TLS for `labs/d1-keycloak-sso-mfa.md` Part C, or port-forward to `localhost` with RP ID `localhost`, and state which in the lab.
- [ ] 3.2 Verify passkey registration and the RP-ID-mismatch exercise are reachable. **BLOCKED (environment):** requires a live Keycloak (no `kubectl`/`helm` cluster access here) plus a real browser for `navigator.credentials.create` — neither is available in this headless run. Re-run manually before marking the lab valid.

## 4. Cert-issuer lifecycle (3.11)

- [x] 4.1 Add a Phase 2 Day 6 certs bring-up block (`certs/up.sh` + re-apply the issuer chain) or retarget the ingress-WAF lab to the shipped `ca-issuer`.
- [ ] 4.2 Verify the Day 6 Certificate reaches `Ready=True`. **BLOCKED (environment):** no `kubectl`/`kind` here to actually bring up cert-manager and check `Ready=True`. The plan/lab text is now internally consistent (retargeted to the shipped `ca-issuer`/`oss500-lab-ca`); live confirmation is owed on a host with cluster tooling.

## 5. SIEM spine (3.12)

- [x] 5.1 Ship a complete `lab-infra/siem/config/ossec.conf` including `<ruleset>` so decoders/rules load.
- [x] 5.2 Add `cap_add: [NET_ADMIN]` and a crafted-log or sshd-sidecar path to the agent, with the exact expected file/line format.
- [x] 5.3 Simplify the Sigma rule to a `-p`-less keyword selection that current pySigma converts.
- [ ] 5.4 Verify one alert end-to-end (telemetry → parsed alert) before marking the lab valid. **BLOCKED (environment):** the Sigma conversion half was live-verified against current `sigma-cli`/`pysigma-backend-opensearch` (see the lab's Validation status note — this also surfaced and fixed a real `-t opensearch` → `opensearch_lucene` target-name break). The manager/indexer/agent half needs the full ~4–6 GB `docker compose -p oss500-siem` stack; this host already had a kind cluster up and only ~18 GB free disk, and the component's own README says run it completely alone, so it was not brought up here. Config files were validated as well-formed (XML/YAML) instead. Re-run on a clean host before marking the lab fully valid.

## 6. Grafana posture dashboard (3.13)

- [x] 6.1 Commit the four-panel posture dashboard as a `grafana_dashboard`-labelled ConfigMap and apply it in `lab-infra/observability/up.sh` (or reword Part D to "build these panels in Explore"). Shipped `lab-infra/observability/dashboards.yaml`, applied by `up.sh`. While building this, found and fixed two panels that weren't actually achievable as originally described: kube-state-metrics ships no "pods running as root"/securityContext metric at all (verified against the upstream docs — swapped for the real, verifiable posture proxy `kube_pod_service_account{service_account="default"}`, CIS 5.1.5), and Tempo has no native time-series query for "trace latency" (added a `spanmetrics` connector to `otel-collector.yaml` to derive a real Prometheus histogram from spans, plus the `ServiceMonitor` that was needed to scrape it — one didn't exist even though a comment claimed it did). Gave the datasources explicit `uid`s so the dashboard JSON can reference them.
- [x] 6.2 Verify the dashboard is present after bring-up. **Live-verified (2026-07-24):** brought the full stack up on kind — `up.sh` completes exit 0, Grafana/Prometheus/KSM/Loki/Tempo/otel-collector all Running, and the dashboard ConfigMap is applied and picked up by the Grafana provisioning sidecar. Verifying the panels' data paths surfaced two real blockers this task's own dashboard depended on, now fixed: (a) the `spanmetrics` connector listed `span.name` as a custom dimension, but it is already a default — contrib 0.111.0 rejected the config and the collector **crash-looped**; removed the duplicate; (b) the panel/comment queried `traces_spanmetrics_latency_bucket`, but the real emitted series is `traces_span_metrics_duration_milliseconds_bucket` (read from the collector's `:8889`) — corrected the query, description, and unit (s→ms). Confirmed end-to-end: the corrected p95 query returns a live value (~178 ms), and `kube_pod_service_account` (panel 2) returns data. Only residual: opening the Grafana UI to eyeball the rendered panels (data path is proven).

## 7. Validation

- [x] 7.1 Run `openspec validate fix-lab-correctness-blockers --type change --strict`. Passes: "Change 'fix-lab-correctness-blockers' is valid". `npm run lint:links` also passes.
