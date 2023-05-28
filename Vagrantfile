# -*- mode: ruby -*-
# vi: set ft=ruby :

require "yaml"
settings = YAML.load_file "settings.yaml"

IP_SECTIONS = settings["network"]["control_ip"].match(/^([0-9.]+\.)([^.]+)$/)
# First 3 octets including the trailing dot:
IP_NW = IP_SECTIONS.captures[0]
# Last octet excluding all dots:
IP_START = Integer(IP_SECTIONS.captures[1])
NUM_WORKER_NODES = settings["nodes"]["workers"]["count"]
NUM_MASTER_NODES = settings["nodes"]["control"]["count"]

Vagrant.configure("2") do |config|
  config.vagrant.plugins = ["vagrant-cachier"]
  config.cache.scope = :machine
  
  config.vm.provision "shell",
    env: { 
      "IP_NW" => IP_NW,
      "IP_START" => IP_START,
      "NUM_WORKER_NODES" => NUM_WORKER_NODES,
      "NUM_MASTER_NODES" => NUM_MASTER_NODES
    },
    inline: <<-SHELL
      apt-get update -y
      cat /etc/hosts|grep -v node > /etc/hosts.tmp
      cat /etc/hosts.tmp > /etc/hosts
      echo "$IP_NW$((IP_START)) master-node" >> /etc/hosts
      
      for i in `seq 2 ${NUM_MASTER_NODES}`; do
        echo "$IP_NW$((IP_START-1+i)) master-node${i}" >> /etc/hosts
      done
      
      for i in `seq 1 ${NUM_WORKER_NODES}`; do
        echo "$IP_NW$((IP_START+4+i)) worker-node0${i}" >> /etc/hosts
      done
  SHELL

  if `uname -m`.strip == "aarch64"
    config.vm.box = settings["software"]["box"] + "-arm64"
  else
    config.vm.box = settings["software"]["box"]
  end
  config.vm.box_check_update = true
  
  i=1
  config.vm.define "master" do |master|
    master.vm.hostname = "master-node"
    master.vm.network "private_network", ip: "#{IP_NW}#{IP_START - 1 + i}"
    if settings["shared_folders"]
      settings["shared_folders"].each do |shared_folder|
        master.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
      end
    end
    master.vm.provider "virtualbox" do |vb|
        vb.cpus = settings["nodes"]["control"]["cpu"]
        vb.memory = settings["nodes"]["control"]["memory"]
        if settings["cluster_name"] and settings["cluster_name"] != ""
          vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
        end
    end
    master.vm.provision "shell",
      env: {
        "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
        "ENVIRONMENT" => settings["environment"],
        "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
        "OS" => settings["software"]["os"]
      },
      path: "scripts/common.sh"
    if settings["software"]["create_cluster"] == 1
      master.vm.provision "shell",
        env: {
          "CALICO_VERSION" => settings["software"]["calico"],
          "CONTROL_IP" => settings["network"]["control_ip"],
          "POD_CIDR" => settings["network"]["pod_cidr"],
          "IP_NW" => IP_NW,
          "IP_START" => IP_START,
          "SERVICE_CIDR" => settings["network"]["service_cidr"]
        },
        path: "scripts/master.sh"
    end
  end
  
  if NUM_MASTER_NODES > 1
    (2..NUM_MASTER_NODES).each do |i|
      config.vm.define "master#{i}" do |master|
        master.vm.hostname = "master-node#{i}"
        master.vm.network "private_network", ip: "#{IP_NW}#{IP_START - 1 + i}"
        if settings["shared_folders"]
          settings["shared_folders"].each do |shared_folder|
            master.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
          end
        end
        master.vm.provider "virtualbox" do |vb|
            vb.cpus = settings["nodes"]["control"]["cpu"]
            vb.memory = settings["nodes"]["control"]["memory"]
            if settings["cluster_name"] and settings["cluster_name"] != ""
              vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
            end
        end
        master.vm.provision "shell",
          env: {
            "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
            "ENVIRONMENT" => settings["environment"],
            "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
            "OS" => settings["software"]["os"]
          },
          path: "scripts/common.sh"
        if settings["software"]["create_cluster"] == 1
          master.vm.provision "shell",
            env: {
              "CALICO_VERSION" => settings["software"]["calico"],
              "CONTROL_IP" => settings["network"]["control_ip"],
              "POD_CIDR" => settings["network"]["pod_cidr"],
              "IP_NW" => IP_NW,
              "IP_START" => IP_START,
              "SERVICE_CIDR" => settings["network"]["service_cidr"]
            },
            path: "scripts/master.sh"
        end
      end
    end
  end
  
  (1..NUM_WORKER_NODES).each do |i|

    config.vm.define "node0#{i}" do |node|
      node.vm.hostname = "worker-node0#{i}"
      node.vm.network "private_network", ip: "#{IP_NW}#{IP_START + 4 + i}"
      if settings["shared_folders"]
        settings["shared_folders"].each do |shared_folder|
          node.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
        end
      end
      node.vm.provider "virtualbox" do |vb|
          vb.cpus = settings["nodes"]["workers"]["cpu"]
          vb.memory = settings["nodes"]["workers"]["memory"]
          if settings["cluster_name"] and settings["cluster_name"] != ""
            vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
          end
      end
      node.vm.provision "shell",
        env: {
          "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
          "ENVIRONMENT" => settings["environment"],
          "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
          "OS" => settings["software"]["os"]
        },
        path: "scripts/common.sh"
      
      if settings["software"]["create_cluster"] == 1
        node.vm.provision "shell", 
          path: "scripts/node.sh"
      
        # Only install the dashboard after provisioning the first worker (and when enabled).
        if i == 1 and settings["software"]["dashboard"] and settings["software"]["metrics_server"] and settings["software"]["dashboard"] != "" and settings["software"]["metrics_server"] != ""
          node.vm.provision "shell", 
          env: {
            "DASHBOARD_VERSION" => settings["software"]["dashboard"],
            "METRICS_SERVER_VERSION" => settings["software"]["metrics_server"]
          },
          path: "scripts/dashboard.sh"
        end
        if i == 1 and settings["software"]["metallb"] and settings["software"]["metallb"] != ""
          node.vm.provision "shell", 
          env: {
            "METALLB_VERSION" => settings["software"]["metallb"],
            "METALLB_ADDR_POOL" => settings["network"]["loadbalancer_addr_pool"]
          },
          path: "scripts/metallb.sh"
        end
        if i == 1 and settings["software"]["ingress_nginx"] and settings["software"]["ingress_nginx"] != ""
          node.vm.provision "shell", 
          env: {
            "INGRESS_NGINX_VERSION" => settings["software"]["ingress_nginx"]
          },
          path: "scripts/ingress-nginx.sh"
        end
      end
    end
  end
end 
