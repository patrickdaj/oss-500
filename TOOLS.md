# TOOLS — install as each phase arrives

Every CLI the labs invoke, the phase it first appears, and how to get it. **Install the day-one baseline now; install the rest just-in-time as its phase arrives** — you never need all of these at once, and the resource plan already assumes you bring up only the current lab's stack.

Each lab's Prerequisites also names the tools *that* lab uses and links back here.

## Day-one baseline (install before Phase 0)

| Tool | Install (macOS) | Install (Linux) |
|---|---|---|
| Docker | [Docker Desktop](https://www.docker.com/products/docker-desktop/) | [Docker Engine](https://docs.docker.com/engine/install/) |
| kind | `brew install kind` | [kind releases](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |
| kubectl | `brew install kubectl` | [kubectl install](https://kubernetes.io/docs/tasks/tools/) |
| Helm | `brew install helm` | [Helm install](https://helm.sh/docs/intro/install/) |
| git | `brew install git` | `apt-get install git` |
| **jq** | `brew install jq` | `apt-get install jq` |

> **`jq` and Terraform are effectively baseline too** — `lab-infra/secrets/up.sh` hard-fails without `jq` (it parses Vault's init JSON), and the ZTNA labs' `tf.sh` hard-fails without `terraform` from Phase 1 Day 6. Install both early.

## Phase 1 — Identity, access, governance

| Tool | Used for | Install (macOS) | Install (Linux) |
|---|---|---|---|
| terraform | ZTNA labs (all Terraform-automated); `gov-iac` | `brew install hashicorp/tap/terraform` | [HashiCorp apt/yum repo](https://developer.hashicorp.com/terraform/install) |
| vault | Boundary broker injects a Vault SSH cred (front-loads a Domain-2 sliver) | `brew install hashicorp/tap/vault` | [HashiCorp repo](https://developer.hashicorp.com/vault/install) |
| boundary | the Boundary ZTNA broker (`boundary dev`, `boundary connect`) | `brew install hashicorp/tap/boundary` | [HashiCorp repo](https://developer.hashicorp.com/boundary/install) |
| ziti | OpenZiti overlay control (`ziti edge …`) | [OpenZiti downloads](https://openziti.io/docs/downloads) | [OpenZiti downloads](https://openziti.io/docs/downloads) |
| ziti-edge-tunnel | OpenZiti client tunneler (separate binary) | [OpenZiti downloads](https://openziti.io/docs/downloads) | [OpenZiti downloads](https://openziti.io/docs/downloads) |
| netbird | NetBird WireGuard mesh client | `brew install netbirdio/tap/netbird` | [install.netbird.io](https://docs.netbird.io/how-to/getting-started) |
| tsh, tctl | Teleport PAM client/admin | [Teleport downloads](https://goteleport.com/download/) | [Teleport downloads](https://goteleport.com/download/) |
| kubescape | posture / framework compliance scan | `brew install kubescape` | [`curl` installer](https://kubescape.io/docs/install-cli/) |
| rbac-tool, kubectl-who-can | RBAC over-permission audit (kubectl plugins via [krew](https://krew.sigs.k8s.io/)) | `kubectl krew install rbac-tool who-can` | `kubectl krew install rbac-tool who-can` |

## Phase 2 — Secrets, data, networking

| Tool | Used for | Install (macOS) | Install (Linux) |
|---|---|---|---|
| psql | test a Vault dynamic DB credential (or `exec` the shipped `psql-client` pod) | `brew install libpq` (keg-only — add to PATH) | `apt-get install postgresql-client` |
| cmctl | cert-manager lifecycle (`cmctl renew/status`) | `brew install cmctl` | [cmctl releases](https://cert-manager.io/docs/reference/cmctl/) |
| istioctl | service-mesh install / inspection | `curl -L https://istio.io/downloadIstio \| sh -` | same |
| cilium | Cilium CNI status/hubble (fabric lab) | `brew install cilium-cli` | [cilium-cli releases](https://github.com/cilium/cilium-cli/releases) |
| hubble | Cilium flow logs | `brew install hubble` | [hubble releases](https://github.com/cilium/hubble/releases) |
| trivy | image/secret scanning | `brew install trivy` | [Trivy install](https://trivy.dev/latest/getting-started/installation/) |
| gitleaks | secret scanning | `brew install gitleaks` | [gitleaks releases](https://github.com/gitleaks/gitleaks/releases) |

## Phase 3 — Compute & AI security

| Tool | Used for | Install (macOS) | Install (Linux) |
|---|---|---|---|
| grype | vuln scan an SBOM | `brew install grype` | [grype releases](https://github.com/anchore/grype/releases) |
| syft | generate an SBOM | `brew install syft` | [syft releases](https://github.com/anchore/syft/releases) |
| cosign | sign / verify images | `brew install cosign` | [cosign releases](https://github.com/sigstore/cosign/releases) |
| opa | evaluate the AI-gateway Rego (`opa eval`) | `brew install opa` | [opa releases](https://github.com/open-policy-agent/opa/releases) |

## Phase 4 — Posture & monitoring

| Tool | Used for | Install (macOS) | Install (Linux) |
|---|---|---|---|
| kube-bench | CIS benchmark (runs as a `kubectl` Job; CLI optional) | [kube-bench releases](https://github.com/aquasecurity/kube-bench/releases) | [kube-bench releases](https://github.com/aquasecurity/kube-bench/releases) |
| sigma (sigma-cli) | convert Sigma rules to OpenSearch queries | `pipx install sigma-cli` | `pipx install sigma-cli` |

## Phase 5 — Offensive validation

| Tool | Used for | Install (macOS) | Install (Linux) |
|---|---|---|---|
| garak | LLM red-team probes | `pipx install garak` (or `pipx run garak`) | same |
| pyrit | multi-turn LLM attack orchestration | `pip install pyrit` | same |
| caldera | chained ATT&CK operations | `git clone --recursive https://github.com/mitre/caldera && pip install -r caldera/requirements.txt` | same |
| stratus | cloud-native TTPs, no cloud account | `brew install stratus-red-team` | [stratus releases](https://github.com/DataDog/stratus-red-team/releases) |
| atomic | single ATT&CK atomics (`Invoke-AtomicTest`, PowerShell) | [Atomic Red Team](https://github.com/redcanaryco/invoke-atomicredteam/wiki) | [Atomic Red Team](https://github.com/redcanaryco/invoke-atomicredteam/wiki) |

## Phase 6 — Agentic zero trust

Reuses `opa`, `helm` (SPIRE chart), and Python (the LangGraph agent / MCP server, pinned in `lab-infra/agentic/agent/requirements.txt`). No new host CLI beyond the above.

---

*If a lab invokes a tool that isn't listed here, that's a documentation bug — please flag it.*
