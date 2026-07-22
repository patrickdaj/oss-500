#!/usr/bin/env bash
# Tear down the purple-team tooling: remove the venv, reports, and pulled repos.
set -euo pipefail
cd "$(dirname "$0")"

rm -rf .venv-offense
rm -rf garak_runs reports *.report.jsonl *.report.html
rm -rf atomic-red-team caldera
echo "Removed offense venv, reports, and any locally cloned attack repos."
echo "Stop any running Caldera server and delete throwaway attack pods/VMs yourself."
