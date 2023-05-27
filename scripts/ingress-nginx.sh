#!/bin/bash
set -euxo pipefail

# install 
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/v${INGRESS_NGINX_VERSION}/deploy/static/provider/baremetal/deploy.yaml

# wait until is ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "ingress-nginx installed"
