# OSS-500 Objective Tracker

Generated from `assessment/data/tracker.yaml` (SC-500 study guide 2026-04-26) — edit the YAML, then run `npm run gen:md`. Live progress state belongs to the study-hub app; this view is the static coverage map. Each objective maps an SC-500 control to its open-source equivalent.

## Manage identity, access, and governance (20-25%)

### Secure access to resources by using an identity provider (Keycloak)

Notes: `domains/1-identity-governance/identity-provider.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `kc-deploy` | Deploy an OIDC/SAML identity provider and model realms, users, and groups (Entra ID equivalent) | Keycloak | Microsoft Entra ID | hands-on |  |  |  |
| `kc-mfa` | Configure authentication methods, including MFA, OTP, and WebAuthn passwordless | Keycloak authentication flows | Entra authentication methods / MFA | hands-on |  |  |  |
| `kc-ca` | Implement conditional access via authentication flows and authorization policies | Keycloak Authorization Services | Conditional Access | hands-on |  |  |  |
| `kc-clients` | Configure identity for applications: OIDC clients, service accounts, and scopes | Keycloak clients | Enterprise apps / app registrations | hands-on |  |  |  |
| `kc-federation` | Configure identity federation and brokering across SAML/OIDC providers | Keycloak identity brokering | Entra external identities / federation | hands-on |  |  |  |
| `kc-consent` | Manage OAuth scopes, client scopes, and consent | Keycloak client scopes / consent | OAuth permission grants and consent | hands-on |  |  |  |

### Implement identity for workloads (managed-identity equivalent)

Notes: `domains/1-identity-governance/workload-identity.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `wi-sa` | Configure Kubernetes ServiceAccounts and bound projected tokens for workloads | Kubernetes ServiceAccounts | Managed identities | hands-on |  |  |  |
| `wi-oidc` | Federate workload identity to secret/cloud systems via the cluster OIDC issuer | Kubernetes workload identity / OIDC | Workload identity federation | hands-on |  |  |  |
| `wi-spiffe` | Explain SPIFFE/SPIRE workload identity and mTLS-based service identity | SPIFFE/SPIRE | Managed identities for services | walkthrough |  |  |  |

### Implement privileged access management (PIM equivalent)

Notes: `domains/1-identity-governance/privileged-access.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `pam-jit` | Implement just-in-time privileged access with short-lived credentials | Teleport / Boundary | Privileged Identity Management (PIM) | hands-on |  |  |  |
| `pam-session` | Configure session recording and audit for privileged sessions | Teleport session recording | PIM audit / access reviews | hands-on |  |  |  |
| `pam-approval` | Require approval workflows and role escalation for privileged roles | Teleport access requests | PIM approval / eligible assignments | walkthrough |  |  |  |

### Implement role-based access control on the cluster

Notes: `domains/1-identity-governance/kubernetes-rbac.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `rbac-roles` | Create Roles/ClusterRoles and bindings scoped to subjects and namespaces | Kubernetes RBAC | Azure RBAC | hands-on |  |  |  |
| `rbac-least` | Apply least-privilege and separate duties across subjects | Kubernetes RBAC | Least-privilege / RBAC | hands-on |  |  |  |
| `rbac-audit` | Audit RBAC to find over-permissioned subjects and risky bindings | rbac-tool / kubectl-who-can | Access reviews / entitlement management | hands-on |  |  |  |

### Implement governance to enforce security and compliance

Notes: `domains/1-identity-governance/governance.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `gov-gatekeeper` | Enforce organizational policy with OPA Gatekeeper constraints | OPA Gatekeeper | Azure Policy | hands-on |  |  |  |
| `gov-kyverno` | Enforce and mutate resources with Kyverno policies | Kyverno | Azure Policy for AKS | hands-on |  |  |  |
| `gov-compliance` | Evaluate compliance against frameworks and baselines | Kubescape compliance frameworks | Defender secure score / regulatory compliance | hands-on |  |  |  |
| `gov-iac` | Implement and configure security controls by using infrastructure as code | Helm / Kubernetes manifests | Security controls via IaC | hands-on |  |  |  |

## Secure secrets, data, and networking (25-30%)

### Secure secrets and keys by using a secrets manager (Key Vault equivalent)

Notes: `domains/2-secrets-data-networking/secrets-management.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `vault-deploy` | Deploy a secrets manager and understand seal/unseal and storage backends | HashiCorp Vault | Azure Key Vault | hands-on |  |  |  |
| `vault-access` | Configure access with auth methods and policies | Vault auth methods / policies | Key Vault access model (RBAC) | hands-on |  |  |  |
| `vault-dynamic` | Issue dynamic, short-lived secrets with leases and revocation | Vault dynamic secrets | Managed credentials / rotation | hands-on |  |  |  |
| `vault-rotation` | Configure secret rotation for static and dynamic credentials | Vault rotation | Key Vault secret rotation | hands-on |  |  |  |
| `vault-k8s` | Deliver secrets to workloads via the Vault agent injector or Secrets Store CSI | Vault Agent / CSI | Key Vault + workload identity | hands-on |  |  |  |
| `vault-audit` | Enable audit devices and monitor secret access | Vault audit devices | Key Vault diagnostics / Defender for Key Vault | hands-on |  |  |  |

