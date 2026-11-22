#!/usr/bin/env bash
# Builds the Gold layer: runs dbt (Silver -> Gold) through Trino, once.
set -euo pipefail
cd "$(dirname "$0")/../dbt"
kubectl -n lakehouse create configmap dbt-code --from-file=. --dry-run=client -o yaml | kubectl apply -f -
kubectl -n lakehouse delete job dbt-build --ignore-not-found
kubectl apply -f ../jobs/dbt-job.yaml
kubectl -n lakehouse wait --for=condition=complete job/dbt-build --timeout=900s || { kubectl -n lakehouse logs job/dbt-build --tail=60; exit 1; }
kubectl -n lakehouse logs job/dbt-build --tail=15
echo "Now query it in Trino:  SELECT * FROM gold.daily_revenue;"
