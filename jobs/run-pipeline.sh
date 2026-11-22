#!/usr/bin/env bash
# Runs the Bronze -> Silver Spark job once. (Later, Airflow replaces this script.)
set -euo pipefail
cd "$(dirname "$0")"
kubectl -n lakehouse create configmap bronze-to-silver-code --from-file=bronze_to_silver.py --dry-run=client -o yaml | kubectl apply -f -
kubectl -n lakehouse delete job bronze-to-silver --ignore-not-found
kubectl apply -f bronze-to-silver-job.yaml
kubectl -n lakehouse wait --for=condition=complete job/bronze-to-silver --timeout=600s || { kubectl -n lakehouse logs job/bronze-to-silver --tail=60; exit 1; }
kubectl -n lakehouse logs job/bronze-to-silver --tail=5
