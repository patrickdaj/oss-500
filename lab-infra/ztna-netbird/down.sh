#!/usr/bin/env bash
# Tear down the NetBird mesh reference solution (groups, setup keys, policy).
set -euo pipefail
cd "$(dirname "$0")"
terraform destroy -input=false -auto-approve
echo "Destroyed. Peers already enrolled should be removed from the dashboard too."
