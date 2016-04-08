# Cyclone WP5 "Network as a Service"

This contains necessary files to automate network configuration on the fly.

1. Using OpenVPN
  * the [OpenVPN post install script](src/bash/openvpn-postint.sh) can be used to automate the installation of an OpenVPN server
  * the [Apache post install script](src/bash/openvpn-postint+apache.sh) shows an example of VPN usage. It can be used to install an OpenVPN server and automatically start an Apache server inside a VPN

2. Using OpenStack VPNaaS
  * the [vpnaas script](src/bash/vpnaas.sh) can be used to start, stop and get the status of a VPN using OpenStack VPNaaS

3. Using OpenNaaS
  * to be done

