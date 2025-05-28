#!/bin/bash

set -euo pipefail

echo "[INFO] Checking for kubectl..."
command -v kubectl >/dev/null 2>&1 || {
  echo "[ERROR] kubectl not found. Please install it first."
  exit 1
}

echo "[INFO] Creating ingress-nginx namespace..."
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

echo "[INFO] Applying mandatory NGINX ingress controller manifests..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml

echo "[INFO] Waiting for ingress controller to be ready..."

READY=false
for i in {1..60}; do
  READY_PODS=$(kubectl -n ingress-nginx get pods -l app.kubernetes.io/component=controller -o jsonpath='{.items[*].status.containerStatuses[*].ready}')
  if [[ "$READY_PODS" == *"true"* ]]; then
    READY=true
    echo "[INFO] Ingress controller pod is ready."
    break
  fi
  echo "[INFO] Waiting for ingress controller pod... (${i}/60)"
  sleep 5
done

if [ "$READY" = false ]; then
  echo "[ERROR] Ingress controller pod did not become ready in time."
  kubectl -n ingress-nginx get pods
  exit 1
fi

echo "[INFO] NGINX Ingress Controller installed successfully."

echo -e "\nYou can test it by creating an Ingress resource.\n"
