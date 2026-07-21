#!/usr/bin/env bash
# Tear down the Boundary+Vault ZTNA reference solution.
set -euo pipefail
cd "$(dirname "$0")"
terraform destroy -input=false -auto-approve
echo "Destroyed. Stop the 'boundary dev' / 'vault server -dev' processes too."
