#!/bin/bash
set -euxo pipefail

if [ -n "${METALLB_VERSION}" ];then
  # actually apply the changes, returns nonzero returncode on errors only
  sudo -i -u vagrant kubectl get configmap kube-proxy -n kube-system -o yaml | \
  sed -e "s/strictARP: false/strictARP: true/" | \
  sudo -i -u vagrant kubectl apply -f - -n kube-system

  # Installation By Manifest
  #sudo -i -u vagrant kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml
  if [ "${METALLB_VERSION}" == "main" ];then
    sudo -i -u vagrant kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml
  else
    sudo -i -u vagrant kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml
  fi

  # Wait until the MetalLB pods (controller and speakers) are ready
  sudo -i -u vagrant kubectl wait --namespace metallb-system \
                  --for=condition=ready pod \
                  --selector=app=metallb \
                  --timeout=180s

  # Setup address pool used by loadbalancers
  cat << EOF | sudo -i -u vagrant kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
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

  echo "metallb installed."
fi