### Manage encryption keys and certificate lifecycle

Notes: `domains/2-secrets-data-networking/keys-and-certificates.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `key-transit` | Provide encryption-as-a-service and manage encryption keys | Vault transit engine | Key Vault keys / encryption | hands-on |  |  |  |
| `key-hsm` | Integrate an HSM as a root of trust for key material | Vault HSM / PKCS#11 | Managed HSM | walkthrough |  |  |  |
| `cert-issuer` | Automate certificate issuance with cluster issuers and ACME | cert-manager | Key Vault certificates | hands-on |  |  |  |
| `cert-lifecycle` | Manage certificate renewal, rotation, and revocation | cert-manager | Certificate lifecycle management | hands-on |  |  |  |

### Implement network segmentation and zero-trust connectivity

Notes: `domains/2-secrets-data-networking/network-security.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `net-policy` | Segment east-west traffic with default-deny NetworkPolicies | Kubernetes NetworkPolicy | NSGs / segmentation | hands-on |  |  |  |
| `net-mesh` | Enforce mTLS and identity-aware east-west controls with a service mesh | Istio / Linkerd | Private Link / zero-trust networking | hands-on |  |  |  |
| `net-ingress` | Secure ingress with TLS termination and authenticated access | ingress-nginx + cert-manager | Secure ingress / App Gateway | hands-on |  |  |  |
| `net-firewall` | Apply perimeter firewall and segmentation concepts for the host/edge | OPNsense / pfSense / nftables | Azure Firewall | walkthrough |  |  |  |

### Protect web workloads with a web application firewall

Notes: `domains/2-secrets-data-networking/web-application-firewall.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `waf-deploy` | Deploy a WAF in front of a web workload | ModSecurity / ingress-nginx WAF | Azure WAF | hands-on |  |  |  |
| `waf-rules` | Configure and tune OWASP Core Rule Set rules and paranoia levels | OWASP CRS | WAF managed rule sets | hands-on |  |  |  |
| `waf-verify` | Verify the WAF blocks injection and XSS attempts and tune false positives | ModSecurity audit log | WAF detection/prevention | hands-on |  |  |  |

### Protect data at rest and detect exposed secrets

Notes: `domains/2-secrets-data-networking/data-protection.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `data-encrypt` | Encrypt data at rest: etcd secrets, volumes, and application data | etcd encryption / Vault transit | Storage/SQL encryption, CMK | hands-on |  |  |  |
| `data-secretscan` | Scan repositories and images for plaintext secrets | Trivy / Gitleaks | Defender CSPM secret scanning | hands-on |  |  |  |

## Secure compute and AI workloads (20-25%)

### Harden pods and enforce workload security standards

Notes: `domains/3-compute-ai/pod-security.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `pod-psa` | Apply Pod Security Admission and the Pod Security Standards | Pod Security Admission | Pod security / AKS baselines | hands-on |  |  |  |
| `pod-securitycontext` | Harden securityContext: non-root, read-only root FS, dropped capabilities, seccomp | Kubernetes securityContext | Container hardening | hands-on |  |  |  |
| `pod-admission` | Enforce workload security at admission time | Kyverno / Gatekeeper | Azure Policy for AKS | hands-on |  |  |  |

### Detect and respond to runtime threats

Notes: `domains/3-compute-ai/runtime-security.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `rt-falco` | Detect anomalous runtime behavior with syscall-based rules | Falco | Defender for Containers | hands-on |  |  |  |
| `rt-tetragon` | Observe and enforce process/network behavior with eBPF | Tetragon | Defender for Containers runtime protection | hands-on |  |  |  |
| `rt-response` | Route runtime alerts and trigger response actions | Falcosidekick | Defender alerts / automation | hands-on |  |  |  |

### Secure the software supply chain and container images

