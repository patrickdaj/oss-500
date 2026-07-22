# Checkpoint 2 — Secrets, data, and networking

Generated from `assessment/data/quiz-2.yaml` — study-hub runs this interactively (Tests page). Pass bar: 80%. 40 questions.

### 1. You initialize a new HashiCorp Vault server and it reports itself as "Sealed: true". An engineer says the root token from `vault operator init` should let them start reading secrets immediately. What is actually required first?

- A. Nothing — the root token unseals Vault implicitly on first use
- B. A quorum of unseal key shares must be supplied to reconstruct the master key and decrypt the storage backend
- C. Restart the Vault process, which auto-unseals from the storage backend
- D. Set VAULT_TOKEN to the root token, which disables the seal

<details><summary>Answer</summary>

**B** — A sealed Vault holds no plaintext master key, so it cannot decrypt its storage backend or serve any request, regardless of token. Unsealing requires a threshold of Shamir key shares (e.g. 3 of 5) to reconstruct the master key. Only after unsealing does the root token become usable.

[Documentation](https://developer.hashicorp.com/vault/docs/concepts/seal) · objectives: `vault-deploy`

</details>

### 2. You are running Vault in HA on Kubernetes and want to avoid an operator manually entering unseal shares every time a pod restarts, while keeping the master key protected by an external root of trust. Which approach fits?

- A. Run Vault in -dev mode so it starts unsealed
- B. Configure auto-unseal with a transit/KMS seal that wraps the master key with an external key
- C. Store the unseal keys in a Kubernetes Secret mounted into the pod
- D. Set the Shamir threshold to 1 so any single share unseals it

<details><summary>Answer</summary>

**B** — Auto-unseal delegates protection of the master key to an external service (a Transit seal on another Vault, or a cloud/HSM KMS). Vault then unseals itself on start without human key entry. Dev mode is in-memory and insecure; storing unseal keys in a Secret defeats the purpose; a threshold of 1 removes the split-knowledge protection.

[Documentation](https://developer.hashicorp.com/vault/docs/concepts/seal#auto-unseal) · objectives: `vault-deploy`

</details>

### 3. An application should be able to read secrets only under `secret/data/app/*` and nothing else. Which Vault construct enforces this, and how is it attached to the app?

- A. A firewall rule on the Vault listener restricting the app's IP
- B. An ACL policy granting read on that path, bound to the auth role the app logs in with
- C. A Kubernetes RBAC Role in the app's namespace
- D. The root token, scoped down with an environment variable

<details><summary>Answer</summary>

**B** — Vault authorization is path-based ACL policies (HCL granting capabilities like read/list on a path), attached to the identity a client receives from an auth method. Vault policies are not Kubernetes RBAC and are not IP filters; the root token has no path restrictions.

[Documentation](https://developer.hashicorp.com/vault/docs/concepts/policies) · objectives: `vault-access`

</details>

### 4. A workload authenticates to Vault using the Kubernetes auth method. Which two elements does Vault verify or bind when that pod logs in? (Select two)

- A. The ServiceAccount JWT the pod presents, validated against the cluster's token review / OIDC issuer
- B. The role's bound ServiceAccount names and namespaces
- C. The pod's image digest signature
- D. The node's TPM attestation quote

<details><summary>Answer</summary>

**A, B** (multiple answers) — Kubernetes auth validates the presented ServiceAccount token (via the TokenReview API or the cluster's OIDC issuer) and checks it against the role's bound_service_account_names and bound_service_account_namespaces before issuing a Vault token with the mapped policies. Image signatures and TPM attestation are not part of this auth method.

[Documentation](https://developer.hashicorp.com/vault/docs/auth/kubernetes) · objectives: `vault-access`

</details>

### 5. Instead of a shared database password stored in a Secret, you configure Vault's database secrets engine so each app instance calls `vault read database/creds/app`. What is the security advantage the exam is looking for?

- A. The password is base64-encoded so it can't be read
- B. Vault issues a unique, short-lived credential per request that it can revoke and that auto-expires with its lease
- C. The credential is encrypted at rest in etcd
- D. The app no longer needs any network access to the database

<details><summary>Answer</summary>

**B** — Dynamic secrets are generated on demand, unique per consumer, tied to a lease with a TTL, and revocable — so a leaked credential is short-lived and traceable, and there is no long-lived shared password. Base64 and etcd encryption are unrelated; the app still connects to the DB normally.

[Documentation](https://developer.hashicorp.com/vault/docs/secrets/databases) · objectives: `vault-dynamic`

</details>

### 6. A dynamic database credential was issued with a 1-hour lease. Thirty minutes in, you detect the consuming pod is compromised. What is the fastest correct containment in Vault, and what happens to the DB user?

- A. Wait for the lease to expire on its own; nothing else is possible
- B. Run `vault lease revoke` on the lease (or `-prefix`); Vault runs the revocation SQL and drops the database user immediately
- C. Delete the Vault policy, which retroactively invalidates the credential
- D. Rotate the app's ServiceAccount token, which cascades to the DB user

<details><summary>Answer</summary>

**B** — Leases can be revoked before expiry with `vault lease revoke` (single or by prefix), which triggers the engine's revocation statements to drop the database user right away. Deleting a policy or rotating an SA token does not remove an already-created database user.

[Documentation](https://developer.hashicorp.com/vault/docs/concepts/lease) · objectives: `vault-dynamic`

</details>

### 7. When you configure Vault's database secrets engine, you give it an admin account. A reviewer worries that admin password now lives in your configuration management. What does `vault write -f database/rotate-root` accomplish?

- A. It rotates every dynamic credential Vault has issued
- B. It changes the root/admin DB password to a value only Vault knows, so the copy in your config becomes useless
- C. It deletes the database connection so no credentials can be issued
- D. It re-encrypts the Vault storage backend with a new master key

<details><summary>Answer</summary>

**B** — rotate-root changes the configured admin credential to a new value known only to Vault, eliminating the human-known bootstrap password. It does not touch issued dynamic leases, delete the connection, or reseal Vault.

[Documentation](https://developer.hashicorp.com/vault/api-docs/secret/databases#rotate-root-credentials) · objectives: `vault-rotation`

</details>

### 8. A legacy third-party API only accepts one static API key that must be rotated on a schedule with zero-downtime, and you want history/rollback. Which Vault capability fits best?

- A. The KV v2 engine with versioning plus a scheduled rotation job that writes the new key as a new version
- B. The transit engine, since it rotates keys automatically
- C. A dynamic database role, reused for the API
- D. Storing the key in a Kubernetes Secret with an annotation

<details><summary>Answer</summary>

**A** — Static third-party secrets that can't be generated on demand live in KV v2, whose versioning gives history and rollback; rotation is a scheduled write of a new version (or an automated rotation for supported plugins). Transit encrypts data and doesn't store your external API key; dynamic DB roles don't apply to an opaque third-party key.

[Documentation](https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2) · objectives: `vault-rotation`

</details>

### 9. You want a pod to receive a Vault secret as a file at `/vault/secrets/config`, without the secret ever becoming a Kubernetes Secret object. Which delivery mechanism matches, and how is it triggered?

- A. The Secrets Store CSI driver, which always creates a synced Kubernetes Secret
- B. The Vault Agent Injector, via `vault.hashicorp.com/agent-inject` pod annotations that add a sidecar writing to an in-memory volume
- C. An init container that runs `kubectl create secret`
- D. envFrom referencing a Vault URL directly

<details><summary>Answer</summary>

**B** — The Vault Agent Injector mutates the pod to add an agent sidecar that authenticates and renders secrets into a shared in-memory (tmpfs) volume at /vault/secrets — no Kubernetes Secret is created. The CSI driver mounts secrets as a volume and only creates a synced K8s Secret if you explicitly enable secretObjects.

[Documentation](https://developer.hashicorp.com/vault/docs/platform/k8s/injector) · objectives: `vault-k8s`

</details>

### 10. Comparing the Vault Agent Injector and the Secrets Store CSI driver, a teammate claims they are interchangeable. Which distinction is correct?

- A. The CSI driver renders secrets to a tmpfs sidecar; the injector mounts a CSI volume
- B. The injector adds a sidecar/init container per pod and writes to a shared volume; the CSI driver mounts secrets through a SecretProviderClass as a CSI volume and can optionally sync a K8s Secret
- C. Only the CSI driver supports Kubernetes auth to Vault
- D. The injector requires the secret to first exist as a Kubernetes Secret

<details><summary>Answer</summary>

**B** — The injector is a mutating webhook that adds Vault Agent sidecar/init containers writing to a shared in-memory volume; the CSI driver uses a SecretProviderClass and the Secrets Store CSI interface to mount secrets as a volume, optionally syncing a Kubernetes Secret. Both can use Kubernetes auth; neither requires a pre-existing K8s Secret.

[Documentation](https://developer.hashicorp.com/vault/docs/platform/k8s/csi) · objectives: `vault-k8s`

</details>

### 11. Compliance asks for a tamper-evident record of every secret access in Vault, but is worried the log itself will leak secret values. What does enabling a Vault audit device (e.g. `vault audit enable file`) provide?

- A. A log with all request/response data in plaintext, so it must be encrypted separately
- B. A log where sensitive string values are HMAC'd with a per-Vault key, recording who/what/when without exposing the secret value
- C. Only failed requests, to reduce volume
- D. Metrics counters only, not per-request records

<details><summary>Answer</summary>

**B** — Audit devices record every authenticated request and response, but sensitive values are hashed (HMAC-SHA256 with an internal key) so the log proves access without disclosing the secret. Vault refuses to service requests if it cannot write to at least one enabled audit device.

[Documentation](https://developer.hashicorp.com/vault/docs/audit) · objectives: `vault-audit`

</details>

### 12. Developers want "encryption as a service" so application data is encrypted with a key that never leaves central control, and apps never handle raw key material. Which Vault engine and data flow is correct?

- A. The KV engine; the app fetches the key and encrypts locally
- B. The transit engine; the app sends plaintext to Vault, Vault returns ciphertext, and the key stays inside Vault
- C. The database engine; it encrypts columns transparently
- D. The PKI engine; it wraps data in a certificate

<details><summary>Answer</summary>

**B** — The transit engine performs cryptographic operations inside Vault: the app sends base64 plaintext to transit/encrypt/<key> and gets ciphertext back; the key material never leaves Vault. That is exactly the encryption-as-a-service / bring-your-own-crypto model. KV would hand the key to the app; database/PKI solve different problems.

[Documentation](https://developer.hashicorp.com/vault/docs/secrets/transit) · objectives: `key-transit`

</details>

### 13. After rotating a transit key with `vault write -f transit/keys/app/rotate`, old ciphertext prefixed `vault:v1:` must still decrypt while new writes use v2. What behavior of the transit engine supports this?

- A. Rotation deletes v1, so old ciphertext must be re-encrypted before rotating
- B. Each ciphertext carries a key-version prefix; Vault keeps prior versions to decrypt old data while encrypting new data with the latest version
- C. The app must store which key version it used
- D. Transit keys cannot be rotated once data is encrypted

<details><summary>Answer</summary>

**B** — Transit ciphertext is versioned (vault:v1:, vault:v2:, ...). Vault retains earlier key versions (down to min_decryption_version) so previously encrypted data still decrypts after rotation, while new encryptions use the latest version. You can later `rewrap` to upgrade old ciphertext.

[Documentation](https://developer.hashicorp.com/vault/docs/secrets/transit#key-rotation) · objectives: `key-transit`

</details>

### 14. An auditor requires that the root of trust protecting Vault's master key be a FIPS 140-2 validated HSM, integrated over PKCS#11. Which statement is accurate for planning this?

- A. Any open-source Vault build supports PKCS#11 HSM seal out of the box
- B. HSM auto-unseal / seal-wrap via PKCS#11 is a Vault Enterprise feature; a real HSM is a hardware root of trust, and SoftHSM is only for testing the integration
- C. The HSM stores every secret directly, replacing Vault storage
- D. PKCS#11 is only used for TLS on the listener, not for sealing

<details><summary>Answer</summary>

**B** — HSM-backed seal (and managed keys) over PKCS#11 is a Vault Enterprise capability; the HSM acts as the hardware root of trust wrapping the master key, analogous to Azure Managed HSM. SoftHSM can stand in for lab testing but is not a real root of trust. The HSM protects key material, not bulk secret storage.

[Documentation](https://developer.hashicorp.com/vault/docs/configuration/seal/pkcs11) · objectives: `key-hsm`

</details>

### 15. You want every Certificate resource in the cluster to be signed by a single internal CA you control, with no external ACME dependency. Which cert-manager objects do you create?

- A. An ACME ClusterIssuer pointing at Let's Encrypt
- B. A CA-type ClusterIssuer referencing a Secret that holds your CA key/cert, then Certificate resources referencing that issuer
- C. A self-signed Issuer in every namespace, one per app
- D. A SecretProviderClass mapping certs from Vault

<details><summary>Answer</summary>

**B** — A CA ClusterIssuer signs certificates from a CA key/cert stored in a Secret and is cluster-scoped so all namespaces can use it. ACME is for publicly-trusted certs via challenges; a bare self-signed issuer has no chain of trust; SecretProviderClass is CSI, not cert-manager issuance.

[Documentation](https://cert-manager.io/docs/configuration/ca/) · objectives: `cert-issuer`

</details>

### 16. An Ingress annotated with `cert-manager.io/cluster-issuer` and an ACME HTTP-01 issuer never gets a certificate; the Order is stuck pending. What is the most likely cause the exam expects?

- A. cert-manager requires the certificate to be created manually first
- B. The ACME HTTP-01 challenge path (/.well-known/acme-challenge/) is not reachable from the ACME server, so the domain can't be validated
- C. ClusterIssuers cannot be referenced from an Ingress
- D. The Certificate needs a Vault transit key to sign

<details><summary>Answer</summary>

**B** — HTTP-01 validation requires the ACME server to reach the solver at http://<domain>/.well-known/acme-challenge/<token>. If ingress/DNS/ firewalling blocks that path, the challenge stays pending and no cert is issued. ClusterIssuers are referenceable from Ingress via annotation, and issuance doesn't require manual certs or transit.

[Documentation](https://cert-manager.io/docs/configuration/acme/http01/) · objectives: `cert-issuer`

</details>

### 17. A Certificate has `duration: 24h` and `renewBefore: 8h`. A colleague worries someone must manually reissue it daily. What does cert-manager actually do?

- A. Nothing automatic — you must run cmctl renew each day
- B. It automatically reissues and updates the Secret roughly 8h before expiry, rotating tls.crt/tls.key with no manual action
- C. It emails an operator when the cert expires
- D. It revokes the cert at 24h and stops serving TLS

<details><summary>Answer</summary>

**B** — cert-manager continuously reconciles Certificate resources and renews automatically at duration minus renewBefore (here ~16h in), writing the new key pair into the referenced Secret. cmctl renew only forces an early renewal; day-to-day renewal is automatic.

[Documentation](https://cert-manager.io/docs/usage/certificate/) · objectives: `cert-lifecycle`

</details>

### 18. Two pods in namespace `oss500-apps` can currently reach each other. You apply a NetworkPolicy that selects all pods with an empty podSelector and lists `policyTypes: [Ingress]` with no ingress rules. What is the result?

- A. Nothing changes — an empty policy is ignored
- B. All ingress to every pod in the namespace is denied (default-deny ingress), so cross-pod curls now time out
- C. All egress is denied but ingress is unaffected
- D. Only traffic from other namespaces is denied

<details><summary>Answer</summary>

**B** — A policy selecting all pods with Ingress in policyTypes and no ingress rules is the canonical default-deny-ingress: once any policy selects a pod, only explicitly allowed traffic is permitted, so with no allow rules all inbound is dropped. Egress is untouched unless you also default-deny egress.

[Documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/) · objectives: `net-policy`

</details>

### 19. After applying a default-deny-egress NetworkPolicy, your pods can no longer resolve service names. Which two facts explain and fix this? (Select two)

- A. Default-deny egress also blocks DNS to kube-dns/CoreDNS unless you add an egress allow rule for it
- B. You must add an egress rule permitting UDP/TCP 53 to the kube-system DNS pods (or namespace) label
- C. NetworkPolicy never affects DNS, so the cause is unrelated
- D. DNS is exempt from all NetworkPolicies by design

<details><summary>Answer</summary>

**A, B** (multiple answers) — DNS is ordinary egress traffic; a default-deny-egress policy blocks it too, which is a classic footgun. The fix is an explicit egress rule allowing port 53 (UDP and TCP) to the DNS pods, typically via a namespaceSelector/podSelector for kube-system CoreDNS. NetworkPolicies are not DNS-exempt.

[Documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-egress-traffic) · objectives: `net-policy`

</details>

### 20. Security wants all service-to-service traffic in a namespace to be mutually authenticated and encrypted, rejecting any plaintext, using workload identity rather than IPs. Which Istio configuration enforces this?

- A. A NetworkPolicy with default-deny ingress
- B. A PeerAuthentication with mtls mode STRICT for the namespace
- C. An Ingress with TLS termination
- D. A transit key encrypting the payloads

<details><summary>Answer</summary>

**B** — PeerAuthentication in STRICT mode requires mTLS for all sidecar traffic in scope, rejecting plaintext, with identity carried in the SPIFFE certificate issued to each workload. NetworkPolicy filters by label/IP/port but doesn't do mTLS; ingress TLS is north-south only.

[Documentation](https://istio.io/latest/docs/tasks/security/authentication/authn-policy/) · objectives: `net-mesh`

</details>

### 21. With mTLS in STRICT mode enabled mesh-wide, you now need "service A may call service B, but service C may not," based on workload identity. Which mesh object expresses this, and what identity does it match on?

- A. A NetworkPolicy matching pod IP ranges
- B. An Istio AuthorizationPolicy allowing the source principal (SPIFFE identity/ServiceAccount) of A to B, denying others
- C. A PeerAuthentication per service
- D. An Ingress annotation restricting source namespaces

<details><summary>Answer</summary>

**B** — AuthorizationPolicy makes identity-aware allow/deny decisions on the authenticated principal (the SPIFFE ID derived from the workload's ServiceAccount), enabling least-privilege east-west authorization. PeerAuthentication governs whether mTLS is required, not who may call whom.

[Documentation](https://istio.io/latest/docs/tasks/security/authorization/authz-http/) · objectives: `net-mesh`

</details>

### 22. You expose an internal app through ingress-nginx and want TLS terminated at the ingress using an automatically issued and renewed certificate. What is the minimal correct wiring?

- A. Manually create a tls Secret and rotate it by hand each renewal
- B. Add a `cert-manager.io/cluster-issuer` annotation and a `tls:` block to the Ingress so cert-manager issues and renews the referenced Secret
- C. Enable ModSecurity, which provides the certificate
- D. Set the Service type to LoadBalancer with TLS passthrough

<details><summary>Answer</summary>

**B** — The Ingress tls block names a Secret and host; the cert-manager.io/cluster-issuer annotation makes cert-manager issue and auto-renew that Secret. TLS then terminates at ingress-nginx. Manual Secrets don't auto-renew; ModSecurity is a WAF, not a cert source; passthrough would move TLS to the backend.

[Documentation](https://cert-manager.io/docs/usage/ingress/) · objectives: `net-ingress`

</details>

### 23. Beyond TLS, an internal dashboard behind ingress-nginx must require authentication before requests reach the backend, without modifying the app. Which ingress-nginx capability is the intended answer?

- A. The `nginx.ingress.kubernetes.io/auth-url` external-auth annotation delegating auth to a forward-auth service such as oauth2-proxy
- B. A NetworkPolicy allowing only authenticated pods
- C. A PeerAuthentication STRICT policy
- D. Enabling the OWASP CRS

<details><summary>Answer</summary>

**A** — ingress-nginx external authentication (auth-url / forward-auth) sends a subrequest to an auth service (e.g. oauth2-proxy fronting an OIDC provider); only a 2xx lets the request through, adding authenticated access without app changes. NetworkPolicy/mTLS/WAF address different layers.

[Documentation](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#external-authentication) · objectives: `net-ingress`

</details>

### 24. In the perimeter-firewall walkthrough (OPNsense/pfSense/nftables), how does a stateful firewall's default posture differ from a Kubernetes NetworkPolicy, conceptually?

- A. Both default to deny with no configuration
- B. A stateful perimeter firewall filters north-south traffic at the network edge with explicit rules and connection tracking, while NetworkPolicy segments east-west pod traffic inside the cluster; both express default-deny + explicit-allow
- C. NetworkPolicy replaces the need for any perimeter firewall
- D. A perimeter firewall inspects application-layer payloads by default, like a WAF

<details><summary>Answer</summary>

**B** — A perimeter/host firewall governs edge (north-south) traffic with stateful connection tracking and explicit rules; NetworkPolicy segments in-cluster east-west traffic by label. They are complementary layers, and both are strongest as default-deny with explicit allows. A stateful L3/L4 firewall is not an L7 WAF.

[Documentation](https://docs.opnsense.org/manual/firewall.html) · objectives: `net-firewall`

</details>

### 25. You enable ModSecurity on an ingress-nginx Ingress but attacks still succeed; the audit log shows the rules matched. You find the config set `SecRuleEngine DetectionOnly`. What is happening and what changes it to blocking?

- A. DetectionOnly blocks but doesn't log; switch to On to add logging
- B. DetectionOnly evaluates and logs rule matches but does not block; set `SecRuleEngine On` to actually reject offending requests
- C. The rules are disabled entirely; re-enable them
- D. ModSecurity only works on HTTP, so enable it for HTTPS

<details><summary>Answer</summary>

**B** — DetectionOnly is a monitor mode: rules evaluate and log but no request is blocked — useful for tuning. SecRuleEngine On enforces, returning 403 on anomaly. This is the classic detect-vs-prevent distinction (mirrors Azure WAF Detection vs Prevention).

[Documentation](https://kubernetes.github.io/ingress-nginx/user-guide/third-party-addons/modsecurity/) · objectives: `waf-deploy`

</details>

### 26. After enabling the OWASP Core Rule Set on your WAF, legitimate requests with rich JSON bodies start getting blocked. You are at paranoia level 3. What is the correct first tuning move?

- A. Disable the CRS entirely
- B. Lower the paranoia level (e.g. to PL1) and/or add targeted rule exclusions, since higher paranoia levels trade more false positives for more coverage
- C. Raise the anomaly threshold to 0 so nothing scores
- D. Switch to DetectionOnly permanently

<details><summary>Answer</summary>

**B** — CRS paranoia levels (PL1–PL4) increase detection aggressiveness at the cost of false positives; PL1 is the recommended starting point. Tune by lowering PL and adding scoped exclusions for known-good traffic, not by disabling the rule set or zeroing the scoring. DetectionOnly stops protection.

[Documentation](https://coreruleset.org/docs/concepts/paranoia_levels/) · objectives: `waf-rules`

</details>

### 27. The OWASP CRS uses anomaly scoring. What does that mean for how a request is blocked, versus a rule-per-block model?

- A. Every matching rule immediately blocks the request
- B. Each matching rule adds to an anomaly score; the request is blocked only when the inbound (or outbound) score crosses a configured threshold
- C. Only the last rule in the chain decides
- D. Scoring is advisory and never blocks

<details><summary>Answer</summary>

**B** — CRS (collaborative detection / anomaly scoring mode) accumulates a score across matched rules and blocks when the inbound_anomaly_score_threshold is exceeded, reducing single-rule false positives and letting you tune the threshold. It does block once the threshold is crossed.

[Documentation](https://coreruleset.org/docs/concepts/anomaly_scoring/) · objectives: `waf-rules`

</details>

### 28. To prove the WAF works, you send `GET /?id=1' OR '1'='1` and expect it to be stopped. With CRS enforcing, what do you observe, and where do you confirm the reason?

- A. A 200 with the payload reflected; confirm in the app logs
- B. An HTTP 403 from the WAF; the ModSecurity audit log shows the matched SQLi rule id and the anomaly score
- C. A 500 error with no log entry
- D. A redirect to the login page

<details><summary>Answer</summary>

**B** — An enforcing CRS returns 403 for the SQL-injection pattern, and the ModSecurity audit log records the triggered rule id(s) and accumulated anomaly score — the observable proof the control worked. A 200 would mean the WAF isn't enforcing.

[Documentation](https://coreruleset.org/docs/development/testing/) · objectives: `waf-verify`

</details>

### 29. A single CRS rule keeps blocking a legitimate endpoint (a confirmed false positive), but you want to keep the rest of the rule set enforcing. What is the surgical fix?

- A. Set SecRuleEngine DetectionOnly globally
- B. Add a scoped exclusion / `SecRuleRemoveById` for that specific rule id (ideally only on that route), leaving the rest of CRS active
- C. Drop the paranoia level to 0
- D. Delete the ModSecurity module

<details><summary>Answer</summary>

**B** — False positives are handled with targeted exclusions — removing or relaxing the specific offending rule id (scoped to the affected path via ctl:ruleRemoveById) — so overall protection stays on. Disabling enforcement globally or gutting the rule set overcorrects.

[Documentation](https://coreruleset.org/docs/concepts/false_positives_tuning/) · objectives: `waf-verify`

</details>

### 30. A colleague says Kubernetes Secrets are safe because kubectl shows them base64-encoded. You dump the raw etcd key for a Secret and read the value in cleartext. What actually encrypts Secrets at rest?

- A. Base64 encoding is encryption once RBAC is applied
- B. An EncryptionConfiguration on the kube-apiserver (aescbc/secretbox or a KMS provider) so Secrets are stored as ciphertext in etcd
- C. Enabling TLS on the etcd peer port
- D. Setting the Secret's type to Opaque

<details><summary>Answer</summary>

**B** — Base64 is encoding, not encryption — anyone reading etcd sees the value. Encryption at rest requires the apiserver's --encryption-provider-config pointing at an EncryptionConfiguration (aescbc/secretbox for a local key, or a KMS provider like Vault for an external key), after which etcd holds k8s:enc: ciphertext. TLS on etcd protects in-transit, not at-rest.

[Documentation](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/) · objectives: `data-encrypt`

</details>

### 31. You just added an EncryptionConfiguration and restarted the apiserver. Which two things are true about Secrets that already existed? (Select two)

- A. Existing Secrets remain stored in their prior (plaintext) form until they are rewritten
- B. Running `kubectl get secrets -A -o json | kubectl replace -f -` re-encrypts existing Secrets by rewriting them
- C. All existing Secrets are re-encrypted instantly on apiserver restart
- D. You must delete and recreate every Secret manually to encrypt them

<details><summary>Answer</summary>

**A, B** (multiple answers) — Encryption applies on write, so pre-existing Secrets stay in their old form until updated. The standard remediation is to force a rewrite of all Secrets (kubectl get ... | kubectl replace -f -) so they are re-persisted under the new provider. A restart alone does not re-encrypt old data, and manual delete/recreate is unnecessary.

[Documentation](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#ensure-all-secrets-are-encrypted) · objectives: `data-encrypt`

</details>

### 32. Before shipping, you want to catch AWS keys and other credentials committed to a git repository, including in past history. Which tool and invocation fits?

- A. Trivy image scanning, which only inspects running containers
- B. Gitleaks, e.g. `gitleaks detect --source .`, which scans the working tree and git history for secret patterns
- C. kubectl get secrets, to list what's exposed
- D. ModSecurity audit logs

<details><summary>Answer</summary>

**B** — Gitleaks scans repositories (working tree and commit history) with regex/ entropy rules to find committed credentials, and runs well as a pre-commit or CI gate. Trivy scans images/filesystems (it also has a secret scanner), but history-aware git scanning is Gitleaks' niche; kubectl and WAF logs don't scan source.

[Documentation](https://github.com/gitleaks/gitleaks) · objectives: `data-secretscan`

</details>

### 33. You want a single tool in CI to scan a built container image for both known CVEs and embedded plaintext secrets (like a baked-in token). Which command matches?

- A. `gitleaks detect` on the image tarball only
- B. `trivy image <image>`, which reports vulnerabilities and, with its secret scanner, embedded secrets
- C. `kubectl describe pod`
- D. `vault kv get` against the registry

<details><summary>Answer</summary>

**B** — Trivy scans container images (and filesystems/repos) for vulnerabilities and, via its built-in secret scanner, for embedded plaintext secrets in one pass — ideal as a CI gate. Gitleaks targets git repos; kubectl and Vault are unrelated to image scanning.

[Documentation](https://github.com/aquasecurity/trivy) · objectives: `data-secretscan`

</details>

### 34. An app's Vault token can read `secret/data/app/*` but a developer reports it returns 403 on `secret/data/finance/db`. Before changing anything, how do you confirm what the token is allowed to do, and where would the denied attempt be recorded?

- A. Grant the token root to test, then narrow later
- B. Use `vault token capabilities <token> secret/data/finance/db` to check its policy result; the denied request is captured in the audit device log
- C. Read the Kubernetes RBAC RoleBinding for the pod
- D. Restart Vault to reset the token's permissions

<details><summary>Answer</summary>

**B** — vault token capabilities shows the effective capabilities a token has on a path from its attached policies, confirming the 403 is expected least-privilege behavior rather than a bug; the denied access is logged by the enabled audit device. Granting root or restarting Vault are both wrong responses.

[Documentation](https://developer.hashicorp.com/vault/docs/concepts/policies#testing-vault-policies) · objectives: `vault-access`, `vault-audit`

</details>

### 35. You create a kind cluster with `disableDefaultCNI: true` and `kubeProxyMode: none` to run Cilium. The nodes sit `NotReady` and CoreDNS is `Pending`. A teammate says the cluster is broken. What is actually happening?

- A. kube-proxy must be reinstalled or nodes never go Ready
- B. There is no CNI yet — nodes stay NotReady until Cilium is installed as the dataplane, after which they go Ready and CoreDNS schedules
- C. The podSubnet is wrong and must match the service CIDR
- D. Docker Desktop cannot run kind with a custom CNI

<details><summary>Answer</summary>

**B** — disableDefaultCNI intentionally leaves the cluster with no dataplane, so nodes report NotReady and pods that need networking stay Pending until a CNI is installed. Installing Cilium (kubeProxyReplacement handles the absent kube-proxy) makes the nodes Ready. This is why Cilium must be installed before the shared namespace/ingress bootstrap.

[Documentation](https://docs.cilium.io/en/stable/installation/kind/) · objectives: `fab-cni`

</details>

### 36. A partner will only accept traffic from an allowlisted source IP, but your pods currently egress with whatever node they land on. Which Cilium construct gives selected pods a fixed, known egress IP, and what is its cloud equivalent?

- A. A LoadBalancer Service, which assigns a stable ingress IP — the NAT gateway analog
- B. A CiliumEgressGatewayPolicy that SNATs the selected pods to a gateway node's IP — the NAT-gateway / controlled-egress analog
- C. A NetworkPolicy egress rule, which rewrites the source IP
- D. An Ingress with a fixed external IP annotation

<details><summary>Answer</summary>

**B** — CiliumEgressGatewayPolicy selects pods (by label/namespace) and routes their outbound traffic through a designated gateway node, SNAT'ing to that node's IP so an external listener always sees the same, allowlist-friendly source — the open-source NAT gateway. LoadBalancer/Ingress concern inbound IPs; NetworkPolicy filters but does not SNAT.

[Documentation](https://docs.cilium.io/en/stable/network/egress-gateway/egress-gateway/) · objectives: `fab-egress`

</details>

### 37. You apply a Cilium FQDN policy allowing egress only to `docs.cilium.io:443` for a pod, but every outbound request — even to the allowed name — now fails to resolve. What is the most likely omission?

- A. toFQDNs cannot be combined with any other egress rule
- B. The policy must also allow DNS to CoreDNS with a `dns:` match rule, since the FQDN allowlist is populated from the DNS answers the proxy observes
- C. FQDN policy requires the pod to run as root
- D. docs.cilium.io must be added to /etc/hosts on every node

<details><summary>Answer</summary>

**B** — Cilium's FQDN enforcement works by watching the pod's DNS responses and pinning the resolved IPs into the allowlist. If the policy doesn't permit DNS to kube-dns with a dns rule (matchPattern), resolution is blocked and the toFQDNs set never populates — the #1 FQDN footgun. Allow DNS first, then the FQDN rule matches on the returned name.

[Documentation](https://docs.cilium.io/en/stable/security/policy/language/#dns-based) · objectives: `fab-fqdn`

</details>

### 38. After applying an FQDN egress policy you want to prove, at the network layer, that a request to a non-allowlisted domain was dropped and by which policy. Which Cilium tool shows this, and what makes it more useful than raw NSG-style IP logs?

- A. kubectl describe networkpolicy, which lists recent drops
- B. Hubble (`hubble observe --verdict DROPPED`), which shows flows with source/destination workload identity and the deciding verdict, not just IPs
- C. cilium status, which prints per-flow verdicts
- D. The CoreDNS log, which records blocked connections

<details><summary>Answer</summary>

**B** — Hubble is Cilium's flow-observability layer: because Cilium sees packets in eBPF with workload identity attached, Hubble reports each flow by source/dest identity and its FORWARDED/DROPPED verdict (and the policy), which is the identity-attributed equivalent of NSG/VNet flow logs — far easier to read than reverse-engineering ephemeral pod IPs.

[Documentation](https://docs.cilium.io/en/stable/observability/hubble/) · objectives: `fab-flowlogs`

</details>

### 39. You connect two clusters with Cilium Cluster Mesh (the VNet-peering analog). A colleague assumes that once peered, workloads in cluster A can freely reach workloads in cluster B. Which two statements are correct? (Select two)

- A. The clusters must have non-overlapping PodCIDRs and unique cluster IDs or the mesh won't form
- B. Peering provides routing/discovery but reachability is still governed by CiliumNetworkPolicy — default-deny across the mesh is the secure posture
- C. Peering automatically trusts all traffic between the two clusters
- D. Overlapping PodCIDRs are fine because Cilium NATs between clusters

<details><summary>Answer</summary>

**A, B** — Cluster Mesh requires non-overlapping PodCIDRs and unique cluster names/IDs for unambiguous cross-cluster routing. Like Azure VNet peering, it grants connectivity and service discovery, not trust: a CiliumNetworkPolicy on the remote identity still decides who may call whom, and default-deny is the zero-trust posture (NIST 800-207).

[Documentation](https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/) · objectives: `fab-peering`

</details>

### 40. Mapping open-source controls to Azure, which pairing is correct for the cloud-network fabric?

- A. Cilium Egress Gateway ≈ Azure WAF; Cilium FQDN policy ≈ NSG
- B. Cilium Egress Gateway ≈ Azure NAT Gateway (controlled egress); Cilium FQDN policy ≈ Azure Firewall application rules
- C. Cilium Egress Gateway ≈ Azure Front Door; Hubble ≈ Azure Firewall
- D. Cilium FQDN policy ≈ Azure Private Link; Egress Gateway ≈ Application Gateway

<details><summary>Answer</summary>

**B** — The egress gateway pins a fixed outbound SNAT IP — the NAT-gateway / controlled-egress control. FQDN egress policy allows traffic by DNS name and denies the rest — Azure Firewall application (FQDN) rules. WAF inspects HTTP payloads (a different layer), NSG is L3/4 micro-segmentation, and Private Link/Front Door/App Gateway solve inbound or backbone-connectivity problems, not egress control.

[Documentation](https://learn.microsoft.com/en-us/azure/firewall/features#application-fqdn-filtering-rules) · objectives: `fab-egress`, `fab-fqdn`

</details>
