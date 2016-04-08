#!/bin/bash
#=============================================================================
#
#  File      : vpnaas.sh
#  Date      : April 8th, 2016
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


#This script shows how to set the VPNaaS on a single openstack cloud between two virtual machines. 


usage() {
	echo "Usage: $0 [start | stop | status] <configName>"
	exit 1
}

writeVariable() {
	echo $* >> ${CONFIG_FILE}
}

start() {
	CONFIG_NAME=$2
	CONFIG_FILE=$2
	if [ -f ${CONFIG_FILE} ] ; then
		echo "VPNAAS error : config already exist. Cowardingly refusing to overwrite it"
		exit 1
	fi

	touch ${CONFIG_FILE}

#--------------------------------------------------
#Creating Private network  and its subnetwork 
#--------------------------------------------------
	KEY="NET1"
	NET1="${CONFIG_NAME}_net1"
	VALUE="${NET1}"
	neutron net-create ${NET1} && writeVariable "${KEY}=${VALUE}"
	KEY="SUBNET1"
	SUBNET1="${CONFIG_NAME}_subnet1"
	VALUE="${SUBNET1}"
	neutron subnet-create --name ${SUBNET1} ${NET1} 10.100.0.0/24 --gateway 10.100.0.1 && writeVariable "${KEY}=${VALUE}"
	KEY="ROUTER1"
	ROUTER1="${CONFIG_NAME}_router1"
	VALUE="${ROUTER1}"
	neutron router-create ${ROUTER1} && writeVariable "${KEY}=${VALUE}"
	neutron router-interface-add ${ROUTER1} ${SUBNET1}
	neutron router-gateway-set ${ROUTER1} public

	KEY="NET2"
	NET2="${CONFIG_NAME}_net2"
	VALUE="${NET2}"
	neutron net-create ${NET2} && writeVariable "${KEY}=${VALUE}"
	KEY="SUBNET2"
	SUBNET2="${CONFIG_NAME}_subnet2"
	VALUE="${SUBNET2}"
	neutron subnet-create --name ${SUBNET2} ${NET2} 20.200.0.0/24 --gateway 20.200.0.2 && writeVariable "${KEY}=${VALUE}"
	KEY="ROUTER2"
	ROUTER2="${CONFIG_NAME}_router2"
	VALUE="${ROUTER2}"
	neutron router-create ${ROUTER2} && writeVariable "${KEY}=${VALUE}"
	neutron router-interface-add ${ROUTER2} ${SUBNET2}
	neutron router-gateway-set ${ROUTER2} public

#---------------------------------------------------
#Starting a VM in each of the private networks
#---------------------------------------------------
	PRIVATE_NET1=`neutron net-list | grep "${NET1}" | cut -f 2 -d' '`
	KEY="VM1"
	VM1="${CONFIG_NAME}_vm1"
	VALUE="${VM1}"
	nova boot --key-name os-77345-demo --flavor 2 --image ubuntu14 --nic net-id=${PRIVATE_NET1} ${VM1}  && writeVariable "${KEY}=${VALUE}"
	FLOATINGIP1=`nova floating-ip-create | grep -vE 'Pool|--'| cut -d ' ' -f 4`
	KEY="FLOATINGIP1"
	VALUE="${FLOATINGIP1}"
	nova add-floating-ip ${VM1} $FLOATINGIP1 && writeVariable "${KEY}=${VALUE}"

	PRIVATE_NET2=`neutron net-list | grep "${NET2}" | cut -f 2 -d' '`
	KEY="VM2"
	VM2="${CONFIG_NAME}_vm2"
	VALUE="${VM2}"
	nova boot --key-name os-77345-demo --flavor 2 --image ubuntu14 --nic net-id=${PRIVATE_NET2} ${VM2} && writeVariable "${KEY}=${VALUE}"
	FLOATINGIP2=`nova floating-ip-create | grep -vE 'Pool|--'| cut -d ' ' -f 4`
	KEY="FLOATINGIP2"
	VALUE="${FLOATINGIP2}"
	nova add-floating-ip ${VM2} $FLOATINGIP2 && writeVariable "${KEY}=${VALUE}"

#Create VPN connections
	KEY="IKEPOLICY"
	IKEPOLICY="${CONFIG_NAME}_ikepolicy"
	VALUE="${IKEPOLICY}"
	neutron vpn-ikepolicy-create ${IKEPOLICY} && writeVariable "${KEY}=${VALUE}"
	KEY="IPSECPOLICY"
	IPSECPOLICY="${CONFIG_NAME}_ipsecpolicy"
	VALUE="${IPSECPOLICY}"
	neutron vpn-ipsecpolicy-create ${IPSECPOLICY} && writeVariable "${KEY}=${VALUE}"
	KEY="VPNSERVICE"
	VPNSERVICE="${CONFIG_NAME}_vpnservice"
	VALUE="${VPNSERVICE}"
	neutron vpn-service-create --name ${VPNSERVICE} --description "Mon service VPN1" ${ROUTER1} ${SUBNET1} && writeVariable "${KEY}=${VALUE}"

	KEY="CONNECTION"
	CONNECTION="${CONFIG_NAME}_connection"
	VALUE="${CONNECTION}"
	neutron ipsec-site-connection-create --name ${CONNECTION} --vpnservice-id ${VPNSERVICE} \
	   --ikepolicy-id ${IKEPOLICY} --ipsecpolicy-id ${IPSECPOLICY} --peer-address 172.24.4.227 \
	   --peer-id 172.24.4.227 --peer-cidr 10.100.0.0/24 --psk secret && writeVariable "${KEY}=${VALUE}"

	[ ! -s ${CONFIG_FILE} ] && rm -f ${CONFIG_FILE}
}

stop() {
	CONFIG_FILE=$2
	if [ ! -f ${CONFIG_FILE} ] ; then
		echo "VPNAAS \"${CONFIG_FILE}\" error : config not found"
		exit 1
	fi

	. ${CONFIG_FILE}

	nova delete ${VM1}
	nova delete ${VM2}

	nova floating-ip-delete ${FLOATINGIP1}
	nova floating-ip-delete ${FLOATINGIP2}

	neutron ipsec-site-connection-delete ${CONNECTION}
	neutron vpn-service-delete ${VPNSERVICE}

	neutron vpn-ipsecpolicy-delete ${IPSECPOLICY}
	neutron vpn-ikepolicy-delete ${IKEPOLICY}

	for i in `neutron port-list | grep -vE 'fixed_ips|--' | cut -f 2 -d' '` ; do neutron port-delete $i  ; done

	neutron router-interface-delete ${ROUTER2} ${SUBNET2}
	neutron router-delete ${ROUTER2}
	neutron net-delete ${NET2}

	neutron router-interface-delete ${ROUTER1} ${SUBNET1}
	neutron router-delete ${ROUTER1}
	neutron net-delete ${NET1}

	rm -f ${CONFIG_FILE}
}

status() {
	CONFIG_FILE=$2
	if [ ! -f ${CONFIG_FILE} ] ; then
		echo "VPNAAS \"${CONFIG_FILE}\" error : config not found"
		exit 1
	fi

	echo "VNPAAS \"${CONFIG_FILE}\": started"
	cat ${CONFIG_FILE}
}

[ $# -ne 2 ] && usage

case $1 in
	"start" )
		start $*
		;;
	"stop" )
		stop $*
		;;
	"status" )
		status $*
		;;
esac

