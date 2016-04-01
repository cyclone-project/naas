#!/bin/bash

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


APACHE_SITES="/etc/apache2/sites-available/"
APACHE_VPNHOST_CONF="/etc/apache2/sites-available/100-vpn_host.conf"

if [ ! -d $APACHE_SITES ] ; then
	echo "ERROR : directory not found, $APACHE_SITES"
	exit $ERR_APACHE
fi

cat <<EOF_VHOST > $APACHE_VPNHOST_CONF
<VirtualHost 10.8.0.1>
  ServerAdmin webmaster@localhost
  DocumentRoot /var/www/html
  ErrorLog ${APACHE_LOG_DIR}/error_vpn.log
  CustomLog ${APACHE_LOG_DIR}/access_vpn.log combined
</VirtualHost>
EOF_VHOST

ln -s $APACHE_VPNHOST_CONF /etc/apache2/sites-enabled
if [ $? -ne 0 ] ; then
	echo "ERROR : can't install apache vpn host"
	exit $ERR_APACHE
fi

service apache2 restart

exit $ERR_OK

