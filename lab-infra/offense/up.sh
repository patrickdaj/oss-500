#!/usr/bin/env bash
# Purple-team tooling for Domain 5 — installs the AI red-team tools locally and
# prints setup for the infra tools. LOCAL TARGETS ONLY: refuses a non-local host.
set -euo pipefail
cd "$(dirname "$0")"

TARGET_HOST="${TARGET_HOST:-127.0.0.1}"

# Safety gate: only localhost / RFC1918 targets are allowed. This lab attacks the
# stack you built, never external or shared infrastructure.
case "$TARGET_HOST" in
  127.0.0.1 | localhost | 10.* | 192.168.* | 172.1[6-9].* | 172.2[0-9].* | 172.3[0-1].*)
    echo "Target: $TARGET_HOST (local) — OK." ;;
  *)
    echo "REFUSING: TARGET_HOST='$TARGET_HOST' is not local/RFC1918." >&2
    echo "Domain 5 attacks the local lab stack only. Aborting." >&2
    exit 1 ;;
esac

echo "==> Creating isolated venv and installing garak + PyRIT (AI track)"
python3 -m venv .venv-offense
# shellcheck source=/dev/null
. .venv-offense/bin/activate
pip install --quiet --upgrade pip
# Pinned: an unpinned install can resolve to wildly different, incompatible
# APIs depending on the interpreter (e.g. garak pre-REST-generator, or PyRIT's
# pre-1.0 orchestrator API) — these versions are what pyrit_multiturn.py and
# localhost-ollama.json were built and run against.
pip install --quiet "garak==0.15.1" "pyrit==1.0.0"
echo "    garak + pyrit installed in .venv-offense (activate it to use)."

cat <<'EOF'

==> Infra track (large/interactive — set up as directed, all run locally):
  Atomic Red Team : git clone https://github.com/redcanaryco/atomic-red-team
                    run atomics INSIDE a disposable pod/VM only.
  Caldera         : git clone https://github.com/mitre/caldera --recursive
                    python3 server.py --insecure   (self-hosted, localhost)
  Stratus         : download the stratus-red-team release binary
                    stratus detonate <technique>   (local targets only)

==> Point AI tools at the LOCAL gateway, e.g. http://127.0.0.1:<d3-ai-port>.
    Never target a hosted model API or any external host.
EOF
