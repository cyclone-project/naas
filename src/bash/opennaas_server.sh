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
cd cnsmo-net-services-master/src/main/docker/vpn/server/
./install_docker.sh
if [ $? -ne 0 ] ; then
    echo "Error : can't install docker"
    exit $ERR_INSTALL_DOCKER
fi

cat <<EOF_VPNCONF > /tmp/cnsmo-net-services-master/src/main/docker/vpn/server/server.conf
local 0.0.0.0
port 1194
proto udp
;dev tap
dev tap
;dev-node MyTap

ca ca.crt
cert server.crt
key server.key  # This file should be kept secret

dh dh2048.pem

server 10.8.0.0 255.255.255.0

ifconfig-pool-persist ipp.txt

;server-bridge 10.8.0.4 255.255.255.0 10.8.0.50 10.8.0.100

;push "route 192.168.10.0 255.255.255.0"
;push "route 192.168.20.0 255.255.255.0"

;client-config-dir ccd
;route 192.168.40.128 255.255.255.248

;client-config-dir ccd
;route 10.9.0.0 255.255.255.252

;learn-address ./script

;push "redirect-gateway"

;push "dhcp-option DNS 134.158.88.149"
;push "dhcp-option WINS 10.8.0.1"

client-to-client

;duplicate-cn

keepalive 10 120

;tls-auth ta.key 0 # This file is secret

;cipher BF-CBC        # Blowfish (default)
;cipher AES-128-CBC   # AES
;cipher DES-EDE3-CBC  # Triple-DES

comp-lzo

;max-clients 100

;user nobody
;group nobody

persist-key
persist-tun

status openvpn-status.log

;log         openvpn.log
;log-append  openvpn.log

verb 3

;mute 20

EOF_VPNCONF


docker build -t vpn-server .
if [ $? -ne 0 ] ; then
    echo "Error : can't build the VPN-Server"
    exit $ERR_BUILD_DOCKER
fi

sudo docker run -t --net=host --privileged -v /dev/net/:/dev/net/ vpn-server

if [ $? -ne 0 ] ; then
    echo "Error : can't run the VPN-Server"
    exit $ERR_RUN_DOCKER
fi
exit $ERR_OK
