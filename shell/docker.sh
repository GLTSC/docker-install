#!/bin/sh
command_exists() {
   command -v "$@" > /dev/null 2>&1
}
get_distribution() {
        lsb_dist=""
        # Every system that we officially support has /etc/os-release
        if [ -r /etc/os-release ]; then
                lsb_dist="$(. /etc/os-release && echo "$ID")"
        fi
        # Returning an empty string here should be alright since the
        # case statements don't act unless you provide an actual value
        echo "$lsb_dist"
}
set -x
#var
kernel=`uname -r |cut -d'.' -f1-3`
unamer=`uname -r |cut -d'.' -f1-2`
kernel_version=`uname -r |cut -d'.' -f1-3|cut -d'-' -f2`
 
#kernel 3.10.0-693
if [[ `echo "${unamer} < 3.10" |bc` -eq 1 ]];then
    echo -e "\033[31m the linux kernel $kernel too lower 3.10 \033[0m" && exit 8
  elif [[ $kernel_version -lt 693 ]]; then
    echo -e "\033[31m the linux kernel $kernel too lower 3.10.0-693 \033[0m" && exit 8
fi
storage=${1:-/var/lib/docker}
harbor_ip=${2:-127.0.0.1}
mkdir -p $storage
if ! command_exists docker; then
  lsb_dist=$( get_distribution )
        lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
        echo "current system is $lsb_dist"
        case "$lsb_dist" in
                ubuntu|deepin|debian|raspbian)
                        cp ../conf/docker.service /lib/systemd/system/docker.service
                ;;
                centos|rhel|ol|sles|kylin|neokylin)
                        cp ../conf/docker.service /usr/lib/systemd/system/docker.service
                ;;
    alios)
      ip link add name docker0 type bridge
      ip addr add dev docker0 172.17.0.1/16
        cp ../conf/docker.service /usr/lib/systemd/system/docker.service
    ;;
                *)
                        echo "unknown system to use /lib/systemd/system/docker.service"
                        cp ../conf/docker.service /lib/systemd/system/docker.service
                ;;
        esac
  tar --strip-components=1 -xvzf ../docker/docker.tgz -C /usr/bin
  chmod a+x /usr/bin
  [ -d  /etc/docker/ ] || mkdir /etc/docker/  -p
cat > /etc/docker/daemon.json  << eof
{
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
    },
  "insecure-registries":
        ["$harbor_ip"],
  "data-root":"${storage}"
}
eof
  systemctl enable  docker.service
  systemctl restart docker.service
fi
# 已经安装了docker并且运行了, 就不去重启.
docker info || systemctl restart docker.service
cgroupDriver=$(docker info|grep Cg)
driver=${cgroupDriver##*: }
echo "driver is ${driver}"
export criDriver=${driver}
