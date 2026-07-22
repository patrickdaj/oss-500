#!/usr/bin/env bash
# Tear down the OpenZiti overlay reference solution.
set -euo pipefail
cd "$(dirname "$0")"
../ztna-common/tf.sh down    # shared: terraform destroy
rm -f host.jwt client.jwt
echo "Destroyed. Stop the 'ziti edge quickstart' controller/router too."
