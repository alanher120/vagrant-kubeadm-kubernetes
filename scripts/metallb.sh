#!/bin/bash
set -euxo pipefail

# actually apply the changes, returns nonzero returncode on errors only
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system

# Installation By Manifest
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml

# Wait until the MetalLB pods (controller and speakers) are ready
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=120s

# Setup address pool used by loadbalancers
cat << EOF > metallb-config.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - ${METALLB_ADDR_POOL}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF
kubectl apply -f metallb-config.yaml && rm -f metallb-config.yaml

echo "metallb installed."
