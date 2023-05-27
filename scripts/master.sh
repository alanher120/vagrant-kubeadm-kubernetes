#!/bin/bash
#
# Setup for Control Plane (Master) servers

set -euxo pipefail

NODENAME=$(hostname -s)
config_path="/vagrant/configs"

sudo kubeadm config images pull

echo "Preflight Check Passed: Downloaded All Required Images"

if [ "$HOSTNAME" == "master-node" ];then
  # For Vagrant re-runs, check if there is existing configs in the location and delete it for saving new configuration.
  if [ -d $config_path ]; then
    rm -f $config_path/*
  else
    mkdir -p $config_path
  fi
  
  # runing on first master
  sudo kubeadm init --apiserver-advertise-address=$CONTROL_IP --apiserver-cert-extra-sans=$CONTROL_IP --control-plane-endpoint=$CONTROL_IP --pod-network-cidr=$POD_CIDR --service-cidr=$SERVICE_CIDR --node-name "$NODENAME" --ignore-preflight-errors Swap
  
  # Install Calico Network Plugin
  #curl https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml -O
  #kubectl apply -f calico.yaml
  KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml
  
  sleep 60
  KUBECONFIG=/etc/kubernetes/admin.conf kubectl wait --namespace kube-system \
                --for=condition=ready pod \
                --selector=k8s-app=calico-kube-controllers \
                --timeout=180s
  
  KUBECONFIG=/etc/kubernetes/admin.conf kubectl wait --namespace kube-system \
                --for=condition=ready pod \
                --selector=k8s-app=calico-node \
                --timeout=180s
  
  # Save Configs to shared /Vagrant location
  cp -i /etc/kubernetes/admin.conf $config_path/config
  
  # create join.sh
  kubeadm token create --ttl 72h0m0s --print-join-command > $config_path/join.sh
  touch $config_path/join.sh
  chmod +x $config_path/join.sh
  
  # create cert key
  kubeadm init phase upload-certs --upload-certs > $config_path/master-join-cert-key
  touch $config_path/master-join-cert-key
  
  for i in 2 3 4 5;do
    # create master-join.sh
    cat $config_path/join.sh|while read x;do echo "${x} --control-plane --certificate-key `tail -1 $config_path/master-join-cert-key` --apiserver-advertise-address=$IP_NW$((IP_START-1+i))" ;done > $config_path/master-node${i}.sh
    touch $config_path/master-node${i}.sh
    chmod +x $config_path/master-node${i}.sh
  done
  
else
  # runing on non-first master
  /bin/bash $config_path/${NODENAME}.sh -v
  
fi

# create kube-config
mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF

# Install Metrics Server

#kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml

