# Lab d2: Deliver Vault secrets to pods (Agent Injector & CSI)

Get a Vault secret onto a pod's filesystem — authenticated by the pod's own ServiceAccount — without the secret ever becoming a base64 Kubernetes Secret object.

**Objectives covered**

| id | Objective |
|---|---|
| `vault-k8s` | Deliver secrets to workloads via the Vault agent injector or Secrets Store CSI |
| `vault-access` | *(touchpoint)* Configure access with auth methods and policies |

**SC-500 correspondence**: Azure Key Vault + workload identity (a workload proves its identity to the secret store and pulls secrets at runtime — no secret checked into config or handed out ahead of time)

**Prerequisites**

- [`lab-infra/secrets`](../lab-infra/secrets/) up (`./up.sh`) — Vault **plus** the Agent Injector (enabled in the chart values) and, for Part C, the Secrets Store CSI driver + Vault CSI provider.
- Notes read: [secrets-management.md](../domains/2-secrets-data-networking/secrets-management.md).
- The Kubernetes auth method configured in [d2-vault-dynamic-secrets](d2-vault-dynamic-secrets.md) Part B (or run its enable step first).

**Estimated time**: 2 h · $0 (local)

## Steps

### Part A — Bind a ServiceAccount to a Vault role & policy (`vault-access` → `vault-k8s`)

1. Configure the Kubernetes auth method so Vault trusts this cluster's ServiceAccount tokens. Vault validates the projected token against the cluster's token reviewer / OIDC issuer:
   ```bash
   kubectl -n oss500-secrets exec -it statefulset/vault -- sh
   vault write auth/kubernetes/config \
       kubernetes_host="https://kubernetes.default.svc:443"
   ```
2. Put a demo secret in KV-v2 and write a policy that reads only it:
   ```bash
   vault kv put secret/app/config username=appuser password=s3cr3t-from-vault
   cat > app-ro.hcl <<'EOF'
   path "secret/data/app/config" { capabilities = ["read"] }
   EOF
   vault policy write app-ro app-ro.hcl
   ```
3. Create a **role** that binds a specific ServiceAccount + namespace to that policy. Only a pod running as `app-sa` in `oss500-apps` may assume it:
   ```bash
   vault write auth/kubernetes/role/app \
       bound_service_account_names=app-sa \
       bound_service_account_namespaces=oss500-apps \
       policies=app-ro \
       ttl=1h
   ```
4. Create the ServiceAccount the workload will run as:
   ```bash
   kubectl -n oss500-apps create serviceaccount app-sa
   ```
   This is workload identity: the pod's SA token *is* its credential to Vault — there is no static secret to distribute.

### Part B — Vault Agent Injector (sidecar → shared memory file)

5. Deploy a workload annotated for injection. The mutating webhook injects an init container + sidecar that log in with `app-sa`'s token and render the secret to an in-pod `tmpfs` file:
   ```yaml
   # inject-demo.yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: inject-demo
     namespace: oss500-apps
     labels: { app.kubernetes.io/part-of: oss500 }
   spec:
     replicas: 1
     selector: { matchLabels: { app: inject-demo } }
     template:
       metadata:
         labels: { app: inject-demo }
         annotations:
           vault.hashicorp.com/agent-inject: "true"          # vault-k8s: turn on injection
           vault.hashicorp.com/role: "app"                    # the Vault role from Part A
           vault.hashicorp.com/agent-inject-secret-config: "secret/data/app/config"
           # optional Go-template to shape the file (e.g. as an env-file):
           vault.hashicorp.com/agent-inject-template-config: |
             {{- with secret "secret/data/app/config" -}}
             export APP_USER="{{ .Data.data.username }}"
             export APP_PASS="{{ .Data.data.password }}"
             {{- end -}}
       spec:
         serviceAccountName: app-sa                            # identity Vault checks
         containers:
           - name: app
             image: busybox:1.36
             command: ["sh","-c","sleep 3600"]
   ```
   ```bash
   kubectl apply -f inject-demo.yaml
   kubectl -n oss500-apps get pod -l app=inject-demo   # note 2/2 containers: app + vault-agent
   ```
