# Lab d2: Certificate lifecycle with cert-manager + Vault transit

Encrypt data without ever holding the key (Vault transit), then let cert-manager issue and auto-renew a TLS certificate the way Key Vault manages a certificate's whole life.

**Objectives covered**

| id | Objective |
|---|---|
| `key-transit` | Provide encryption-as-a-service and manage encryption keys |
| `cert-issuer` | Automate certificate issuance with cluster issuers and ACME |
| `cert-lifecycle` | Manage certificate renewal, rotation, and revocation |
| `key-hsm` | Integrate an HSM as a root of trust for key material *(walkthrough)* |

**SC-500 correspondence**: Key Vault keys / encryption (transit) · Key Vault certificates & certificate lifecycle management (cert-manager) · Managed HSM (HSM root of trust)

**Prerequisites**

- [`lab-infra/certs`](../lab-infra/certs/) up (`./up.sh`) — cert-manager in `oss500-secrets`, plus `cmctl`.
- [`lab-infra/secrets`](../lab-infra/secrets/) up for Part A (Vault transit engine).
- Notes read: [keys-and-certificates.md](../domains/2-secrets-data-networking/keys-and-certificates.md).

**Estimated time**: 2–2.5 h · $0 (local)

## Challenge

Reach four outcomes — this is a **guided build**: you run the Vault commands and write the cert-manager YAML yourself, then check against the reference solution.

