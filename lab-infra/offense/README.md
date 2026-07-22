# lab-infra/offense — purple-team tooling (local targets only)

The attack tooling for **Domain 5** ([`../../domains/5-offensive-validation/`](../../domains/5-offensive-validation/)). It installs the red-team tools into an isolated Python venv and points them at the **local lab stack only** — never an external host. Used by the three D5 labs:

| Track | Tools | Lab |
|---|---|---|
| AI | garak, PyRIT | [`d5-ai-redteam`](../../labs/d5-ai-redteam.md) |
| Infra | Atomic Red Team, Caldera, Stratus Red Team | [`d5-infra-attack-simulation`](../../labs/d5-infra-attack-simulation.md) |
| ZTNA | curl/ssh/nmap (no install) | [`d5-ztna-authz`](../../labs/d5-ztna-authz.md) |

## Rules of engagement (enforced by design)
- **Local only.** `TARGET_HOST` defaults to `127.0.0.1` and `up.sh` **refuses to proceed** if it's set to anything non-local/non-private. Every attack hits the kind cluster / Compose stack you built.
- **Disposable targets.** Privileged infra techniques run in a throwaway pod/VM you destroy after (see the infra lab).
- **Teardown included.** `down.sh` removes the venv, Caldera state, and any reports.

## What `up.sh` does
1. Creates `.venv-offense/` and pip-installs `garak` and `pyrit` (pinned).
2. Prints how to fetch **Atomic Red Team** (git clone), run **Caldera** (self-hosted server, local), and **Stratus Red Team** (single binary) — these are large/interactive, so they're documented rather than force-installed.
3. Echoes the local target it will attack, and stops if it isn't local.

## Run
```bash
./up.sh            # installs garak/pyrit into .venv-offense, prints infra-tool setup
# ... run the D5 labs ...
./down.sh          # remove venv + reports + Caldera state
```

Nothing here is committed beyond the scripts and this README — the venv, reports, and any pulled repos are gitignored.
