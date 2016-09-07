#
# Copyright (C) 2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=bondlink
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_SOURCE:=
PKG_SOURCE_URL:=
PKG_MD5SUM:=

PKG_MAINTAINER:=dl12345 dl12345@github.com
PKG_LICENSE:=GPL v3

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

PATCH_NAME:=999-bonding-empty-mac-address.patch
PATCH_FILE:=patches-$(KERNEL_PATCHVER)/$(PATCH_NAME)
PATCH_TARGET:=$(TOPDIR)/target/linux/generic/patches-$(KERNEL_PATCHVER)

define Package/bondlink
  CATEGORY:=Network
  TITLE:=Link bonding support
  DEPENDS:=+kmod-bonding +firewall +openvpn-openssl +ip-full +socat +python 
endef

define Package/bondlink/description
Kernel module for bonding multiple internet links
This module replaces the kernel bonding driver with a 
modified version patched to allow the bonding of point 
to point interfaces. This driver will likely break 
other bonding applications.

BEFORE launching a top-level or a kernel make, you
MUST call this package's prepare target in order to
install the patch in the kernel source. The patch will
be installed in the kernel package target patches 
folder and will persist across a make clean 

	make package/bondlink/prepare V=s

Failure to perform this step will not install the patch 
to the bonding driver and the scripts will not work.
endef

define Build/Prepare
	$(CP) $(PATCH_FILE) $(PATCH_TARGET)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/bondlink/conffiles
/etc/config/bonding
endef

define Package/bondlink-base-files/description
This package contains base files for the bondlink package
endef

define Package/bondlink/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/bonding
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_CONF) files/etc/config/bonding $(1)/etc/config/bonding
	$(INSTALL_BIN) files/etc/uci-defaults/update-config.sh $(1)/etc/uci-defaults/update-config.sh
	$(INSTALL_BIN) files/etc/init.d/bonding $(1)/etc/init.d/bonding
	$(INSTALL_BIN) files/etc/bonding/bonding-preup.sh $(1)/etc/bonding/bonding-preup.sh
	$(INSTALL_BIN) files/etc/bonding/bonding-up.sh $(1)/etc/bonding/bonding-up.sh
	$(INSTALL_BIN) files/etc/bonding/ifdown-local $(1)/etc/bonding/ifdown-local
	$(INSTALL_BIN) files/etc/bonding/tun0-down.sh $(1)/etc/bonding/tun0-down.sh
	$(INSTALL_BIN) files/etc/bonding/tun0-up.sh $(1)/etc/bonding/tun0-up.sh
	$(INSTALL_BIN) files/etc/bonding/tun1-down.sh $(1)/etc/bonding/tun1-down.sh
	$(INSTALL_BIN) files/etc/bonding/tun1-up.sh $(1)/etc/bonding/tun1-up.sh
	$(INSTALL_BIN) files/etc/bonding/watchbond.sh $(1)/etc/bonding/watchbond.sh
	$(INSTALL_BIN) files/etc/bonding/ifup-local $(1)/etc/bonding/ifup-local
	$(INSTALL_BIN) files/etc/bonding/restartbonding.sh $(1)/etc/bonding/restartbonding.sh
	$(INSTALL_BIN) files/etc/hotplug.d/iface/60-local $(1)/etc/hotplug.d/iface/60-local
	$(INSTALL_BIN) files/usr/bin/speedtest_cli $(1)/usr/bin/speedtest_cli
endef

define Package/bondlink/postinst
#!/bin/sh /etc/rc.common

# Add the bonding interface to the WAN zone
# and basic configuration to network and
# firewall config to support the bonding
# of two internet links

if [ -n "$${IPKG_INSTROOT}" ]; then
	rm -f /etc/uci_defaults/upgrade-config.sh
	exit 0
fi

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
	return "${ret}"
}

update_wan_zone "bond0"

[[ $? -eq 0 ]] && uci_commit firewall
exit $?
endef

$(eval $(call BuildPackage,bondlink))

