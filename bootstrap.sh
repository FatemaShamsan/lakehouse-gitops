#!/usr/bin/env bash
# Usage: REPO_URL=https://github.com/<you>/lakehouse-gitops.git ./bootstrap.sh
# Push this folder to that repo (branch: main) BEFORE running, because Argo CD reads from Git.
set -euo pipefail
: "${REPO_URL:?Set REPO_URL to your Git repo, e.g. https://github.com/you/lakehouse-gitops.git}"
cd "$(dirname "$0")"

minikube start --driver=docker --cpus="${CPUS:-4}" --memory="${MEMORY:-10240}" --disk-size=40g
minikube addons enable metrics-server

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

# Point the Applications at your repo, then start the app of apps
sed -i "s|REPO_URL|${REPO_URL}|g" apps/*.yaml argocd/root-app.yaml
echo ">>> Commit and push the changed apps/*.yaml and argocd/root-app.yaml to ${REPO_URL}, then press Enter"
read -r _
kubectl apply -f argocd/root-app.yaml

echo "Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
echo "UI: kubectl -n argocd port-forward svc/argocd-server 8080:443   then https://localhost:8080 (user: admin)"
