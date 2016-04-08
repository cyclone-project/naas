#!/bin/bash
#=============================================================================
#
#  File      : openvpn-postint.sh
#  Date      : March 27th, 2016
#  Author    : Oleg Lodygensky
#
#  Change log:
#    Jan 13th, 2016; first version
#
#
# Copyright 2016  CNRS
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
#=============================================================================


ERR_OK=0
ERR_APTGET=1
ERR_OPENVPN=2
ERR_APACHE=3

apt-get -y update
apt-get -y upgrade

apt-get -y install apache2 openvpn easy-rsa openssl
if [ $? -ne 0 ] ; then
	echo "ERROR : can't install apache2, openvpn, easy-rsa or openssl"
	exit $ERR_APTGET
fi

cp -r /usr/share/easy-rsa /etc/openvpn
if [ $? -ne 0 ] ; then
	echo "ERROR : can't copy easy-rsa to openvpn"
	exit $ERR_OPENVPN
fi

openssl dhparam -out /etc/openvpn/dh2048.pem 2048
if [ $? -ne 0 ] ; then
	echo "ERROR : can't generate dh key"
	exit $ERR_OPENVPN
fi

cd /etc/openvpn/easy-rsa
if [ $? -ne 0 ] ; then
	echo "ERROR : can't cd to /etc/openvpn/easy-rsa"
	exit $ERR_OPENVPN
fi

source vars

export KEY_COUNTRY="fr"
export KEY_CITY="Orsay"
export KEY_ORG="CNRS"
export KEY_EMAIL="lodygens@lal.in2p3.fr"
export KEY_OU="LAL"

./clean-all && ./pkitool --initca &&  ./pkitool --server server && ./pkitool client
if [ $? -ne 0 ] ; then
	echo "ERROR : can't create keys"
	exit $ERR_OPENVPN
fi

cp /etc/openvpn/easy-rsa/keys/ca.crt /etc/openvpn/ && cp /etc/openvpn/easy-rsa/keys/server.crt /etc/openvpn/ && cp /etc/openvpn/easy-rsa/keys/server.key /etc/openvpn/
if [ $? -ne 0 ] ; then
	echo "ERROR : can't install server keys"
	exit $ERR_OPENVPN
fi

cat <<EOF_VPNCONF > /etc/openvpn/server.conf
port 443
# en cas de souci, commentez proto udp et décommentez proto tcp
;proto tcp
proto udp
##
dev tun
ca ca.crt
cert server.crt
key server.key
#push "redirect-gateway def1 bypass-dhcp"
# remplacez les IP ci-dessous par celles des serveurs DNS désirés
# ici celles actuellement fournies par OpenDNS
push "dhcp-option DNS 134.158.88.149"
##
# si vous avez généré une clé d'une taille différente de 2048, renommez dh2048.pem en fonction
dh dh2048.pem
##
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
# commenté par défaut, la commande ci-dessous permet d'autoriser une même clé pour plusieurs clients
duplicate-cn
##
keepalive 10 120
# Modifier le réglage ci-dessous permet de choisir le cipher utilisé,
# le même réglage doit être présent dans la config client
;cipher BF-CBC        # Blowfish (default)
;cipher AES-128-CBC   # AES
;cipher DES-EDE3-CBC  # Triple-DES
##
comp-lzo
# en cas de problème d'autorisation, commentez les lignes ci-dessous (déconseillé)
user nobody
group nogroup # remplacez par "group nogroup" sous certaines Debian
##
persist-key
persist-tun
status openvpn-status.log
verb 0

EOF_VPNCONF


service openvpn start

exit $ERR_OK

