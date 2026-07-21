# Protect web workloads with a web application firewall

Domain 2, subsection 4 (`d2-waf`). A firewall and a mesh secure the network; a **web application firewall** inspects L7 HTTP traffic for *application* attacks — SQL injection, XSS, path traversal, RCE payloads. On this stack that's **ModSecurity** running inside **ingress-nginx**, loaded with the **OWASP Core Rule Set (CRS)**. Deploy it, tune the rules, and prove it blocks. Primary lab: [d2-ingress-waf](../../labs/d2-ingress-waf.md); environment in [`lab-infra/network/`](../../lab-infra/network/).

## Deploy a WAF in front of a web workload

*Objective: `waf-deploy` · OSS: ModSecurity / ingress-nginx WAF ≈ SC-500: Azure WAF · Lab: [d2-ingress-waf](../../labs/d2-ingress-waf.md)*

ingress-nginx ships with the **ModSecurity** (libmodsecurity v3) WAF engine compiled in via the `ngx_http_modsecurity_module` connector; you just turn it on. Enable it globally in the controller's ConfigMap, or per-Ingress with an annotation, so HTTP requests are inspected *before* they reach the backend — the same "WAF bolted onto the edge proxy" topology as `net-ingress`. ModSecurity processes each request through five **phases**: (1) request headers, (2) request body, (3) response headers, (4) response body, (5) logging — rules declare which phase they run in, which is why body-inspection rules need phase 2 and why `SecRequestBodyAccess On` must be set for SQLi/XSS body detection to work at all.

The critical operational choice is **mode**: `SecRuleEngine DetectionOnly` logs matches without blocking (safe rollout, learn your false positives) versus `SecRuleEngine On` which actively **blocks** (returns 403). You always onboard in DetectionOnly, tune, then flip to On. A third value, `SecRuleEngine Off`, disables inspection entirely.

```yaml
# Controller-wide: enable ModSecurity in the ingress-nginx ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
data:
  enable-modsecurity: "true"
  # start in detection to learn false positives, then set SecRuleEngine On to block
  modsecurity-snippet: |
    SecRuleEngine DetectionOnly
    SecAuditLog /var/log/modsec/audit.log
    SecAuditEngine RelevantOnly
```

```yaml
# Per-Ingress: enable the WAF (and blocking) only on one app
metadata:
  annotations:
    nginx.ingress.kubernetes.io/enable-modsecurity: "true"
    nginx.ingress.kubernetes.io/modsecurity-snippet: |
      SecRuleEngine On
```

This is the OSS equivalent of **Azure WAF** (on Application Gateway or Front Door): an L7 inspection layer in front of the app, running in **Detection** or **Prevention** mode — the exact same two-mode model. Just as Azure bundles WAF into App Gateway, here the WAF lives in the same ingress-nginx that terminates TLS, which matters because the WAF can only inspect **decrypted** traffic — it must sit *after* TLS termination, never in front of it.

Common failure modes:

- **WAF sees nothing because TLS isn't terminated there.** If traffic is passed through (TCP/SSL passthrough) rather than terminated at ingress-nginx, ModSecurity inspects ciphertext and every rule is blind.
- **Body attacks slip through** when `SecRequestBodyAccess` is off or the payload exceeds `SecRequestBodyLimit` — large bodies are skipped or rejected depending on `SecRequestBodyLimitAction`.
- **Engine on, no rules loaded** — `SecRuleEngine On` with no CRS blocks nothing; a green "ModSecurity enabled" is not protection (`waf-rules`).
- **Snippet annotation ignored** — ingress-nginx only honors `modsecurity-snippet` / config snippets when `allow-snippet-annotations: "true"` (tightened in recent releases after CVE hardening); otherwise your per-Ingress tuning is silently dropped.

Exam gotchas:

- A WAF is **L7 (HTTP payload) inspection** — orthogonal to NetworkPolicy/firewall (L3/4). It catches SQLi/XSS in the request body a port-based control can't see.
- **DetectionOnly logs, On blocks.** Deploying the WAF isn't protection until `SecRuleEngine On`; DetectionOnly is a tuning phase, mirroring Azure WAF Detection vs Prevention.
- ModSecurity is enabled but **empty** without a rule set — turning the engine on does nothing until CRS is loaded (`waf-rules`).
- Enable per-Ingress to scope the WAF to one app; the ConfigMap toggle is controller-wide.
- A WAF is compensating, not curative — it reduces exposure to the **OWASP Top 10** but doesn't fix the vulnerable code; the exam frames it as defense-in-depth alongside secure SDLC, not a replacement.

