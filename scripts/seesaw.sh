#!/bin/bash
# https://blog.csdn.net/Jeeper_/article/details/50683047
# https://codeantenna.com/a/FOtutjP9od
# https://blog.csdn.net/Jeeper_/article/details/50683047
set -euxo pipefail

modprobe ip_vs
modprobe nf_conntrack_ipv4
modprobe nf_conntrack
modprobe dummy numdummies=1

# rc.local
cat <<EOF > /etc/rc.local
modprobe ip_vs
modprobe nf_conntrack_ipv4
modprobe nf_conntrack
modprobe dummy numdummies=1
EOF

# modprobe.d
if [ -d /etc/modprobe.d/ ];then
  echo options ip_vs > /etc/modprobe.d/ip_vs.conf
  echo options nf_conntrack > /etc/modprobe.d/nf_conntrack.conf
  echo options nf_conntrack_ipv4 > /etc/modprobe.d/nf_conntrack_ipv4.conf
  echo options dummy numdummies=1 > /etc/modprobe.d/dummy.conf
fi

# systemd
if [ -d /etc/modules.load.d/ ];then
  echo ip_vs > /etc/modules.load.d/ip_vs.conf
  echo nf_conntrack_ipv4 > /etc/modules.load.d/nf_conntrack_ipv4.conf
  echo nf_conntrack > /etc/modules.load.d/nf_conntrack.conf
  echo dummy numdummies=1 > /etc/modules.load.d/dummy.conf
  systemctl restart systemd-modules-load.service
fi

# install go lang and make
apt-get install golang -y
apt-get install libnl-3-dev libnl-genl-3-dev -y
apt install make -y

curl -LO https://go.dev/dl/go1.20.4.linux-amd64.tar.gz
export GOROOT=/usr/local/go
export GOPATH=$GOROOT/bin
rm -rf $GOROOT ; tar -C /usr/local -xzf go1.20.4.linux-amd64.tar.gz
export PATH=$GOPATH:$PATH

go get -u golang.org/x/crypto/ssh
go get -u github.com/dlintw/goconf
go get -u github.com/golang/glog
go get -u github.com/miekg/dns
go get -u github.com/kylelemons/godebug/pretty
go get -u github.com/golang/protobuf/proto

# complic swwsaw
git clone https://github.com/google/seesaw.git
cd seesaw
make test && make install

# install swwsaw
SEESAW_BIN="/usr/local/seesaw"
SEESAW_ETC="/etc/seesaw"
SEESAW_LOG="/var/log/seesaw"

cat <<EOF >> ~/.profile 
SEESAW_BIN="/usr/local/seesaw"
SEESAW_ETC="/etc/seesaw"
SEESAW_LOG="/var/log/seesaw"
export PATH=$SEESAW_BIN:$PATH
EOF

INIT=`ps -p 1 -o comm=`

install -d "${SEESAW_BIN}" "${SEESAW_ETC}" "${SEESAW_LOG}"

install "${GOPATH}/seesaw_cli" /usr/bin/seesaw

for component in {ecu,engine,ha,healthcheck,ncc,watchdog}; do
  install "${GOPATH}/seesaw_${component}" "${SEESAW_BIN}"
done

if [ $INIT = "init" ]; then
  install "etc/init/seesaw_watchdog.conf" "/etc/init"
elif [ $INIT = "systemd" ]; then
  install "etc/systemd/system/seesaw_watchdog.service" "/etc/systemd/system"
  systemctl --system daemon-reload
fi
install "etc/seesaw/watchdog.cfg" "${SEESAW_ETC}"

# Enable CAP_NET_RAW for seesaw binaries that require raw sockets.
/sbin/setcap cap_net_raw+ep "${SEESAW_BIN}/seesaw_ha"
/sbin/setcap cap_net_raw+ep "${SEESAW_BIN}/seesaw_healthcheck"

# write seesaw.cfg
cat <<EOF > /etc/seesaw/seesaw.cfg
[cluster]
anycast_enabled = false
name = au-syd
node_ipv4 = 10.0.0.10
peer_ipv4 = 10.0.0.15
vip_ipv4 = 10.0.0.9

[config_server]
primary = master-node
secondary = worker-node01
tertiary = worker-node02

[interface]
node = eth1
lb = eth2
EOF

# write cluster.pb
cat <<EOF > /etc/seesaw/cluster.pb
seesaw_vip: <
  fqdn: "seesaw-vip1.example.com."
  ipv4: "192.168.10.1/24"
  status: PRODUCTION
>
node: <
  fqdn: "seesaw1-1.example.com."
  ipv4: "192.168.10.2/24"
  status: PRODUCTION
>
node: <
  fqdn: "seesaw1-2.example.com."
  ipv4: "192.168.10.3/24"
  status: PRODUCTION
>
vserver: <
  name: "dns.resolver@au-syd"
  entry_address: <
    fqdn: "dns-anycast.example.com."
    ipv4: "10.0.0.5/24"
    status: PRODUCTION
  >
  rp: "corpdns-team@example.com"
  vserver_entry: <
    protocol: TCP
    port: 53
    scheduler: RR
    server_low_watermark: 0.3
    healthcheck: <
      type: DNS
      interval: 5
      timeout: 2
      port: 53
      send: "www.example.com"
      receive: "10.0.0.5"
      mode: DSR
      method: "a"
      retries: 1
    >
  >
  backend: <
    host: <
      fqdn: "worker-node01."
      ipv4: "10.0.0.15/24"
      status: PRODUCTION
    >
    weight: 1
  >
  backend: <
    host: <
      fqdn: "worker-node02."
      ipv4: "10.0.0.16/24"
      status: PRODUCTION
    >
    weight: 1
  >
>
EOF
