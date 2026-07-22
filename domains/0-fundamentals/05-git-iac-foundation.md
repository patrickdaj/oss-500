# Fundamentals: git and Terraform — the IaC groundwork

Ramp notes — no exam objective maps here. The course's later work assumes you can already drive **git** and **Terraform**: the ZTNA labs are all Terraform-automated and `gov-iac` is an objective. `03-kind-helm-iac.md` gives the *applied* toolchain; this note is the *foundation* underneath it. Read it before the automated labs so the plumbing isn't in your way.

## git — the version-control model

git tracks **snapshots**, not diffs. A **commit** is a full snapshot of the tree plus a pointer to its parent(s), named by a hash of its content — so history is a chain (really a DAG) of immutable snapshots. The three places a file lives: the **working tree** (what you edit), the **staging area / index** (what `git add` marks for the next commit), and the **repository** (committed history).

```bash
git init                       # start a repo
git add <path>                 # stage changes into the index
git commit -m "message"        # snapshot the index into history
git log --oneline --graph      # read the commit DAG
```

A **branch** is just a movable pointer to a commit — cheap, so branch per change. **Remotes** are other copies of the repo (`origin` on GitHub/GitLab); `push`/`pull`/`fetch` sync commits between them, and a **pull request / merge request** is the review gate before a branch lands on the mainline.

```bash
git switch -c feature/x        # branch off and move onto it
git push -u origin feature/x   # publish the branch to the remote
git pull                       # fetch + merge others' commits
```

**Why it matters for this course.** Every lab repo *is* the source of truth — the environment is reproducible from a clean clone, and a change is a reviewable commit, not an untracked click. That "the repo defines the infrastructure" idea is **GitOps**: the desired state lives in git, and reconciliation makes the running system match it. It's also the change-management/audit story behind `gov-iac` — a diff is an audit trail.

## Terraform — the IaC foundation

Terraform declares **desired state** in HCL; you describe *what* you want and Terraform computes the *how*. **Providers** are plugins that map that HCL to a real API (AWS, Kubernetes, Vault) — each `resource` block belongs to a provider.

**State** is the load-bearing concept. Terraform records what it has created in a **state file** that maps your config to real-world resource IDs; on the next run it diffs desired-vs-state to decide what to change. Because state is shared and mutable, concurrent runs would corrupt it — so a **backend** stores state **remotely** (S3, Terraform Cloud, GCS) and **locks** it during an apply so two people can't clobber each other. **Modules** are reusable, parameterized bundles of resources — the unit of composition and reuse.

```bash
terraform init      # download providers, configure the backend
terraform plan      # diff desired state vs actual — the review step
terraform apply     # make reality match the config
terraform destroy   # tear the managed resources back down
```

The **write → plan → apply** loop is the whole discipline: `plan` shows exactly what will change *before* anything happens — read it like you'd read a code diff.

**Why it matters for this course.** The Terraform-automated ZTNA labs stand up and tear down whole environments through this loop, and `gov-iac` is provisioning security controls *as code* — reviewable, reproducible, version-controlled. When a lab's Terraform sets a default-deny policy or a hardened `securityContext`, the `plan` is where you verify the control before it's live. `03-kind-helm-iac.md` builds on this foundation with kind and Helm in the lab context.

## Self-check

1. Explain the difference between the working tree, the staging area, and the repository — and which command moves a change between each.
2. Why is a git branch cheap, and what makes the commit history immutable?
3. What does Terraform **state** record, and why must a shared backend **lock** it during an apply?
4. Describe write → plan → apply and why `plan` is the step that maps onto "verify the control before it's live."

## Primary sources
- [Pro Git — Recording changes to the repository](https://git-scm.com/book/en/v2/Git-Basics-Recording-Changes-to-the-Repository) · [Branches in a nutshell](https://git-scm.com/book/en/v2/Git-Branching-Branches-in-a-Nutshell) · [Working with remotes](https://git-scm.com/book/en/v2/Git-Basics-Working-with-Remotes)
- [git](https://git-scm.com/) (reference)
- [OpenGitOps — Principles](https://opengitops.dev/) (reference)
- [Terraform — The core workflow (write/plan/apply)](https://developer.hashicorp.com/terraform/intro/core-workflow) · [State](https://developer.hashicorp.com/terraform/language/state) · [State locking](https://developer.hashicorp.com/terraform/language/state/locking) · [Modules](https://developer.hashicorp.com/terraform/language/modules) · [Backends & remote state](https://developer.hashicorp.com/terraform/language/backend)
- [Terraform](https://developer.hashicorp.com/terraform) (reference)
