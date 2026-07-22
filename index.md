---
title: OSS-500 — Open-Source Cloud & AI Security Engineering
---

A complete, self-built **Cloud & AI Security** curriculum on a **100% open-source
stack** — for **$0**, entirely on a local machine, with no cloud account and no
expiring trials. It's **defense *and* offense, standards-grounded**: build each
control, then prove it by attacking it.

The **defensive anchor is Microsoft SC-500** (Cloud and AI Security Engineer
Associate) — every SC-500 control is mapped to an open-source equivalent and
practiced as a hands-on lab you deploy, verify, and tear down. On top of that
anchor the course expands *beyond* the exam into the full **zero-trust
access-model** picture and a **purple-team** habit of validating every defense.

## What it covers

- **Identity & access** — Keycloak SSO/MFA, Kubernetes RBAC, just-in-time access (Teleport/Boundary), workload identity.
- **Secrets, data & networking** — Vault, cert-manager, default-deny NetworkPolicy, service-mesh mTLS, WAF, encryption at rest.
- **Compute & AI** — Pod Security Admission, Kyverno/OPA, Falco/Tetragon runtime detection, Trivy/Grype supply chain, and AI security (prompt-injection guardrails, secure RAG, LLM observability).
- **Posture & monitoring** — Prometheus/Grafana/Loki, Wazuh SIEM, Suricata/Zeek, Kubescape.
- **Zero-trust access — five models** — broker, app-embedded overlay, identity-aware proxy, WireGuard mesh, on a SPIFFE/SPIRE substrate — Terraform-automated.
- **Offensive validation — purple team** — prove every control by attacking it: garak/PyRIT vs AI guardrails, Atomic Red Team/Caldera vs runtime + SIEM detections, authz tests vs the ZTNA brokers.

## Explore the curriculum

The full course — study notes, lab guides, infrastructure-as-code, and quizzes —
lives in the repository:

- **[Browse the repo →](https://github.com/patrickdaj/oss-500)**
- **[Start with the learning path](https://github.com/patrickdaj/oss-500/blob/main/plan/overview.md)**
- **[Standards map (ATT&CK ↔ D3FEND, OWASP LLM, NIST AI RMF, 800-207)](https://github.com/patrickdaj/oss-500/blob/main/domains/standards-map.md)**
- **[Objective tracker](https://github.com/patrickdaj/oss-500/blob/main/assessment/tracker.md)**

---

*Built and studied in public. See the companion lab & notes repo:
[cloud-native-security-lab](https://github.com/patrickdaj/cloud-native-security-lab).*