**Resources:**
- [ingress-nginx ModSecurity guide](https://kubernetes.github.io/ingress-nginx/user-guide/third-party-addons/modsecurity/) (~15 min)
- [OWASP ModSecurity v3 engine (GitHub)](https://github.com/owasp-modsecurity/ModSecurity) (~15 min)
- [ModSecurity Reference Manual (v3.x) — processing phases & SecRuleEngine](https://github.com/owasp-modsecurity/ModSecurity/wiki/Reference-Manual-(v3.x)) (~25 min)
- [OWASP Top 10 (2021)](https://owasp.org/www-project-top-ten/) (~20 min)
- [Azure WAF Detection vs Prevention mode (concept parallel)](https://learn.microsoft.com/azure/web-application-firewall/ag/ag-overview) (~10 min)

## Configure and tune OWASP Core Rule Set rules and paranoia levels

*Objective: `waf-rules` · OSS: OWASP CRS ≈ SC-500: WAF managed rule sets · Lab: [d2-ingress-waf](../../labs/d2-ingress-waf.md)*

ModSecurity is just the engine; the **OWASP Core Rule Set (CRS)** is the actual attack-detection ruleset — a community-maintained (now an OWASP flagship) set covering the OWASP Top 10 (SQLi, XSS, LFI/RFI, RCE, PHP/Java injection, protocol violations, scanner/bot detection). ingress-nginx bundles CRS; enable it with `enable-owasp-modsecurity-crs: "true"`. CRS uses **anomaly scoring** (collaborative detection): instead of one rule = one block, each matched rule adds a severity-weighted amount to `tx.inbound_anomaly_score`, and the request is blocked in the blocking-evaluation rule only when the score crosses the **inbound/outbound anomaly threshold** — this decouples detection from the block decision and reduces false positives from any single noisy rule. Each rule also carries a severity (CRITICAL=5, ERROR=4, WARNING=3, NOTICE=2), which is what it contributes to the score.

The tuning dial is the **Paranoia Level (PL1–PL4)**. PL1 (default) catches obvious attacks with few false positives; higher PLs add stricter, more aggressive rules that catch more but flag more legitimate traffic — a security-vs-usability trade you raise deliberately. A companion setting, **executing/sampling paranoia level**, lets you *evaluate* a higher PL's rules in logging-only mode before committing. CRS is versioned (the 4.x line); pinning a version is the equivalent of choosing an Azure WAF managed-rule-set version.

```yaml
data:
  enable-modsecurity: "true"
  enable-owasp-modsecurity-crs: "true"        # load the OWASP Core Rule Set
  modsecurity-snippet: |
    SecRuleEngine On
    SecAction "id:900110,phase:1,pass,nolog,\
      setvar:tx.inbound_anomaly_score_threshold=5,\
      setvar:tx.outbound_anomaly_score_threshold=4"
    SecAction "id:900000,phase:1,pass,nolog,setvar:tx.paranoia_level=1"
```

This maps to Azure WAF **managed rule sets**: Azure's OWASP/CRS-based managed rules (the "OWASP" / Microsoft_DefaultRuleSet) and its own anomaly-scoring model are the same concept — Microsoft ships and updates the ruleset, you pick the rule-set version and tune per-rule/per-group overrides. CRS *is* the upstream OWASP project those managed rules derive from, so understanding CRS anomaly scoring is directly how you reason about the Azure exam questions.

Exam gotchas:

- CRS uses **anomaly scoring**, not one-rule-one-block: matches accumulate a severity-weighted score; blocking happens at the **threshold** (lower threshold = stricter). A single CRITICAL rule (score 5) blocks at the default inbound threshold of 5.
- **Paranoia level** trades detection for false positives (PL1 default → PL4 strictest). Raising PL without tuning floods you with false positives; use the sampling/executing PL to preview.
- The engine (ModSecurity) and the rules (CRS) are separate — you must explicitly load CRS; ModSecurity alone blocks nothing.
- CRS is the upstream of Azure's managed rule sets — "managed rules" on the exam = a vendor-shipped CRS-style ruleset you version and tune, not hand-written rules.
- **Custom rules** (an app-specific `SecRule` you author) evaluate *before/alongside* managed CRS rules — the exam contrasts writing your own rule with tuning the managed set; you reach for a custom rule only when CRS has no coverage.

**Resources:**
- [OWASP CRS documentation](https://coreruleset.org/docs/) (~20 min)
- [CRS paranoia levels](https://coreruleset.org/docs/concepts/paranoia_levels/) (~15 min)
- [CRS anomaly scoring explained](https://coreruleset.org/docs/concepts/anomaly_scoring/) (~15 min)
- [CRS rules & rule categories overview](https://coreruleset.org/docs/rules/) (~15 min)
- [OWASP Top 10 mapped to CRS coverage](https://owasp.org/www-project-top-ten/) (~15 min)

## Verify the WAF blocks injection and XSS attempts and tune false positives

*Objective: `waf-verify` · OSS: ModSecurity audit log ≈ SC-500: WAF detection/prevention · Lab: [d2-ingress-waf](../../labs/d2-ingress-waf.md)*

A WAF isn't done until you've *watched it block*. With `SecRuleEngine On` + CRS loaded, send a classic SQL-injection or XSS payload and confirm a **403** plus a match in the **audit log** (`SecAuditLog`), which records the triggered rule id, the matched data, and the anomaly score:

```bash
# SQL injection attempt — CRS should block with HTTP 403
curl -sk "https://app.oss500.local/?id=1%27%20OR%20%271%27%3D%271" -o /dev/null -w "%{http_code}\n"
# -> 403

# XSS attempt — also 403
curl -sk "https://app.oss500.local/?q=<script>alert(1)</script>" -o /dev/null -w "%{http_code}\n"
# -> 403

# See exactly which rule fired
kubectl exec -n ingress-nginx <controller-pod> -- tail -n 50 /var/log/modsec/audit.log
```

The other half is **false-positive tuning**: legitimate traffic that trips a rule. You don't disable the WAF — you surgically **exclude** the offending rule for that path/parameter. CRS distinguishes **rule exclusions**: a *blanket* exclusion removes a rule entirely (`SecRuleRemoveById 942100`), while a **targeted** exclusion (`SecRuleUpdateTargetById` / `ctl:ruleRemoveTargetById`) drops just one parameter from one rule's scope — far surgical, and the preferred CRS pattern. CRS also ships a `REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` / `-AFTER-CRS.conf` convention for exactly this. After any exclusion, re-test that the *attack* is still blocked. This detection-tune-prevent loop is the operational heart of running a WAF.

```
# modsecurity-snippet: two tuning styles for a known false positive on rule 942100
SecRuleRemoveById 942100                                      # blanket — drops the rule everywhere (blunt)
SecRuleUpdateTargetById 942100 "!ARGS:comment"               # targeted — exempt only the 'comment' param
```

To read what fired, the audit log is JSON with sections (A=header, B=request headers, C=request body, H=audit/matched-rule data, etc.). Grep the `H` section for the `id`, `msg`, and the accumulated `Anomaly Score` to see why the request crossed the threshold.

This is Azure WAF **detection/prevention** verification: fire a payload, confirm the block in the WAF logs (Log Analytics / the `AzureDiagnostics` `WAFEvln` table on Azure; the ModSecurity audit log here), and tune exclusions/per-rule overrides to cut false positives without weakening real coverage.

Exam gotchas:

- Proof of a WAF is an **observed 403 + an audit-log match**, not merely that CRS is enabled — this is the lab's verification observable.
- Tune false positives with **targeted rule exclusions** (prefer `SecRuleUpdateTargetById` over a blanket `SecRuleRemoveById`) scoped to the path/param — never by disabling the engine or dropping paranoia globally.
- Always re-test the *malicious* payload after adding an exclusion to confirm you narrowed, not opened, the WAF.
- The audit log names the **rule id** and matched data — that id is what you exclude or investigate, and what you forward to the SIEM (Domain 4) for WAF alerting.
- A WAF blocking a payload does **not** mean the app is patched — the exam distinguishes "blocked at the edge" (compensating control) from "vulnerability remediated in code."

**Resources:**
- [CRS false-positive & tuning guide](https://coreruleset.org/docs/concepts/false_positives_tuning/) (~20 min)
- [ModSecurity SecAuditLog reference](https://github.com/owasp-modsecurity/ModSecurity/wiki/Reference-Manual-(v3.x)#SecAuditLog) (~15 min)
- [OWASP WSTG — testing for SQLi & XSS (payloads to verify with)](https://owasp.org/www-project-web-security-testing-guide/) (~20 min)
- [OWASP ASVS — verification requirements a WAF complements](https://owasp.org/www-project-application-security-verification-standard/) (~20 min)
- [OWASP CRS Sandbox / test payloads](https://coreruleset.org/docs/development/sandbox/) (~10 min)

## Summary

| Objective | Takeaway |
|---|---|
| `waf-deploy` | ModSecurity in ingress-nginx (`enable-modsecurity`), L7 inspection at the edge; DetectionOnly logs / On blocks ≈ Azure WAF Detection vs Prevention |
| `waf-rules` | OWASP CRS (`enable-owasp-modsecurity-crs`) is the ruleset; anomaly scoring + threshold; paranoia levels PL1–PL4 trade detection vs false positives |
| `waf-verify` | Prove a 403 on SQLi/XSS + audit-log match; tune false positives with targeted `SecRuleRemoveById` exclusions, then re-test the attack |
