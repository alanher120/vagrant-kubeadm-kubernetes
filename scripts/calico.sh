#!/bin/bash

set -euxo pipefail

if [ -n "calico" ];then
  # Install Calico Network Plugin
  if [ $CALICO_VERSION == "main" ];then
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/main/manifests/calico.yaml
  else
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml
  fi
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
