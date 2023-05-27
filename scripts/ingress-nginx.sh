#!/bin/bash
set -euxo pipefail

# install 
#sudo -i -u vagrant kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/v${INGRESS_NGINX_VERSION}/deploy/static/provider/baremetal/deploy.yaml
if [ "${INGRESS_NGINX_VERSION}" == "main" ];then
  sudo -i -u vagrant kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml
else
  sudo -i -u vagrant kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/v${INGRESS_NGINX_VERSION}/deploy/static/provider/baremetal/deploy.yaml
fi

# wait until is ready
sudo -i -u vagrant kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "ingress-nginx installed"
