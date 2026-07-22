#!/usr/bin/env bash
# Tear down the Pomerium reference solution.
set -euo pipefail
cd "$(dirname "$0")"
terraform destroy -input=false -auto-approve
echo "Destroyed."
