# Lab Catalog

Every skills-outline subsection maps to at least one lab. Each lab names the **SC-500 control it corresponds to** and proves the **open-source equivalent** enforces the same security outcome — its verification step is an observable check (a denied request, a fired alert, a blocked connection), not just "the tool is installed."

Types: **hands-on** = you perform it on the local kind cluster / Compose stack · **walkthrough** = exact steps documented but impractical to fully run on a single laptop host (steps still studied at the same depth, tracker row marked `walkthrough`).

Lab environments live in [`lab-infra/`](../lab-infra/); each has an `up.sh`/`down.sh` and its own README.

## Domain 1 — Identity, access, governance (20–25%)

| Subsection (tracker id) | Lab | Type | OSS components |
|---|---|---|---|
| Identity provider (`d1-idp`) | [d1-keycloak-sso-mfa](d1-keycloak-sso-mfa.md) · [d1-keycloak-conditional-access](d1-keycloak-conditional-access.md) | hands-on | Keycloak |
| Workload identity (`d1-workload-identity`) | [d1-workload-identity](d1-workload-identity.md) | hands-on (SPIFFE section: walkthrough) | K8s ServiceAccounts, OIDC, SPIRE |
| Privileged access (`d1-pam`) | [d1-privileged-access](d1-privileged-access.md) | hands-on (approval flow: walkthrough) | Teleport / Boundary |
| Cluster RBAC (`d1-k8s-rbac`) | [d1-kubernetes-rbac](d1-kubernetes-rbac.md) | hands-on | Kubernetes RBAC, rbac-tool |
| Governance (`d1-governance`) | [d1-governance-policy](d1-governance-policy.md) | hands-on | Kyverno, OPA Gatekeeper, Kubescape |
| Zero-trust access — five models (`d1-ztna`) *(beyond-blueprint)* | [d1-ztna-boundary](d1-ztna-boundary.md) · [d1-ztna-openziti](d1-ztna-openziti.md) · [d1-ztna-pomerium](d1-ztna-pomerium.md) · [d1-ztna-netbird](d1-ztna-netbird.md) | hands-on (all Terraform-automated) | Boundary+Vault, OpenZiti, Pomerium, NetBird (SPIFFE/Teleport ✅ in `d1-workload-identity`/`d1-pam`) |

## Domain 2 — Secrets, data, networking (25–30%)

| Subsection (tracker id) | Lab | Type | OSS components |
|---|---|---|---|
| Secrets management (`d2-secrets`) | [d2-vault-dynamic-secrets](d2-vault-dynamic-secrets.md) · [d2-vault-k8s-injection](d2-vault-k8s-injection.md) | hands-on | HashiCorp Vault |
| Keys & certificates (`d2-keys-certs`) | [d2-cert-manager](d2-cert-manager.md) | hands-on (HSM section: walkthrough) | cert-manager, Vault transit |
| Network segmentation (`d2-network`) | [d2-network-policy](d2-network-policy.md) | hands-on (perimeter firewall: walkthrough) | NetworkPolicy, service mesh |
| Web application firewall (`d2-waf`) | [d2-ingress-waf](d2-ingress-waf.md) | hands-on | ingress-nginx, ModSecurity, OWASP CRS |
| Data protection (`d2-data`) | [d2-data-protection](d2-data-protection.md) | hands-on | etcd encryption, Trivy, Gitleaks |

## Domain 3 — Compute & AI security (20–25%)

| Subsection (tracker id) | Lab | Type | OSS components |
|---|---|---|---|
| Pod security (`d3-podsecurity`) | [d3-pod-security](d3-pod-security.md) | hands-on | Pod Security Admission, Kyverno/Gatekeeper |
| Runtime security (`d3-runtime`) | [d3-runtime-detection](d3-runtime-detection.md) | hands-on | Falco, Tetragon, Falcosidekick |
| Supply chain (`d3-supplychain`) | [d3-supply-chain](d3-supply-chain.md) | hands-on | Trivy, Grype, Harbor, cosign, Syft |
| AI security (`d3-ai`) *(new to SC-500)* | [d3-ai-security](d3-ai-security.md) | hands-on (AI governance: walkthrough) | Ollama, Open WebUI, NeMo Guardrails, OPA |

## Domain 4 — Posture & monitoring (20–25%)

| Subsection (tracker id) | Lab | Type | OSS components |
|---|---|---|---|
| Observability (`d4-observability`) | [d4-observability](d4-observability.md) | hands-on | Prometheus, Grafana, Loki, Tempo, OTel |
| SIEM & IR (`d4-siem`) | [d4-siem-wazuh](d4-siem-wazuh.md) | hands-on | Wazuh, OpenSearch, Sigma |
| Network detection (`d4-network-detection`) | [d4-network-detection](d4-network-detection.md) | hands-on | Suricata, Zeek |
| Vulnerability & posture (`d4-vuln`) | [d4-vuln-posture](d4-vuln-posture.md) | hands-on | Kubescape, kube-bench, Trivy |

## Domain 5 — Prove it: offensive validation (beyond-blueprint)

Red-team the controls built in Domains 1–4 to prove they work: build → name the ATT&CK/ATLAS technique → fire it locally → confirm detection (or document the gap). **Local, disposable targets only.**

| Subsection (tracker id) | Lab | Type | OSS components |
|---|---|---|---|
| AI red-teaming (`d5-ai-redteam`) | [d5-ai-redteam](d5-ai-redteam.md) | hands-on (local target) | garak, PyRIT, Burp/PortSwigger vs the d3-ai gateway |
| Infra attack simulation (`d5-infra-attack`) | [d5-infra-attack-simulation](d5-infra-attack-simulation.md) | hands-on (disposable targets) | Atomic Red Team, Caldera, Stratus vs Falco/Tetragon/Suricata/Wazuh |
| ZTNA authz testing (`d5-ztna-authz`) | [d5-ztna-authz](d5-ztna-authz.md) | hands-on | curl/ssh/nmap bypass attempts vs the D1 brokers |

Attack tooling lives in [`../lab-infra/offense/`](../lab-infra/offense/) and is wired to local targets only.

## Ground rules

1. **Deploy → verify → destroy**: bring up the lab's `lab-infra/` component, perform the steps, prove the control, then `down.sh`. The loop is itself practice for the IaC objective (`gov-iac`).
2. **Prove the control**: a lab isn't done until its verification observable is seen — the firewall denies, the admission webhook rejects, the Falco rule fires, the WAF blocks.
3. **Walkthrough ≠ skip**: walkthrough sections are read at the same depth, then the tracker row is marked `walkthrough` so the review phase knows where hands-on confidence is thinner.
4. **Resource discipline**: bring up only the current lab's component; the heaviest stacks (SIEM, full observability) run alone.
