#!/usr/bin/env bash
# Reference solution — Pomerium identity-aware proxy in front of an internal app,
# deployed as a Terraform-wrapped Helm release.
# Build your own from labs/d1-ztna-pomerium.md first; run this to check/compare.
# Prereqs: the kind cluster up, Keycloak (D1) reachable as the OIDC IdP, and an
# `internal-app` Service in the default namespace to protect.
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f terraform.tfvars ]; then
  echo "Copy terraform.tfvars.example -> terraform.tfvars and fill it in first." >&2
  exit 1
fi
terraform init -input=false
terraform apply -input=false -auto-approve
echo
echo "Applied. Browse to the route (https://app.localtest.me) — you're bounced to"
echo "Keycloak to authenticate, then allowed only if your identity matches policy."
