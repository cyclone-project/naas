#!/bin/bash

ERR_OK=0
ERR_APTGET=1
ERR_WGET=2
ERR_COPY_MASTER=3
ERR_UNZIP=4
ERR_INSTALL_DOCKER=5
ERR_BUILD_DOCKER=6
ERR_RUN_DOCKER=7

apt-get -y update
apt-get -y upgrade
apt-get -y install unzip apache2 easy-rsa openssl
if [ $? -ne 0 ] ; then
    echo "Error : can't install unzip, apache2, easy-rsa or openssl"
    exit $ERR_APTGET
fi

wget https://github.com/dana-i2cat/cnsmo-net-services/archive/master.zip
if [ $? -ne 0 ] ; then
    echo "Error : can't get the CNSMO archive"
    exit $ERR_WGET
fi

cp master.zip /tmp/
if [ $? -ne 0 ] ; then
    echo "Error : can't copy the CNSMO archive to /tmp/"
    exit $ERR_COPY_MASTER
fi

cd /tmp/
unzip master.zip
if [ $? -ne 0 ] ; then
    echo "Error : can't unzip the CNSMO archive"
    exit $ERR_UNZIP
fi
cd cnsmo-net-services-master/src/main/docker/vpn/client/
./install_docker.sh
if [ $? -ne 0 ] ; then
    echo "Error : can't install docker"
    exit $ERR_INSTALL_DOCKER
fi

cat <<EOF_VPNCONF > /tmp/cnsmo-net-services-master/src/main/docker/vpn/client/client.conf
client

dev tap
;dev tun

;dev-node MyTap

;proto tcp
proto udp

remote 134.158.75.63 1194
;remote my-server-2 1194

;remote-random

resolv-retry infinite

nobind

;user nobody
;group nobody

persist-key
persist-tun

;http-proxy-retry # retry on connection failures
;http-proxy [proxy server] [proxy port #]

;mute-replay-warnings

ca ca.crt
cert client.crt
key client.key

;ns-cert-type server

;tls-auth ta.key 1

;cipher x

comp-lzo

verb 3

;mute 20
EOF_VPNCONF

docker build -t vpn-client .
if [ $? -ne 0 ] ; then
    echo "Error : can't build the VPN-client"
    exit $ERR_BUILD_DOCKER
fi

sudo docker run -t --net=host --privileged -v /dev/net/:/dev/net/ vpn-client

if [ $? -ne 0 ] ; then
    echo "Error : can't run the VPN-Client"
    exit $ERR_RUN_DOCKER
fi
exit $ERR_OK