6. Read the materialized secret from **inside** the pod — it lives on a `tmpfs` mount at `/vault/secrets/`, never on disk, never as an etcd Secret:
   ```bash
   kubectl -n oss500-apps exec deploy/inject-demo -c app -- cat /vault/secrets/config
   # export APP_USER="appuser"
   # export APP_PASS="s3cr3t-from-vault"
   ```
7. Confirm the negative: there is **no Kubernetes Secret** holding this value:
   ```bash
   kubectl -n oss500-apps get secret | grep -i config    # nothing — the value never became a k8s Secret
   ```
8. **Rotation refresh**: update the secret in Vault and watch the sidecar re-render the file (the agent watches the lease and rewrites `/vault/secrets/config`):
   ```bash
   vault kv put secret/app/config username=appuser password=rotated-value
   sleep 5
   kubectl -n oss500-apps exec deploy/inject-demo -c app -- cat /vault/secrets/config   # now shows rotated-value
   ```

### Part C — Secrets Store CSI driver (alternative delivery)

9. The CSI path mounts secrets as a volume via the driver + Vault provider (no sidecar). Define a `SecretProviderClass`:
   ```yaml
   # spc.yaml
   apiVersion: secrets-store.csi.x-k8s.io/v1
   kind: SecretProviderClass
   metadata:
     name: vault-app-config
     namespace: oss500-apps
     labels: { app.kubernetes.io/part-of: oss500 }
   spec:
     provider: vault
     parameters:
       roleName: "app"                                   # same Vault role
       vaultAddress: "http://vault.oss500-secrets:8200"
       objects: |
         - objectName: "password"
           secretPath: "secret/data/app/config"
           secretKey: "password"
   ```
10. Mount it into a pod as a read-only volume:
    ```yaml
    # csi-demo.yaml (pod excerpt)
    spec:
      serviceAccountName: app-sa
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh","-c","sleep 3600"]
          volumeMounts:
            - name: secrets
              mountPath: /mnt/secrets
              readOnly: true
      volumes:
        - name: secrets
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: vault-app-config
    ```
    ```bash
    kubectl apply -f spc.yaml -f csi-demo.yaml
    kubectl -n oss500-apps exec deploy/csi-demo -- cat /mnt/secrets/password   # -> rotated-value
    ```
11. Note the trade-off: the **Agent Injector** renders arbitrary templates and refreshes automatically; the **CSI driver** mounts objects as files and (optionally, with `secretObjects`) can *sync into a real k8s Secret* — convenient but reintroduces a base64 Secret in etcd, so only enable sync when a controller genuinely needs a `Secret`.

## Verification

- `kubectl exec ... -- cat /vault/secrets/config` returns the live Vault value **inside** the pod, while `kubectl get secret` shows **no** corresponding Kubernetes Secret — the secret was delivered at runtime via the pod's ServiceAccount identity, not stored as a base64 object.
- After `vault kv put` changes the value, the injected file (and the CSI mount) reflects the **new** value without redeploying the pod — proving rotation reaches the workload.
- A pod running as any SA other than `app-sa` in `oss500-apps` fails to authenticate to the Vault role (permission denied) — the workload-identity binding is enforced.

## Teardown

- `cd lab-infra/secrets && ./down.sh`

## What the exam asks

- A Kubernetes `Secret` is only **base64-encoded**, not encrypted; delivering secrets from an external store at runtime (injector/CSI) keeps them **out of etcd** entirely — the preferred answer to "stop storing credentials as k8s Secrets."
- The workload authenticates with **its own ServiceAccount token** (workload identity), so there is no bootstrap secret to distribute — the OSS mirror of a managed identity fetching from Key Vault.
- **Injector vs CSI**: injector = sidecar + tmpfs file + templating + auto-refresh; CSI = volume mount, optional sync to a real Secret. Know that enabling CSI's `secretObjects` sync *does* create a base64 Secret again.
- The Vault **role's `bound_service_account_names`/`namespaces`** is the authorization gate — a pod with the wrong SA/namespace is denied even if the token is valid, matching least-privilege scoping.
