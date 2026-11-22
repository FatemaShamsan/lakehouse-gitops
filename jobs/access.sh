#!/usr/bin/env bash
# Trino SQL shell, and Trino through Envoy Gateway on http://trino.localtest.me:8081
set -euo pipefail
case "${1:-shell}" in
  shell) POD=$(kubectl -n lakehouse get pod -l app.kubernetes.io/component=coordinator -o jsonpath='{.items[0].metadata.name}')
         kubectl -n lakehouse exec -it "$POD" -- trino --catalog lakehouse ;;
  gateway) SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=lakehouse-gw -o jsonpath='{.items[0].metadata.name}')
           echo "Open http://trino.localtest.me:8081"; kubectl -n envoy-gateway-system port-forward "svc/$SVC" 8081:80 ;;
esac
