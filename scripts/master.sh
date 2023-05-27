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
  sudo kubeadm init --apiserver-advertise-address=$CONTROL_IP --apiserver-cert-extra-sans=$CONTROL_IP --pod-network-cidr=$POD_CIDR --service-cidr=$SERVICE_CIDR --node-name "$NODENAME" --ignore-preflight-errors Swap
  
  kubeadm init phase upload-certs --upload-certs > $config_path/master-cert-key
  CERT_KEY=`tail -1 $config_path/master-cert-key`
  cat $config_path/join.sh|while read x;do echo "${x} --control-plane --certificate-key ${CERT_KEY}" ;done > $config_path/master-join.sh
else
  # runing on non-first master
  /bin/bash $config_path/master-join.sh -v 
fi

mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# Save Configs to shared /Vagrant location

cp -i /etc/kubernetes/admin.conf $config_path/config
touch $config_path/join.sh
chmod +x $config_path/join.sh

kubeadm token create --print-join-command > $config_path/join.sh

# Install Calico Network Plugin

#curl https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml -O

#kubectl apply -f calico.yaml

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF

# Install Metrics Server

#kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml

