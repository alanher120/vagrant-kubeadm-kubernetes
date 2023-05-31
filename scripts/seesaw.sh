!/bin/bash
# ref:
# https://blog.csdn.net/Jeeper_/article/details/50683047
# https://codeantenna.com/a/FOtutjP9od
# https://blog.csdn.net/Jeeper_/article/details/50683047
set -ux

# tune on or off with using go version 1.11
#GO111MODULE=off

# create GOPATH
export GOPATH=/root/go
rm -rf $GOPATH
mkdir -p $GOPATH

# export PATH
export PATH=/usr/local/go/bin:$PATH

# load kernel modules
modprobe ip_vs
modprobe nf_conntrack_ipv4
modprobe nf_conntrack
modprobe dummy numdummies=1

set -e

# modules
if [ -f /etc/modules ];then
  cat << EOF > /etc/modules
ip_vs
dummy numdummies=1
EOF
fi

# modprobe.d
if [ -d /etc/modprobe.d/ ];then
  #echo options ip_vs  > /etc/modprobe.d/ip_vs.conf
  #echo options nf_conntrack > /etc/modprobe.d/nf_conntrack.conf
  #echo options nf_conntrack_ipv4 > /etc/modprobe.d/nf_conntrack_ipv4.conf
  echo options dummy numdummies=1 > /etc/modprobe.d/dummy.conf
fi

# modules.load.d
if [ -d /etc/modules.load.d/ ];then
  echo ip_vs > /etc/modules.load.d/ip_vs.conf
  echo nf_conntrack_ipv4 > /etc/modules.load.d/nf_conntrack_ipv4.conf
  echo nf_conntrack > /etc/modules.load.d/nf_conntrack.conf
  echo dummy numdummies=1 > /etc/modules.load.d/dummy.conf
  systemctl restart systemd-modules-load.service
fi

# install go lang 
[ ! -f go.tar.gz ] && curl -Lo go.tar.gz https://go.dev/dl/go1.19.1.linux-amd64.tar.gz
rm -rf /usr/local/go ; tar -C /usr/local -xzf go.tar.gz

which go
go version

# install dependencies
apt-get install libnl-3-dev libnl-genl-3-dev build-essential git curl wget -y

# compile swwsaw
mkdir -p ${GOPATH}/src/github.com/google
cd ${GOPATH}/src/github.com/google
git clone https://github.com/google/seesaw.git
cd seesaw

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

exit 0

install /vagrant/cfgs/cluster.pb /etc/seesaw
install /vagrant/cfgs/${HOSTNAME}-seesaw.cfg /etc/seesaw/seesaw.cfg

if [ ! -f /vagrant/cert/ca.crt ];then
  openssl req -x509 -sha256 -nodes -newkey rsa:2048 -keyout ca.key -out ca.crt
  
  MASTER_IP=10.0.0.10
  SEESAW_IP=10.0.0.10
  openssl req -new -x509 -sha256 -nodes -newkey rsa:4096 -days 1000 -subj "/CN=${MASTER_IP}" -keyout ca.key -out ca.crt
  
  openssl req -new -sha256 -nodes -newkey rsa:2048 -subj "/CN=${SEESAW_IP}" -keyout seesaw.key -out seesaw.csr
  openssl x509 -req -sha256 -CA ca.crt -CAkey ca.key -CAserial ca.srl -CAcreateserial -days 730 -in seesaw.csr -out seesaw.crt
  
  mkdir -p /vagrant/cert
  install ca.crt /vagrant/cert
  install ca.key /vagrant/cert
  install seesaw.key /vagrant/cert
  install seesaw.key /vagrant/cert
fi

install /vagrant/cert/ca.crt /etc/seesaw/ssl
install /vagrant/cert/ca.key /etc/seesaw/ssl
