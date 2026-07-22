#!/usr/bin/env bash
# Tear down the Pomerium reference solution.
set -euo pipefail
cd "$(dirname "$0")"
../ztna-common/tf.sh down    # shared: terraform destroy
echo "Destroyed."
