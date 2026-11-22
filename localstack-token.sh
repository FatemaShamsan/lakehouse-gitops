#!/usr/bin/env bash
# Only if you use a newer LocalStack image: store your free auth token in the cluster (not in Git).
# Usage: LOCALSTACK_AUTH_TOKEN=... ./localstack-token.sh
set -euo pipefail
: "${LOCALSTACK_AUTH_TOKEN:?set LOCALSTACK_AUTH_TOKEN}"
kubectl -n lakehouse create secret generic localstack-auth --from-literal=token="$LOCALSTACK_AUTH_TOKEN" --dry-run=client -o yaml | kubectl apply -f -
