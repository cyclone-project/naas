#!/bin/bash

ERR_APACHE=7

APACHE_SITES="/etc/apache2/sites-available"
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