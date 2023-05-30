!/bin/bash
# ref:
# https://blog.csdn.net/Jeeper_/article/details/50683047
# https://codeantenna.com/a/FOtutjP9od
# https://blog.csdn.net/Jeeper_/article/details/50683047
set -ux

modprobe ip_vs
modprobe nf_conntrack_ipv4
modprobe nf_conntrack
modprobe dummy numdummies=1

set -e

cat <<EOF > /etc/rc.local
#!/bin/bash
modprobe ip_vs
modprobe nf_conntrack_ipv4
modprobe nf_conntrack
modprobe dummy numdummies=1
EOF

chmod +x /etc/rc.local
systemctl enable rc-local

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

rm -rf /root/go
mkdir -p /root/go
export GOPATH=/root/go

GO111MODULE=off
golan=2

if [ $golan -eq 1 ];then
  # install go lang 1
  apt-get install golang -y
fi 

if [ $golan -eq 2 ];then
  export PATH=/usr/local/go/bin:$PATH

  # install go lang 2
  [ -f go.tar.gz ] || curl -Lo go.tar.gz https://go.dev/dl/go1.19.3.linux-amd64.tar.gz
  rm -rf /usr/local/go ; tar -C /usr/local -xzf go.tar.gz
fi

if [ $golan -eq 3 ];then
  export PATH=/usr/local/go/bin:$PATH
  
  # install go lang 3
  apt-get install golang -y
  curl -LO https://go.dev/dl/go1.20.4.linux-amd64.tar.gz
  rm -rf /usr/local/go ; tar -C /usr/local -xzf go1.20.4.linux-amd64.tar.gz
fi

which go
go version

# install dependencies
apt-get install libnl-3-dev libnl-genl-3-dev build-essential git curl wget -y

# compile swwsaw
mkdir -p ${GOPATH}/src/github.com/google
cd ${GOPATH}/src/github.com/google
git clone https://github.com/google/seesaw.git
cd seesaw

go get -u golang.org/x/crypto/ssh
go get -u github.com/dlintw/goconf
go get -u github.com/golang/glog
go get -u github.com/miekg/dns
go get -u github.com/kylelemons/godebug/pretty
go get -u github.com/golang/protobuf/proto

if [ "$GO111MODULE" == "off" ];then
  go get -u github.com/fsnotify/fsnotify
  go get -u golang.org/x/term   
fi

make test 
make install

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

install /vagrant/cluster.pb /etc/seesaw
install /vagrant/seesaw.cfg /etc/seesaw
