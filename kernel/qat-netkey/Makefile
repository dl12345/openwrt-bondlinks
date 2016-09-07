#
# Copyright (C) 2010 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=qat-netkey
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_SOURCE_VERSION:=L.0.4.2-10
PKG_TAR_SOURCE:=icp_qat_netkey.$(PKG_SOURCE_VERSION).tar.gz
PKG_SOURCE:=qat_patches_netkeyshim.zip
PKG_SOURCE_URL:=https://01.org/sites/default/files/page/
PKG_MD5SUM:=48f20c019bb462643b91946984f8faf3

PKG_MAINTAINER:=dl12345 <dl12345@github.com>
PKG_LICENSE:=GPL v3

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_UNPACK:=unzip -pl $(DL_DIR)/$(PKG_SOURCE) */$(PKG_TAR_SOURCE) \
			| zcat | $(TAR) -C $(PKG_BUILD_DIR) --strip-components=1 -xf -

define KernelPackage/crypto-qat-netkey
  SUBMENU:=Cryptographic API modules
  TITLE:=Intel Quick Assist netkey shim for c2xxx
  DEPENDS:=kmod-crypto-qat-c2xxx +kmod-crypto-rng @TARGET_x86_c2xxx 
  FILES:=$(PKG_BUILD_DIR)/icp_qat_netkey.ko $(PKG_BUILD_DIR)/test/icp_perf_aead.ko
endef

define KernelPackage/crypto-qat-netkey/description
 Kernel drivers for Intel c2xxx Quick Assist Technology
 AEAD crypto acceleration (IPSEC)
endef

MAKE_VARS += ICP_ROOT="$(STAGING_DIR)/usr/icp" \
	CROSS_COMPILE="$(KERNEL_CROSS)" \
	KERNEL_SOURCE_ROOT="$(LINUX_DIR)" 

NETKEY_OPTS = PWD="$(PKG_BUILD_DIR)"
TEST_OPTS = PWD="$(PKG_BUILD_DIR)/test"

define Build/Compile
	$(call Build/Compile/Default,$(NETKEY_OPTS)) 
	$(call Build/Compile/Default,-C $(PKG_BUILD_DIR)/test $(TEST_OPTS))
endef

$(eval $(call KernelPackage,crypto-qat-netkey))
