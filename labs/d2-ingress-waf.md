# Lab d2: TLS ingress + ModSecurity WAF (OWASP CRS)

Terminate TLS at the ingress with a cert-manager cert, then put ModSecurity + the OWASP Core Rule Set in front of it and watch a SQL-injection request come back 403.

**Objectives covered**

| id | Objective |
|---|---|
| `net-ingress` | Secure ingress with TLS termination and authenticated access |
| `waf-deploy` | Deploy a WAF in front of a web workload |
| `waf-rules` | Configure and tune OWASP Core Rule Set rules and paranoia levels |
| `waf-verify` | Verify the WAF blocks injection and XSS attempts and tune false positives |

**SC-500 correspondence**: secure ingress / Application Gateway (TLS termination) · Azure WAF (ModSecurity) · WAF managed rule sets (OWASP CRS) · WAF detection/prevention modes

**Prerequisites**

- [`lab-infra/network`](../lab-infra/network/) up (`./up.sh`) — ingress-nginx built **with ModSecurity + the OWASP CRS** bundled (the controller image ships them; the component enables them via ConfigMap/annotations).
- [`lab-infra/certs`](../lab-infra/certs/) up for the TLS cert (from [d2-cert-manager](d2-cert-manager.md)).
- Notes read: [web-application-firewall.md](../domains/2-secrets-data-networking/web-application-firewall.md) and [network-security.md](../domains/2-secrets-data-networking/network-security.md) (`net-ingress`).

**Estimated time**: 2–3 h · $0 (local)

> Ingress is reachable on `localhost:8080/8443` (kind port-mapping). Use the wildcard resolver `demo.localtest.me` (→ 127.0.0.1) so `Host`-based routing and TLS SNI work without editing `/etc/hosts`.

## Steps

### Part A — TLS termination at the ingress (`net-ingress`)

1. Deploy a demo web app to protect:
   ```bash
   kubectl -n oss500-apps create deployment demo --image=hashicorp/http-echo --port=5678 -- -text="hello from demo"
   kubectl -n oss500-apps expose deployment demo --port=80 --target-port=5678
   ```
2. Create an Ingress that **terminates TLS** using a cert-manager-issued certificate (the annotation makes cert-manager mint `demo-tls` automatically from the `oss500-ca-issuer` built in the cert lab):
   ```yaml
   # ingress.yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: demo
     namespace: oss500-apps
     labels: { app.kubernetes.io/part-of: oss500 }
     annotations:
       cert-manager.io/cluster-issuer: "oss500-ca-issuer"     # net-ingress: cert-manager provisions the TLS secret
   spec:
     ingressClassName: nginx
     tls:
       - hosts: ["demo.localtest.me"]
         secretName: demo-tls                                  # TLS terminated here
     rules:
       - host: demo.localtest.me
         http:
           paths:
             - path: /
               pathType: Prefix
               backend: { service: { name: demo, port: { number: 80 } } }
   ```
   ```bash
   kubectl apply -f ingress.yaml
   kubectl -n oss500-apps get certificate demo-tls    # READY True (cert-manager issued it)
   ```
