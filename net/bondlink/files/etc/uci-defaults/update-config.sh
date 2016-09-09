#!/bin/sh /etc/rc.common

# Add the bonding interface to the WAN zone
# and basic configuration to network and
# firewall config to support the bonding
# of two internet links

. $IPKG_INSTROOT/lib/config/uci.sh

append_to_firewall_and_network_config() {


cat >> /etc/config/network  <<EOF


config interface 'bond0'
	option ifname 'bond0'
	option _orig_ifname 'bond0'
	option _orig_bridge 'false'
	option proto 'none'

config interface 'tun0'
	option proto 'none'
	option ifname 'tun0'

config interface 'tun1'
	option proto 'none'
	option ifname 'tun1'

EOF


cat >> /etc/config/firewall  <<EOF


config rule
	option name 'openvpn-udp-link0'
	option src 'wan'
	option dest_port '1194'
	option proto 'udp'
	option src_ip '172.0.0.1/32'

#
# Allow incoming UDP to openvpn link1 UDP port
#
config rule
	option name 'openvpn-udp-link1'
	option src 'wan'
	option dest_port '1195'
	option proto 'udp'
	option src_ip '172.0.0.1/32'
	option target 'ACCEPT'

#
# Put both tunnel interfaces into the bondzone and allow outgoing traffic
# Drop all incoming traffic
#
config zone
	option name 'bondzone'
	option output 'ACCEPT'
	option mtu_fix '1'
	option forward 'DROP'
	option input 'DROP'
	option masq '1'
	option conntrack '1'
	option log '1'
	option network 'tun0 tun1'

config forwarding
	option dest 'bondzone'
	option src 'lan'

config forwarding
	option dest 'bondzone'
	option src 'wan'

config forwarding
	option dest 'wan'
	option src 'bondzone'

EOF

}

update_wan_zone() {

	local bond="${1}"
    local section
    local value
	local found=0
	local ret=1

    uci_load firewall

    if [ $? -eq 0 ]; then

    	for section in $CONFIG_SECTIONS; do
			
			value=$(uci_get firewall ${section} name)

			if [ "${value}" == "wan" ]; then
			
				value=$(uci_get firewall ${section} network)

				for item in ${value}; do

					if [ "${item}" == "${bond}" ]; then
						found=1
					fi

				done

				if [ ${found} -eq 0 ]; then

					value="${value} ${bond}"
					uci_set firewall ${section} network "${value}"
					ret="$?"
					append_to_firewall_and_network_config

				fi
			fi
		done
	fi
	return ${ret}
}


append_to_openvpn_config() {


cat >> /etc/config/openvpn  <<EOF


# config openvpn tun0
#	option enabled 1
#	option config /etc/openvpn/tun0.conf

# config openvpn tun1
#	option enabled 1
#	option config /etc/openvpn/tun1.conf


EOF

}

update_wan_zone "bond0"
append_to_openvpn_config

[[ $? -eq 0 ]] && uci_commit firewall
exit $?