Notes: `domains/3-compute-ai/supply-chain.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `sc-scan` | Scan images and dependencies for vulnerabilities | Trivy / Grype | Defender vulnerability management | hands-on |  |  |  |
| `sc-registry` | Secure a private registry and sign/verify images | Harbor / cosign | Azure Container Registry | hands-on |  |  |  |
| `sc-sbom` | Generate and evaluate SBOMs for deployed artifacts | Syft / Trivy SBOM | Supply-chain security | hands-on |  |  |  |
| `sc-admission` | Gate admission on scan results and signature verification | Kyverno / Harbor policy | Azure Policy for AKS | hands-on |  |  |  |

### Implement security for AI workloads *(new to SC-500)*

Notes: `domains/3-compute-ai/ai-security.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `ai-access` | Control access to models and the inference API with authentication and rate limits | Ollama behind a gateway + Keycloak | Azure OpenAI access control | hands-on |  |  |  |
| `ai-prompt` | Mitigate prompt-injection and jailbreak attempts | NeMo Guardrails / guardrails | Prompt Shields / prompt protection | hands-on |  |  |  |
| `ai-guardrails` | Filter unsafe input and output with content-safety guardrails | NeMo Guardrails | Azure AI Content Safety | hands-on |  |  |  |
| `ai-rag` | Design a secure RAG architecture with data isolation and least privilege | Open WebUI + Vault + RBAC | Secure RAG on Azure AI | hands-on |  |  |  |
| `ai-observability` | Instrument LLM calls for observability and auditing | OpenTelemetry | Azure AI monitoring / Application Insights | hands-on |  |  |  |
| `ai-governance` | Govern AI usage with policy at the gateway | OPA + AI gateway | AI governance / Purview DSPM for AI | walkthrough |  |  |  |

## Manage and monitor security posture (20-25%)

### Collect metrics, logs, and traces for security monitoring

Notes: `domains/4-posture-monitoring/observability.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `obs-metrics` | Collect and query metrics | Prometheus | Azure Monitor | hands-on |  |  |  |
| `obs-logs` | Aggregate and query logs | Loki | Log Analytics | hands-on |  |  |  |
| `obs-traces` | Capture distributed traces | Tempo / OpenTelemetry | Application Insights | hands-on |  |  |  |
| `obs-dashboards` | Build monitoring dashboards | Grafana | Azure Monitor Workbooks | hands-on |  |  |  |
| `obs-alerting` | Define alerting rules and routing | Alertmanager | Azure Monitor alerts | hands-on |  |  |  |

### Operate a SIEM and respond to incidents

Notes: `domains/4-posture-monitoring/siem-incident-response.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `siem-deploy` | Deploy a SIEM and its search backend | Wazuh + OpenSearch | Microsoft Sentinel | hands-on |  |  |  |
| `siem-collect` | Collect and normalize security telemetry from agents and sources | Wazuh agents / connectors | Sentinel data connectors | hands-on |  |  |  |
| `siem-detect` | Engineer detections with portable detection-as-code rules | Sigma rules | Sentinel analytics rules | hands-on |  |  |  |
| `siem-hunt` | Hunt threats and correlate events with a query language | OpenSearch Query DSL | KQL threat hunting | hands-on |  |  |  |
| `siem-response` | Automate incident response with active-response actions | Wazuh active response | Sentinel automation rules / SOAR | hands-on |  |  |  |

### Detect threats on the network

Notes: `domains/4-posture-monitoring/network-detection.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `nid-suricata` | Detect and optionally block malicious traffic with an IDS/IPS | Suricata | Network threat detection | hands-on |  |  |  |
| `nid-zeek` | Analyze network behavior and produce protocol logs | Zeek | Network security monitoring | hands-on |  |  |  |

### Manage vulnerabilities and security posture

Notes: `domains/4-posture-monitoring/vulnerability-posture.md`

| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |
|---|---|---|---|---|---|---|---|
| `vuln-cluster` | Scan cluster configuration for posture risks | Kubescape | Defender for Cloud posture | hands-on |  |  |  |
| `vuln-cis` | Audit nodes and cluster against CIS benchmarks | kube-bench / Kubescape | CIS benchmark auditing | hands-on |  |  |  |
| `vuln-compliance` | Produce compliance and secure-score style reports | Kubescape frameworks | Secure score / regulatory compliance | hands-on |  |  |  |
| `vuln-remediate` | Prioritize and remediate findings across images and infrastructure | Trivy + Kubescape | Defender recommendations | hands-on |  |  |  |

**Total objectives: 70**