3. Confirm TLS termination end-to-end (the cert is served by the ingress; `--resolve` maps SNI to localhost:8443):
   ```bash
   curl -k https://demo.localtest.me:8443/ --resolve demo.localtest.me:8443:127.0.0.1
   # hello from demo
   curl -kvI https://demo.localtest.me:8443/ --resolve demo.localtest.me:8443:127.0.0.1 2>&1 | grep -i 'subject\|issuer'
   # subject: CN=demo.localtest.me ; issuer: CN=oss500-ca
   ```
   (For **authenticated** ingress, you'd add `nginx.ingress.kubernetes.io/auth-url` pointing at Keycloak/oauth2-proxy — noted in the network-security notes; the WAF is the layer we prove here.)

### Part B — Deploy the WAF (`waf-deploy`)

ModSecurity is the WAF engine embedded in ingress-nginx; it inspects requests before they reach the backend — the Azure WAF analogue in front of App Gateway.

4. Turn ModSecurity on for this Ingress and **start in detection-only** (log, don't block) so you can baseline traffic without breaking anything:
   ```yaml
   # add to the Ingress annotations
   nginx.ingress.kubernetes.io/enable-modsecurity: "true"           # waf-deploy: engine on for this ingress
   nginx.ingress.kubernetes.io/modsecurity-snippet: |
     SecRuleEngine DetectionOnly
     SecAuditEngine RelevantOnly
     SecAuditLog /dev/stdout
     SecAuditLogFormat JSON
   ```
   ```bash
   kubectl apply -f ingress.yaml
   ```
5. Send a malicious-looking request and confirm it is **logged but still served** (detection-only):
   ```bash
   curl -k "https://demo.localtest.me:8443/?id=1'%20OR%20'1'='1" --resolve demo.localtest.me:8443:127.0.0.1
   # still: hello from demo   (200) -- but the controller log records a ModSecurity match
   kubectl -n ingress-nginx logs deploy/ingress-nginx-controller | grep -i ModSecurity | tail
   ```
   DetectionOnly is how you tune before enforcing — the same "WAF in Detection mode" stance Azure WAF offers.
6. Flip to **prevention** by switching the engine on:
   ```yaml
   nginx.ingress.kubernetes.io/modsecurity-snippet: |
     SecRuleEngine On                                             # waf-deploy: now BLOCKING
     SecAuditEngine RelevantOnly
     SecAuditLog /dev/stdout
     SecAuditLogFormat JSON
   ```

### Part C — Enable & tune the OWASP Core Rule Set (`waf-rules`)

The CRS is the managed rule set (the Azure "WAF managed ruleset" analogue): generic SQLi/XSS/LFI/RCE detections scored by an **anomaly engine** with a tunable **paranoia level**.

7. Enable CRS and set paranoia + thresholds:
   ```yaml
   nginx.ingress.kubernetes.io/enable-modsecurity: "true"
   nginx.ingress.kubernetes.io/enable-owasp-modsecurity-crs: "true"   # waf-rules: load OWASP CRS
   nginx.ingress.kubernetes.io/modsecurity-snippet: |
     SecRuleEngine On
     SecAuditEngine RelevantOnly
     SecAuditLog /dev/stdout
     SecAuditLogFormat JSON
     # CRS tuning (waf-rules):
     SecAction "id:900000,phase:1,pass,nolog,setvar:tx.paranoia_level=1"          # PL1 = fewer false positives
     SecAction "id:900110,phase:1,pass,nolog,setvar:tx.inbound_anomaly_score_threshold=5"
     SecAction "id:900110,phase:1,pass,nolog,setvar:tx.outbound_anomaly_score_threshold=4"
   ```
   ```bash
   kubectl apply -f ingress.yaml
   ```
8. Understand the dials: **paranoia level 1→4** raises sensitivity (and false positives); the **anomaly score threshold** is how many rule "points" a request may accumulate before it's blocked. Higher paranoia + lower threshold = stricter. (Cluster-wide CRS defaults can also be set in the controller ConfigMap.)

### Part D — Verify blocking & tune a false positive (`waf-verify`)

9. **SQL injection → 403.** With enforcement + CRS on, the earlier payload is now blocked:
   ```bash
   curl -k -o /dev/null -w "%{http_code}\n" "https://demo.localtest.me:8443/?id=1'%20OR%20'1'='1" --resolve demo.localtest.me:8443:127.0.0.1
   # 403
   ```
10. **XSS → 403**:
    ```bash
    curl -k -o /dev/null -w "%{http_code}\n" "https://demo.localtest.me:8443/?q=<script>alert(1)</script>" --resolve demo.localtest.me:8443:127.0.0.1
    # 403
    ```
11. **Benign request → 200** (proves the WAF isn't just blocking everything):
    ```bash
    curl -k -o /dev/null -w "%{http_code}\n" "https://demo.localtest.me:8443/?q=hello" --resolve demo.localtest.me:8443:127.0.0.1
    # 200
    ```
12. **Read the audit log** to see *which CRS rule* fired (the rule id is what you tune against):
    ```bash
    kubectl -n ingress-nginx logs deploy/ingress-nginx-controller | grep -i ModSecurity | tail -n 1 | jq '.transaction.messages[].details.ruleId'
    # e.g. "942100"  (CRS SQLi via libinjection),  "941100" (XSS)
    ```
13. **Tune a false positive.** Suppose a legitimate app field trips rule `942100`. Rather than disabling the WAF, surgically remove just that rule (ideally scoped to one path) — the "reduce WAF false positives without weakening the whole policy" skill:
    ```yaml
    nginx.ingress.kubernetes.io/modsecurity-snippet: |
      SecRuleEngine On
      Include /etc/nginx/owasp-modsecurity-crs/crs-setup.conf
      # waf-verify: allow a known-good pattern on one field, keep the rest of CRS enforcing
      SecRuleRemoveById 942100
    ```
    Re-send the previously-blocked legitimate request → now **200**, while other SQLi patterns still 403. (Best practice: prefer a narrowly-scoped `SecRuleUpdateTargetById`/exclusion over a blanket `RemoveById`.)

## Verification

- **TLS**: `curl -kvI https://demo.localtest.me:8443/` shows the cert `subject=CN=demo.localtest.me` issued by `CN=oss500-ca` — TLS is terminated at the ingress with a cert-manager cert.
- **WAF blocks attacks**: the SQLi and XSS `curl`s return **403**, and the controller ModSecurity audit log names the firing CRS rule id (e.g. `942100`, `941100`).
- **No over-blocking**: a benign `?q=hello` request returns **200**; after `SecRuleRemoveById`, the specific false-positive request returns **200** while other injection payloads still return 403.
- **Mode change is observable**: the same SQLi payload returns 200 (logged) in `DetectionOnly` and 403 in `SecRuleEngine On`.

## Teardown

- `cd lab-infra/network && ./down.sh`

## What the exam asks

- A WAF inspects **application-layer (L7)** requests for injection/XSS/etc. — distinct from an NSG/NetworkPolicy (L3/L4) and from TLS termination. "Block SQL injection reaching the app" = WAF, not a firewall rule.
- **Detection vs Prevention** mode: DetectionOnly logs without blocking (for tuning/baselining); Prevention blocks. Roll out in detection first, then enforce — the exam's WAF deployment best practice.
- The **OWASP Core Rule Set** is the managed rule set; **paranoia level** trades coverage for false positives and the **anomaly score threshold** decides the block cutoff. Tuning false positives means excluding a specific rule id (ideally per-path), *not* disabling the WAF.
- TLS **termination** at the ingress/gateway lets the WAF inspect decrypted traffic — end-to-end re-encryption to the backend is a separate choice. App Gateway + WAF ≈ ingress-nginx + ModSecurity/CRS.
- Read the **audit log rule id** to identify what blocked a request — the artifact you use to justify a tuning exclusion.
