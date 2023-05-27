#!/bin/bash
set -euxo pipefail

# Install Metrics Server
kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml

echo 'Waiting for metrics server to be ready...'
kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=k8s-app=metrics-server \
  --timeout=120s
echo 'Metrics server is ready.'
