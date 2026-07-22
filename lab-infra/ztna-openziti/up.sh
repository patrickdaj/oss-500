#!/usr/bin/env bash
# Reference solution — the OpenZiti app-embedded overlay, as Terraform.
# Build your own from labs/d1-ztna-openziti.md first; run this to check/compare.
# Prereqs: a local controller + edge router (`ziti edge quickstart`), and two
# tunnelers (client + host) you enroll with the tokens this prints.
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f terraform.tfvars ]; then
  echo "Copy terraform.tfvars.example -> terraform.tfvars and fill it in first." >&2
  exit 1
fi
terraform init -input=false
terraform apply -input=false -auto-approve
echo
echo "Applied. Enroll the tunnelers with the one-time tokens:"
echo "  terraform output -raw host_enrollment_token   > host.jwt   && ziti-edge-tunnel enroll -j host.jwt"
echo "  terraform output -raw client_enrollment_token > client.jwt && ziti-edge-tunnel enroll -j client.jwt"
echo "Then dial the service by its overlay name — no listening port on the underlay."
