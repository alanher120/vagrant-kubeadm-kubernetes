#!/bin/bash

set -euxo pipefail

if [ -n "$FLANNEL_VERSION" ];then
  # Install flannel Network Plugin
  if [ $FLANNEL_VERSION == "main" ];then
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://github.com/flannel-io/flannel/releases/laeset/download/kube-flannel.yml
  else
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://github.com/flannel-io/flannel/releases/laeset/download/kube-flannel.yml
  fi
  
cat <<EOF | KUBECONFIG=/etc/kubernetes/admin.conf kubectl -n kube-flannel patch cm patch-file -
data:
  net-conf.json: |
    {
      "Network": "$POD_CIDR"
    }
EOF
  
  sleep 20
  KUBECONFIG=/etc/kubernetes/admin.conf kubectl wait --namespace kube-system \
                --for=condition=ready pod \
                --selector=k8s-app=calico-kube-controllers \
                --timeout=180s
  
  KUBECONFIG=/etc/kubernetes/admin.conf kubectl wait --namespace kube-system \
                --for=condition=ready pod \
                --selector=k8s-app=calico-node \
                --timeout=180s
fi
