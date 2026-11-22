#!/usr/bin/env bash
# Creates the "AWS" resources (bucket, KMS key, secret, IAM role) in LocalStack using OpenTofu.
# Run once after Argo CD has deployed LocalStack. Needs OpenTofu (tofu) installed.
set -euo pipefail
cd "$(dirname "$0")/tofu"
kubectl -n lakehouse rollout status deploy/localstack --timeout=300s
kubectl -n lakehouse port-forward svc/localstack 4566:4566 >/dev/null 2>&1 &
PF=$!; trap 'kill $PF' EXIT; sleep 3
tofu init
tofu apply -auto-approve
echo "Check: aws --endpoint-url http://localhost:4566 s3 ls   (any fake credentials)"
