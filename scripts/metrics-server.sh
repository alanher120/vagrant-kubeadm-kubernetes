#!/bin/bash
set -euxo pipefail

# Install Metrics Server
sudo -i -u vagrant kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml

echo 'Waiting for metrics server to be ready...'
sudo -i -u vagrant kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=k8s-app=metrics-server \
  --timeout=120s
echo 'Metrics server is ready.'
