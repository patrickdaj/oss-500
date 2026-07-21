# Protect web workloads with a web application firewall

Domain 2, subsection 4 (`d2-waf`). A firewall and a mesh secure the network; a **web application firewall** inspects L7 HTTP traffic for *application* attacks — SQL injection, XSS, path traversal, RCE payloads. On this stack that's **ModSecurity** running inside **ingress-nginx**, loaded with the **OWASP Core Rule Set (CRS)**. Deploy it, tune the rules, and prove it blocks. Primary lab: [d2-ingress-waf](../../labs/d2-ingress-waf.md); environment in [`lab-infra/network/`](../../lab-infra/network/).

## Deploy a WAF in front of a web workload

*Objective: `waf-deploy` · OSS: ModSecurity / ingress-nginx WAF ≈ SC-500: Azure WAF · Lab: [d2-ingress-waf](../../labs/d2-ingress-waf.md)*

ingress-nginx ships with the **ModSecurity** WAF engine compiled in; you just turn it on. Enable it globally in the controller's ConfigMap, or per-Ingress with an annotation, so HTTP requests are inspected *before* they reach the backend — the same "WAF bolted onto the edge proxy" topology as `net-ingress`. The critical operational choice is **mode**: `SecRuleEngine DetectionOnly` logs matches without blocking (safe rollout, learn your false positives) versus `SecRuleEngine On` which actively **blocks** (returns 403). You always onboard in DetectionOnly, tune, then flip to On.

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

This is the OSS equivalent of **Azure WAF** (on Application Gateway or Front Door): an L7 inspection layer in front of the app, running in **Detection** or **Prevention** mode — the exact same two-mode model. Just as Azure bundles WAF into App Gateway, here the WAF lives in the same ingress-nginx that terminates TLS.

Exam gotchas:

- A WAF is **L7 (HTTP payload) inspection** — orthogonal to NetworkPolicy/firewall (L3/4). It catches SQLi/XSS in the request body a port-based control can't see.
- **DetectionOnly logs, On blocks.** Deploying the WAF isn't protection until `SecRuleEngine On`; DetectionOnly is a tuning phase, mirroring Azure WAF Detection vs Prevention.
- ModSecurity is enabled but **empty** without a rule set — turning the engine on does nothing until CRS is loaded (`waf-rules`).
- Enable per-Ingress to scope the WAF to one app; the ConfigMap toggle is controller-wide.

**Resources:**
- [ingress-nginx ModSecurity guide](https://kubernetes.github.io/ingress-nginx/user-guide/third-party-addons/modsecurity/) (~15 min)
- [OWASP ModSecurity engine](https://github.com/owasp-modsecurity/ModSecurity) (~15 min)

## Configure and tune OWASP Core Rule Set rules and paranoia levels

*Objective: `waf-rules` · OSS: OWASP CRS ≈ SC-500: WAF managed rule sets · Lab: [d2-ingress-waf](../../labs/d2-ingress-waf.md)*

ModSecurity is just the engine; the **OWASP Core Rule Set (CRS)** is the actual attack-detection ruleset — a community-maintained set covering the OWASP Top 10 (SQLi, XSS, LFI/RFI, RCE, protocol violations). ingress-nginx bundles CRS; enable it with `enable-owasp-modsecurity-crs: "true"`. CRS uses **anomaly scoring**: instead of one rule = one block, each matched rule adds to a score, and the request is blocked only when the score crosses the **inbound/outbound anomaly threshold** — this reduces false positives from any single noisy rule.

The tuning dial is the **Paranoia Level (PL1–PL4)**. PL1 (default) catches obvious attacks with few false positives; higher PLs add stricter, more aggressive rules that catch more but flag more legitimate traffic — a security-vs-usability trade you raise deliberately.

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

This maps to Azure WAF **managed rule sets**: Azure's OWASP/CRS-based managed rules and its own anomaly-scoring model are the same concept — Microsoft ships and updates the ruleset, you pick the rule-set version and tune. CRS *is* the upstream OWASP project those managed rules derive from.

Exam gotchas:

- CRS uses **anomaly scoring**, not one-rule-one-block: matches accumulate a score; blocking happens at the **threshold** (lower threshold = stricter).
- **Paranoia level** trades detection for false positives (PL1 default → PL4 strictest). Raising PL without tuning floods you with false positives.
- The engine (ModSecurity) and the rules (CRS) are separate — you must explicitly load CRS; ModSecurity alone blocks nothing.
- CRS is the upstream of Azure's managed rule sets — "managed rules" on the exam = a vendor-shipped CRS-style ruleset you version and tune, not hand-written rules.

**Resources:**
- [OWASP CRS documentation](https://coreruleset.org/docs/) (~20 min)
- [CRS paranoia levels & anomaly scoring](https://coreruleset.org/docs/concepts/paranoia_levels/) (~15 min)

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

The other half is **false-positive tuning**: legitimate traffic that trips a rule. You don't disable the WAF — you surgically **exclude** the offending rule for that path/parameter with `SecRuleRemoveById` (or `SecRuleUpdateTargetById` / `ctl:ruleRemoveTargetById`), then re-test that the *attack* is still blocked. This detection-tune-prevent loop is the operational heart of running a WAF.

```
# modsecurity-snippet: drop a single false-positive rule id for this app
SecRuleRemoveById 942100
```

This is Azure WAF **detection/prevention** verification: fire a payload, confirm the block in the WAF logs (Log Analytics on Azure; the ModSecurity audit log here), and tune exclusions to cut false positives without weakening real coverage.

Exam gotchas:

- Proof of a WAF is an **observed 403 + an audit-log match**, not merely that CRS is enabled — this is the lab's verification observable.
- Tune false positives with **targeted rule exclusions** (`SecRuleRemoveById`/target updates) scoped to the path/param — never by disabling the engine or dropping paranoia globally.
- Always re-test the *malicious* payload after adding an exclusion to confirm you narrowed, not opened, the WAF.
- The audit log names the **rule id** and matched data — that id is what you exclude or investigate, and what you forward to the SIEM (Domain 4).

**Resources:**
- [CRS false-positive tuning](https://coreruleset.org/docs/concepts/false_positives_tuning/) (~20 min)
- [ModSecurity audit log reference](https://github.com/owasp-modsecurity/ModSecurity/wiki/Reference-Manual-(v3.x)#SecAuditLog) (~15 min)

## Summary

| Objective | Takeaway |
|---|---|
| `waf-deploy` | ModSecurity in ingress-nginx (`enable-modsecurity`), L7 inspection at the edge; DetectionOnly logs / On blocks ≈ Azure WAF Detection vs Prevention |
| `waf-rules` | OWASP CRS (`enable-owasp-modsecurity-crs`) is the ruleset; anomaly scoring + threshold; paranoia levels PL1–PL4 trade detection vs false positives |
| `waf-verify` | Prove a 403 on SQLi/XSS + audit-log match; tune false positives with targeted `SecRuleRemoveById` exclusions, then re-test the attack |
