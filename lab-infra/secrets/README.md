# secrets — HashiCorp Vault (+ Agent Injector, Secrets Store CSI)

The OSS-500 secrets manager. Backs the labs
[d2-vault-dynamic-secrets](../../labs/d2-vault-dynamic-secrets.md) and
[d2-vault-k8s-injection](../../labs/d2-vault-k8s-injection.md), and the transit
part of [d2-cert-manager](../../labs/d2-cert-manager.md).
**SC-500 correspondence:** Azure Key Vault (secrets, keys, rotation, diagnostics).

**Objectives:** `vault-deploy`, `vault-access`, `vault-dynamic`, `vault-rotation`, `vault-k8s`, `vault-audit`, `key-transit`

**Footprint:** ~1 Vault pod + injector + CSI driver DaemonSet ≈ 300–400 MB, a handful of pods. Fits the reference host easily.

Vault runs in **dev mode** here (`server.dev.enabled: true`) so it auto-initialises
and auto-unseals with the fixed root token `root` — perfect for a laptop, wrong for
anything real. `values.yaml` carries the production HA-Raft + auto-unseal config
commented alongside, and `vault-init.json.example` shows the Shamir unseal output a
real `vault operator init` would produce.

```bash
./up.sh          # Vault (dev) + injector + Secrets Store CSI driver
./configure.sh   # audit device, kubernetes auth, transit, database engine
```

**Verify**
```bash
# vault-deploy: server is initialised and unsealed
kubectl -n oss500-secrets exec vault-0 -- \
  sh -c 'VAULT_ADDR=http://127.0.0.1:8200 vault status'

# vault-audit: a file audit device is enabled
kubectl -n oss500-secrets exec vault-0 -- \
  sh -c 'VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault audit list'

# key-transit: encrypt-as-a-service round-trips (key never leaves Vault)
kubectl -n oss500-secrets exec vault-0 -- sh -c \
 'VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root \
  vault write transit/encrypt/app-data plaintext=$(echo -n hello | base64)'
```

**Teardown**
```bash
./down.sh        # helm uninstall vault + csi driver, clean up demo SAs/SPCs
```

> Secrets hygiene: the real `vault-init.json` (unseal keys + root token) is
> gitignored — only `vault-init.json.example` is tracked.
