#!/usr/bin/env bash
# Shared bring-up/teardown flow for the lab-infra/ztna-* stack family.
# This is the single place the invariant Terraform plumbing lives, so a change to
# the tfvars guard or the init/apply/destroy flags is made once, not four times.
#
# Per-model logic is NOT here: each stack's own main.tf (the study material) and
# its up.sh/down.sh header + verify hint stay in the stack directory. This wrapper
# only runs terraform in the caller's current directory.
#
# Usage (from a stack's up.sh/down.sh, after `cd "$(dirname "$0")"`):
#   ../ztna-common/tf.sh up     # tfvars guard + terraform init + apply
#   ../ztna-common/tf.sh down   # terraform destroy
set -euo pipefail

action="${1:-}"

case "$action" in
  up)
    if [ ! -f terraform.tfvars ]; then
      echo "Copy terraform.tfvars.example -> terraform.tfvars and fill it in first." >&2
      exit 1
    fi
    terraform init -input=false
    terraform apply -input=false -auto-approve
    ;;
  down)
    terraform destroy -input=false -auto-approve
    ;;
  *)
    echo "usage: ${0##*/} <up|down>" >&2
    exit 2
    ;;
esac