1. **`key-transit`** — Turn Vault into encryption-as-a-service: plaintext goes in, ciphertext comes out, and the key material never leaves Vault. Prove it by rotating the key and showing old ciphertext still decrypts while new encryptions carry a newer key-version prefix.
2. **`cert-issuer`** — Stand up a certificate-authority chain inside the cluster (a self-signed root, then an issuer that signs from it) and get a leaf certificate issued for a demo service into a TLS `Secret` cert-manager manages.
3. **`cert-lifecycle`** — Force a renewal and prove the certificate actually rotated (a later `notAfter` in the same Secret), then simulate revocation of a private-CA leaf by deleting it and watching cert-manager re-issue.
4. **`key-hsm`** *(walkthrough)* — Without a real HSM on hand, be able to explain how Vault would use one as a root of trust (auto-unseal / PKCS#11 seal) and map it to the Key Vault Premium vs Managed HSM exam distinction.

The observable to reach for each (exact check in Verification): a transit round-trip plus a `vault:v1:` → `vault:v2:` rotation where the old ciphertext still decrypts; `demo-tls` reaching `READY True` with a valid issuer chain; and a later `notAfter` in the same Secret after a forced renewal. No finished YAML or Vault commands below — build them yourself in **Build it (guided)**, then check your work against **Reference solution**.

## Build it (guided)

### Part A — Encryption-as-a-service with Vault transit (`key-transit`)

The transit engine is Vault's "encryption-as-a-service": the **key never leaves Vault**, callers send plaintext and get ciphertext back — exactly what a Key Vault *key* (wrap/unwrap, encrypt/decrypt) does, versus a *secret* that just stores bytes.

1. **Enable transit and create a named key.** Exec into the Vault pod (`kubectl -n oss500-secrets exec -it statefulset/vault -- sh`) and turn on the transit secrets engine, then create a named key — pick any name (the reference solution uses `app-data`). Hint: it's `vault secrets enable <engine>` and `vault write -f transit/keys/<name>`. Before you run it, predict: what algorithm does Vault default to, and is the key exportable? Your turn — get both commands running and confirm the key exists with `vault list transit/keys`.
2. **Encrypt some plaintext.** Transit's `encrypt` endpoint takes base64-encoded input, not raw text, so base64-encode your string first (`echo -n "<your string>" | base64`) and pass it as `plaintext=` to `vault write transit/encrypt/<key>`. Your turn — encrypt any string you like, then look closely at the ciphertext you get back: what does the `vault:vN:` prefix at the front tell you?
3. **Decrypt to prove the round-trip** — and that you never touched the key itself. Feed the ciphertext to the matching `decrypt` endpoint; the `plaintext` you get back is base64-encoded, so you'll need `base64 -d` to read it. Confirm it matches what you started with.
4. **Rotate the key and watch the version change.** There's a `rotate` action on the key path — find it, run it, then encrypt something new. Before you check: will the new ciphertext's version prefix be higher than before, and — critically — does the *old* `v1` ciphertext from step 3 still decrypt after rotation? Try it and see whether Vault kept the prior key version around.
5. **(Optional) Rewrap old ciphertext to the newest key version — without ever exposing the plaintext.** There's a `rewrap` endpoint that takes old ciphertext and returns it re-encrypted under the current key version. This is precisely the "customer-managed key rotates; re-wrap the data-encryption key" flow, done server-side — find the endpoint and try it on your `v1` ciphertext.

### Part B — Issue a certificate with a ClusterIssuer (`cert-issuer`)

cert-manager is the Kubernetes-native certificate authority integration: an **Issuer/ClusterIssuer** is the CA source (self-signed, a private CA, Vault, or ACME/Let's Encrypt), and a **Certificate** resource is the desired cert — cert-manager reconciles it into a TLS `Secret`, the Key Vault "certificate object" analogue.

6. **Build the CA chain: a self-signed root, then an issuer that signs from it.** You need three objects, wired together (a realistic private-CA chain; ACME/Let's Encrypt is the same shape but needs a public DNS name):
   - a `ClusterIssuer` with `selfSigned: {}` — bootstraps itself, no parent CA needed.
   - a `Certificate` with `isCA: true` (the root CA cert), signed by that ClusterIssuer, landing in a Secret you name via `secretName`.
   - a second `ClusterIssuer` whose `spec.ca.secretName` points at that same Secret — this is the one that will sign your leaf certs.

   Sketch the chain before you write the YAML:
   ```
   selfSigned ClusterIssuer  --signs-->  Certificate (isCA: true, secretName: X)
   ClusterIssuer { ca: { secretName: X } }  --signs leaves--> ...
   ```
   Your turn — write `issuer.yaml` with all three objects, `kubectl apply` it, and confirm your leaf-signing `ClusterIssuer` reaches `READY True` (`kubectl get clusterissuer`).
7. **Request a leaf certificate for a demo service.** Goal: a `Certificate` named `demo-tls` in `oss500-apps`, issued by the `ClusterIssuer` you just built, that cert-manager reconciles into a Secret containing `tls.crt`/`tls.key`. Two fields matter for what comes next in Part C:
   - `duration` — short enough to watch a renewal happen in one sitting (hours, not the usual 90 days).
   - `renewBefore` — cert-lifecycle: cert-manager renews once roughly half the cert's life remains, so this should land around half of `duration`.

   Your turn — write `cert.yaml` (pick a `commonName`/`dnsNames`, e.g. something under `.localtest.me`, which resolves to loopback with no `/etc/hosts` edits needed), apply it, and confirm `kubectl -n oss500-apps get certificate demo-tls` shows `READY True`.
8. **Inspect the issued cert inside the Secret cert-manager created:**
   ```bash
   kubectl -n oss500-apps get secret demo-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -issuer -dates
   ```
   Confirm the `subject` is your hostname and the `issuer` is your CA's `commonName`. This `demo-tls` Secret is what the ingress lab ([d2-ingress-waf](d2-ingress-waf.md)) terminates TLS with.

### Part C — Renewal, rotation & revocation (`cert-lifecycle`)

9. **Force a renewal instead of waiting for `renewBefore`.** cert-manager renews **automatically** at `renewBefore`, but `cmctl` (the cert-manager CLI) has a `renew` subcommand so you can watch the machinery now instead of waiting. Run it against `demo-tls`, then use `cmctl status certificate` to see the issuance history and next renewal time.
10. **Confirm the rotation actually happened.** Re-run the `openssl x509 -noout -dates` inspection from step 8 against the same Secret — a **new `notAfter`** should show up, in the same Secret name (consumers watching that Secret pick up the fresh cert/key on reload, no re-pointing needed).
11. **Simulate revocation.** cert-manager has no CRL for a private CA, so revocation in practice means rotating the leaf — delete the Secret and let cert-manager re-issue — or rotating the issuing CA itself and letting all leaves re-issue. For public ACME certs, revocation is a CA-side operation instead. Your turn — delete the `demo-tls` Secret and watch (`-w`) the `Certificate` re-issue into a fresh Secret.

### Part D — HSM as root of trust (`key-hsm`) — walkthrough

*Impractical on a single laptop host (needs a real HSM or a PKCS#11 stack + Vault Enterprise for HSM auto-unseal), but studied at the same depth — this is the Managed HSM analogue.*

12. **Why**: an HSM keeps key material in tamper-resistant hardware; keys are non-exportable and crypto happens inside the device (FIPS 140-2/3). It is the *root of trust* — in Vault, an HSM can **auto-unseal** Vault (wrapping the master key) and/or back the PKI/transit keys via **PKCS#11 seal**.
13. **Config shape** (Vault Enterprise `seal "pkcs11"` stanza) — read this as directions, not something to run locally:
    ```hcl
    seal "pkcs11" {
      lib            = "/usr/lib/softhsm/libsofthsm2.so"   # or a real vendor lib
      slot           = "0"
      pin            = "1234"
      key_label      = "vault-hsm-key"
      hmac_key_label = "vault-hsm-hmac"
    }
    ```
    With this, Vault's seal key never exists in plaintext outside the HSM — restart no longer needs Shamir shares; the HSM unwraps it.
14. **Local approximation only**: `softhsm2-util --init-token` creates a *software* PKCS#11 token to exercise the plumbing, but it is not a hardware root of trust — so this stays a walkthrough. The exam mapping: **Key Vault Premium = HSM-backed keys on shared HSMs; Managed HSM = single-tenant, dedicated, local RBAC** — Vault + PKCS#11 is how you'd achieve the equivalent on-prem.

## Verification

- **Transit round-trips**: `transit/encrypt` returns `vault:v1:...` ciphertext, `transit/decrypt` recovers the original plaintext, and after `rotate` new ciphertext carries `vault:v2:` while old ciphertext still decrypts — the key never left Vault.
- **Issuance**: `kubectl get certificate demo-tls` shows `READY True` and the `demo-tls` Secret contains a valid `tls.crt` whose issuer is your CA.
- **Auto-renewal**: after `cmctl renew` (or crossing `renewBefore`), `openssl x509 -dates` shows a **later `notAfter`** in the same Secret — the cert rotated without manual reissue.

## Reference solution

Build it yourself first; check after.

### Part A — Vault transit

```bash
kubectl -n oss500-secrets exec -it statefulset/vault -- sh
vault secrets enable transit
vault write -f transit/keys/app-data      # AES-256-GCM by default; exportable=false — key material stays in Vault
```
```bash
vault write transit/encrypt/app-data plaintext=$(echo -n "cardholder-4111" | base64)
# ciphertext   vault:v1:xxxxxxxxxxxxxxxxxxxx...
```
Note the **`vault:v1:` prefix** — the key version that produced this ciphertext.
```bash
vault write transit/decrypt/app-data ciphertext="vault:v1:xxxx..."
# plaintext   Y2FyZGhvbGRlci00MTEx   ->  echo ...| base64 -d  ->  cardholder-4111
```
Rotate the key and observe versioning. New encryptions use `v2`; old `vault:v1:` ciphertext still decrypts (Vault keeps prior versions):
```bash
vault write -f transit/keys/app-data/rotate
vault write transit/encrypt/app-data plaintext=$(echo -n "new-data" | base64)
# ciphertext   vault:v2:yyyy...        <- new version prefix
```
`rewrap` upgrades old ciphertext to the newest key version *without exposing plaintext* — the pattern for CMK rotation across a data store:
```bash
vault write transit/rewrap/app-data ciphertext="vault:v1:xxxx..."   # -> vault:v2:...
```

### Part B — ClusterIssuer chain + leaf certificate

```yaml
# issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: { name: selfsigned-root }
spec: { selfSigned: {} }
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: { name: oss500-ca, namespace: oss500-secrets }
spec:
  isCA: true
  commonName: oss500-ca
  secretName: oss500-ca-tls
  issuerRef: { name: selfsigned-root, kind: ClusterIssuer }
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: { name: oss500-ca-issuer }
spec:
  ca: { secretName: oss500-ca-tls }
```
```bash
kubectl apply -f issuer.yaml
kubectl get clusterissuer            # oss500-ca-issuer -> READY True
```
```yaml
# cert.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: { name: demo-tls, namespace: oss500-apps, labels: { app.kubernetes.io/part-of: oss500 } }
spec:
  secretName: demo-tls                 # cert-manager writes tls.crt / tls.key here
  duration: 24h                        # short, to watch lifecycle in Part C
  renewBefore: 12h                     # cert-lifecycle: renew when half its life remains
  commonName: demo.localtest.me
  dnsNames: ["demo.localtest.me"]
  issuerRef: { name: oss500-ca-issuer, kind: ClusterIssuer }
```
```bash
kubectl apply -f cert.yaml
kubectl -n oss500-apps get certificate demo-tls        # READY True
```
Inspect the issued cert inside the Secret cert-manager created:
```bash
kubectl -n oss500-apps get secret demo-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -issuer -dates
# subject=CN=demo.localtest.me / issuer=CN=oss500-ca / notBefore.. notAfter (24h out)
```
This `demo-tls` Secret is what the ingress lab ([d2-ingress-waf](d2-ingress-waf.md)) terminates TLS with.

### Part C — Renewal, rotation & revocation

cert-manager renews **automatically** at `renewBefore`. Force it now to watch the machinery instead of waiting:
```bash
cmctl renew demo-tls -n oss500-apps
cmctl status certificate demo-tls -n oss500-apps    # shows issuance, next renewal time, events
```
Confirm rotation happened — a **new `notAfter`** and a fresh key in the same Secret (consumers auto-pick it up on reload):
```bash
kubectl -n oss500-apps get secret demo-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
# notAfter has moved forward -> the cert rotated
```
**Revocation / rotation of trust**: cert-manager has no CRL for a private CA, so revocation in practice = rotate the leaf (delete the Secret; cert-manager re-issues) or rotate the issuing CA and let all leaves re-issue. For public ACME certs, revocation is a CA-side operation. Delete the Secret and watch re-issue:
```bash
kubectl -n oss500-apps delete secret demo-tls
kubectl -n oss500-apps get certificate demo-tls -w    # cert-manager re-issues into a new Secret
```

### Part D — HSM as root of trust (walkthrough reference)

An HSM keeps key material in tamper-resistant hardware; keys are non-exportable and crypto happens inside the device (FIPS 140-2/3) — the *root of trust*. In Vault, an HSM can **auto-unseal** Vault (wrapping the master key) and/or back the PKI/transit keys via **PKCS#11 seal**:
```hcl
seal "pkcs11" {
  lib            = "/usr/lib/softhsm/libsofthsm2.so"   # or a real vendor lib
  slot           = "0"
  pin            = "1234"
  key_label      = "vault-hsm-key"
  hmac_key_label = "vault-hsm-hmac"
}
```
With this, Vault's seal key never exists in plaintext outside the HSM — restart no longer needs Shamir shares; the HSM unwraps it. `softhsm2-util --init-token` creates a *software* PKCS#11 token to exercise the plumbing locally, but it is not a hardware root of trust, so this stays a walkthrough. Exam mapping: **Key Vault Premium = HSM-backed keys on shared HSMs; Managed HSM = single-tenant, dedicated, local RBAC** — Vault + PKCS#11 is how you'd achieve the equivalent on-prem.

## Teardown

- `cd lab-infra/certs && ./down.sh` (and `cd lab-infra/secrets && ./down.sh` if you brought Vault up only for Part A)

## What the exam asks

- **Key vs secret**: encryption-as-a-service where the key *never leaves* the store (transit / Key Vault keys) is the answer when the scenario says "the app must encrypt/decrypt but must never possess the key." A stored blob is a *secret*, not a key.
- **Key/cert versions & rotation**: rotating a transit/CMK key produces a new version; existing ciphertext is re-wrapped, not re-encrypted from plaintext. Certificates and keys **auto-rotate by policy**; plain secrets do not.
- cert-manager's model: **Issuer/ClusterIssuer = the CA**, **Certificate = desired state**, output is a **TLS Secret**. `renewBefore` drives automatic renewal — the Key Vault "certificate lifetime action / auto-renew with integrated CA" equivalent.
- **HSM root of trust**: non-exportable keys, crypto in hardware, FIPS validation → Managed HSM / Vault PKCS#11. "Keys must be protected by a single-tenant FIPS-validated HSM" is Managed HSM, not standard Key Vault.
- ClusterIssuer (cluster-wide) vs Issuer (namespaced) — scope questions mirror ClusterRole vs Role.
