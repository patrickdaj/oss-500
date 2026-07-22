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

## Challenge

Using the Kubernetes auth method already enabled in [d2-vault-dynamic-secrets](d2-vault-dynamic-secrets.md) Part B, get a Vault-held secret onto a running pod's filesystem two different ways — without it ever becoming a Kubernetes `Secret` object — and prove that workload identity, not a flag, is the actual gate. No solution here; build toward these observables (the exact proof commands are in Verification):

- **Part A**: a Vault Kubernetes-auth **role** bound to one ServiceAccount (`app-sa`) in one namespace (`oss500-apps`), backed by a policy that can `read` exactly one KV path and nothing else.
- **Part B**: a pod annotated for the **Vault Agent Injector** renders the secret to a `tmpfs` file under `/vault/secrets/` inside the pod; `kubectl get secret` shows no matching object for it; and bumping the value in Vault updates the in-pod file **without redeploying the pod**.
- **Part C**: the same secret delivered instead via the **Secrets Store CSI driver**, mounted read-only into a pod — no sidecar involved.
- **Negative test**: a pod running under any ServiceAccount other than `app-sa` in `oss500-apps` is denied by Vault when it tries to assume the role.

## Build it (guided)

### Part A — Bind a ServiceAccount to a Vault role & policy (`vault-access` → `vault-k8s`)

1. **Trust the cluster's tokens.** Vault has to be able to validate a projected ServiceAccount token presented by a pod. Exec into the Vault pod and configure the `kubernetes` auth method. The one field that matters: `kubernetes_host` must point at the **in-cluster** API server (`https://kubernetes.default.svc:443`), not an external endpoint — Vault calls back into the cluster to validate tokens. Your turn: run the `vault write auth/kubernetes/config ...` call.
2. **Put a secret behind a narrow policy.** Write a demo secret to KV-v2 at a path of your choosing (e.g. `secret/app/config`, with a couple of key/value fields), then author a Vault policy in HCL granting **only** `read` on that one `secret/data/...` path — nothing broader. Name the policy `app-ro` and load it with `vault policy write`.
3. **Create the binding — this is the authorization gate.** A Vault Kubernetes-auth **role** is what actually ties an identity to a policy. Write a role (call it `app`) that sets `bound_service_account_names`, `bound_service_account_namespaces`, `policies`, and a short `ttl` — only a pod running as the exact SA/namespace pair you specify can assume it. This binding is what the negative test in Part B exercises.
4. **Create the ServiceAccount.** `kubectl create serviceaccount` in `oss500-apps`, matching the name you bound in step 3. Why this matters: the pod's own SA token *is* its credential to Vault — there is no bootstrap secret to distribute or rotate ahead of time.

### Part B — Vault Agent Injector (sidecar → shared memory file)

5. **Annotate a workload for injection.** The Agent Injector is a mutating admission webhook: when it sees the right annotations on a pod template, it adds an init container and a sidecar that log in to Vault using the pod's own `app-sa` token and render the secret to a file on a shared `tmpfs` volume. At minimum you need annotations that: turn injection on, name the Vault role from Part A, and name the secret path to render into a file (`vault.hashicorp.com/agent-inject-secret-<name>`). Optionally add an `agent-inject-template-<name>` annotation with a Go template if you want the rendered file shaped as, say, an env-file rather than raw JSON — the template has access to `.Data.data.<field>` from your KV secret. Your turn: write the Deployment manifest (a `busybox` "sleep" container is a fine workload), set `serviceAccountName: app-sa`, apply it, and confirm you see **2/2** containers running for the pod — that second container is your proof the webhook fired:
   ```bash
   kubectl -n oss500-apps get pod -l app=inject-demo
   ```
6. **Read the file from inside the pod.** It lives under `/vault/secrets/` on `tmpfs` — never written to a persistent disk, never stored as a Kubernetes object. Inspect it and confirm it shows the values from step 2, shaped the way your template specified:
   ```bash
   kubectl -n oss500-apps exec deploy/inject-demo -c app -- cat /vault/secrets/config
   ```
7. **Confirm the negative.** Check that no Kubernetes `Secret` was created to hold this value — the whole point of injection is that the value never becomes a base64 etcd object:
   ```bash
   kubectl -n oss500-apps get secret | grep -i config
   ```
8. **Prove rotation reaches the workload.** Write a new value to the same Vault path (same shape as step 2, different value), wait a few seconds for the agent's lease-driven refresh, then re-run your step-6 inspection command — the file should now show the new value, with **no pod restart**. This is what distinguishes injection from a one-shot init container.

### Part C — Secrets Store CSI driver (alternative delivery)

9. **Define a `SecretProviderClass`.** This is the CSI equivalent of the injector's annotations: it tells the driver + Vault provider which role to authenticate as and which secret/key to expose as a file. You'll need `spec.provider: vault`, a `parameters.roleName` (the same Vault role from Part A), a `vaultAddress` reachable inside the cluster, and an `objects` list mapping an `objectName` to a `secretPath`/`secretKey` from your KV secret. Your turn: name it and target the same secret from Part B.
10. **Mount it read-only into a pod.** Reuse the `app-sa` ServiceAccount, and add a `csi` volume with `driver: secrets-store.csi.k8s.io` referencing your `SecretProviderClass` by name via `volumeAttributes.secretProviderClass`. Apply both manifests and inspect the mounted file — it should show the rotated value from step 8, with no sidecar container involved this time:
    ```bash
    kubectl -n oss500-apps exec deploy/csi-demo -- cat /mnt/secrets/password
    ```
11. **Weigh the trade-off.** The **Agent Injector** renders arbitrary templates and refreshes automatically; the **CSI driver** mounts objects as files and (optionally, with `secretObjects`) can *sync into a real Kubernetes Secret* — convenient but reintroduces a base64 Secret in etcd, so only enable sync when a controller genuinely needs a `Secret`.

## Verification

- `kubectl exec ... -- cat /vault/secrets/config` returns the live Vault value **inside** the pod, while `kubectl get secret` shows **no** corresponding Kubernetes Secret — the secret was delivered at runtime via the pod's ServiceAccount identity, not stored as a base64 object.
- After `vault kv put` changes the value, the injected file (and the CSI mount) reflects the **new** value without redeploying the pod — proving rotation reaches the workload.
- A pod running as any SA other than `app-sa` in `oss500-apps` fails to authenticate to the Vault role (permission denied) — the workload-identity binding is enforced.

## Reference solution

Build it yourself first; check after.

### Part A

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

### Part B

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

### Part C

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

If your policy grants more than `read` on the one KV path, or the role omits `bound_service_account_namespaces`, the negative test (wrong SA) won't actually fail — tighten it until only `app-sa` in `oss500-apps` can assume the role.

## Teardown

- `cd lab-infra/secrets && ./down.sh`

## What the exam asks

- A Kubernetes `Secret` is only **base64-encoded**, not encrypted; delivering secrets from an external store at runtime (injector/CSI) keeps them **out of etcd** entirely — the preferred answer to "stop storing credentials as k8s Secrets."
- The workload authenticates with **its own ServiceAccount token** (workload identity), so there is no bootstrap secret to distribute — the OSS mirror of a managed identity fetching from Key Vault.
- **Injector vs CSI**: injector = sidecar + tmpfs file + templating + auto-refresh; CSI = volume mount, optional sync to a real Secret. Know that enabling CSI's `secretObjects` sync *does* create a base64 Secret again.
- The Vault **role's `bound_service_account_names`/`namespaces`** is the authorization gate — a pod with the wrong SA/namespace is denied even if the token is valid, matching least-privilege scoping.
