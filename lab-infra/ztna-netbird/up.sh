#!/usr/bin/env bash
# Reference solution — a NetBird WireGuard mesh with identity ACLs, as Terraform.
# Build your own from labs/d1-ztna-netbird.md first; run this to check/compare.
# Prereqs: a self-hosted NetBird control plane (getting-started-with-zitadel compose
# or the official quickstart) reachable at management_url, plus a PAT in tfvars.
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f terraform.tfvars ]; then
  echo "Copy terraform.tfvars.example -> terraform.tfvars and fill it in first." >&2
  exit 1
fi
terraform init -input=false
terraform apply -input=false -auto-approve
echo
echo "Applied. Enroll peers into their groups with the setup keys:"
echo "  netbird up --management-url \$MGMT --setup-key \$(terraform output -raw admin_setup_key)"
echo "  netbird up --management-url \$MGMT --setup-key \$(terraform output -raw server_setup_key)"
echo "admins can SSH servers; nothing else is permitted."
