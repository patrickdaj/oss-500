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

## Steps

### Part A — Encryption-as-a-service with Vault transit (`key-transit`)

The transit engine is Vault's "encryption-as-a-service": the **key never leaves Vault**, callers send plaintext and get ciphertext back — exactly what a Key Vault *key* (wrap/unwrap, encrypt/decrypt) does, versus a *secret* that just stores bytes.

1. Enable transit and create a named key:
   ```bash
   kubectl -n oss500-secrets exec -it statefulset/vault -- sh
   vault secrets enable transit
   vault write -f transit/keys/app-data      # AES-256-GCM by default; exportable=false — key material stays in Vault
   ```
2. Encrypt some plaintext (transit takes base64 input):
   ```bash
   vault write transit/encrypt/app-data plaintext=$(echo -n "cardholder-4111" | base64)
   # ciphertext   vault:v1:xxxxxxxxxxxxxxxxxxxx...
   ```
   Note the **`vault:v1:` prefix** — the key version that produced this ciphertext.
3. Decrypt to prove the round-trip (and that you never saw the key):
   ```bash
   vault write transit/decrypt/app-data ciphertext="vault:v1:xxxx..."
   # plaintext   Y2FyZGhvbGRlci00MTEx   ->  echo ...| base64 -d  ->  cardholder-4111
   ```
4. **Rotate the key** and observe versioning. New encryptions use `v2`; old `vault:v1:` ciphertext still decrypts (Vault keeps prior versions):
   ```bash
   vault write -f transit/keys/app-data/rotate
   vault write transit/encrypt/app-data plaintext=$(echo -n "new-data" | base64)
   # ciphertext   vault:v2:yyyy...        <- new version prefix
   ```
5. (Optional) `rewrap` upgrades old ciphertext to the newest key version *without exposing plaintext* — the pattern for CMK rotation across a data store:
   ```bash
   vault write transit/rewrap/app-data ciphertext="vault:v1:xxxx..."   # -> vault:v2:...
   ```
   This is precisely the "customer-managed key rotates; re-wrap the data-encryption key" flow, done server-side.

### Part B — Issue a certificate with a ClusterIssuer (`cert-issuer`)

cert-manager is the Kubernetes-native certificate authority integration: an **Issuer/ClusterIssuer** is the CA source (self-signed, a private CA, Vault, or ACME/Let's Encrypt), and a **Certificate** resource is the desired cert — cert-manager reconciles it into a TLS `Secret`, the Key Vault "certificate object" analogue.

6. Create a self-signed root, then a CA issuer signed by it (a realistic private-CA chain; ACME/Let's Encrypt is the same shape but needs a public DNS name):
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
7. Request a leaf certificate for a demo service:
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
8. Inspect the issued cert inside the Secret cert-manager created:
   ```bash
   kubectl -n oss500-apps get secret demo-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -issuer -dates
   # subject=CN=demo.localtest.me / issuer=CN=oss500-ca / notBefore.. notAfter (24h out)
   ```
   This `demo-tls` Secret is what the ingress lab ([d2-ingress-waf](d2-ingress-waf.md)) terminates TLS with.

### Part C — Renewal, rotation & revocation (`cert-lifecycle`)

9. cert-manager renews **automatically** at `renewBefore`. Force it now to watch the machinery instead of waiting:
   ```bash
   cmctl renew demo-tls -n oss500-apps
   cmctl status certificate demo-tls -n oss500-apps    # shows issuance, next renewal time, events
   ```
10. Confirm rotation happened — a **new `notAfter`** and a fresh key in the same Secret (consumers auto-pick it up on reload):
    ```bash
    kubectl -n oss500-apps get secret demo-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
    # notAfter has moved forward -> the cert rotated
    ```
11. **Revocation / rotation of trust**: cert-manager has no CRL for a private CA, so revocation in practice = rotate the leaf (delete the Secret; cert-manager re-issues) or rotate the issuing CA and let all leaves re-issue. For public ACME certs, revocation is a CA-side operation. Delete the Secret and watch re-issue:
    ```bash
    kubectl -n oss500-apps delete secret demo-tls
    kubectl -n oss500-apps get certificate demo-tls -w    # cert-manager re-issues into a new Secret
    ```

### Part D — HSM as root of trust (`key-hsm`) — walkthrough

*Impractical on a single laptop host (needs a real HSM or a PKCS#11 stack + Vault Enterprise for HSM auto-unseal), but studied at the same depth — this is the Managed HSM analogue.*

12. **Why**: an HSM keeps key material in tamper-resistant hardware; keys are non-exportable and crypto happens inside the device (FIPS 140-2/3). It is the *root of trust* — in Vault, an HSM can **auto-unseal** Vault (wrapping the master key) and/or back the PKI/transit keys via **PKCS#11 seal**.
13. **Config shape** (Vault Enterprise `seal "pkcs11"` stanza):
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

## Teardown

- `cd lab-infra/certs && ./down.sh` (and `cd lab-infra/secrets && ./down.sh` if you brought Vault up only for Part A)

## What the exam asks

- **Key vs secret**: encryption-as-a-service where the key *never leaves* the store (transit / Key Vault keys) is the answer when the scenario says "the app must encrypt/decrypt but must never possess the key." A stored blob is a *secret*, not a key.
- **Key/cert versions & rotation**: rotating a transit/CMK key produces a new version; existing ciphertext is re-wrapped, not re-encrypted from plaintext. Certificates and keys **auto-rotate by policy**; plain secrets do not.
- cert-manager's model: **Issuer/ClusterIssuer = the CA**, **Certificate = desired state**, output is a **TLS Secret**. `renewBefore` drives automatic renewal — the Key Vault "certificate lifetime action / auto-renew with integrated CA" equivalent.
- **HSM root of trust**: non-exportable keys, crypto in hardware, FIPS validation → Managed HSM / Vault PKCS#11. "Keys must be protected by a single-tenant FIPS-validated HSM" is Managed HSM, not standard Key Vault.
- ClusterIssuer (cluster-wide) vs Issuer (namespaced) — scope questions mirror ClusterRole vs Role.
