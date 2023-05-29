#!/bin/bash
# https://codeantenna.com/a/FOtutjP9od
#https://blog.csdn.net/Jeeper_/article/details/50683047
set -euxo pipefail

modprobe ip_vs
modprobe nf_conntrack_ipv4
modprobe nf_conntrack
modprobe dummy numdummies=1

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

rm -rf /usr/local/go && tar -C /usr/local -xzf go1.20.4.linux-amd64.tar.gz
export PATH=/usr/local/go:$PATH

go get -u golang.org/x/crypto/ssh
go get -u github.com/dlintw/goconf
go get -u github.com/golang/glog
go get -u github.com/miekg/dns
go get -u github.com/kylelemons/godebug/pretty
go get -u github.com/golang/protobuf/proto

# complic swwsaw
git clone https://github.com/google/seesaw.git
cd swwsaw
make test && make install

# install swwsaw
SEESAW_BIN="/usr/local/seesaw"
SEESAW_ETC="/etc/seesaw"
SEESAW_LOG="/var/log/seesaw"

INIT=`ps -p 1 -o comm=`

install -d "${SEESAW_BIN}" "${SEESAW_ETC}" "${SEESAW_LOG}"

install "${GOPATH}/bin/seesaw_cli" /usr/bin/seesaw

for component in {ecu,engine,ha,healthcheck,ncc,watchdog}; do
  install "${GOPATH}/bin/seesaw_${component}" "${SEESAW_BIN}"
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
