#!/usr/bin/env bash
# Reference solution — the Boundary + Vault ZTNA broker, as Terraform.
# Build your own from labs/d1-ztna-boundary.md first; run this to check/compare.
# Prereqs: a controller (`boundary dev`) and Vault (`vault server -dev`) with the
# SSH secrets engine, plus a private SSH host the worker can reach.
set -euo pipefail
cd "$(dirname "$0")"
../ztna-common/tf.sh up    # shared: tfvars guard + terraform init + apply
echo
echo "Applied. Verify identity-based, credential-injected access:"
echo "  boundary authenticate password -login-name appuser"
echo "  boundary connect ssh -target-id \$(terraform output -raw target_id)"
