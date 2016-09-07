#
# Copyright (C) 2010 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=qat-c2xxx
PKG_VERSION:=1.5
PKG_RELEASE:=1

PKG_SOURCE_VERSION:=l.2.5.0-80
PKG_SOURCE:=qatmux.$(PKG_SOURCE_VERSION).tar_1.gz
PKG_SOURCE_URL:=https://01.org/sites/default/files/downloads/packet-processing/
PKG_MD5SUM:=e3c2ceeec7ed8b36d75682742caff81e

PKG_MAINTAINER:=Felix Fietkau <nbd@openwrt.org>
PKG_LICENSE:=GPL v3

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

QAT_VERSION:=1.5
QAT_RELEASE:=L.1.10.0-80
QAT_SOURCE:=QAT$(QAT_VERSION).$(QAT_RELEASE).tar.gz
QAT_BUILD_DIR:=$(PKG_BUILD_DIR)/quickassist

CRYPTO_MENU=Cryptographic API modules

define KernelPackage/crypto-qat-c2xxx
  SUBMENU:=$(CRYPTO_MENU)
  TITLE:=Intel Quick Assist Technology for c2xxx
  DEPENDS:= \
	+libc +libpthread +libopenssl \
  	+kmod-crypto-manager +kmod-crypto-aes \
	+kmod-crypto-sha256 +kmod-crypto-sha512 \
	@TARGET_x86_c2xxx
  FILES:=$(PKG_BUILD_DIR)/build/icp_qa_al.ko
endef

define KernelPackage/crypto-qat-c2xxx/description
 Kernel drivers for Intel c2xxx Quick Assist Technology
endef

define KernelPackage/crypto-qat-c2xxx/config
source "$(SOURCE)/Config.in"
endef

ifdef CONFIG_CRYPTO_QAT_c2xxx_DEBUG

DEBUG_FLAGS = \
	ICP_DEBUG="1" \
	ADF_ACCEL_MGR_DEBUG="1" \
	ADF_DRIVERS_DEBUG="1" \
	ADF_PLATFORM_DEBUG="1" \
	ADF_TRANSPORT_DEBUG="1" \
	ADF_CONFIG_DEBUG="1" \
	ADF_USER_PROXY_DEBUG="1" \
	EXTRA_CFLAGS="-D_DEBUG_" 

else

DEBUG_FLAGS = 

endif

MAKE_VARS += ICP_ROOT="$(PKG_BUILD_DIR)" \
	$(DEBUG_FLAGS) \
	CROSS_COMPILE="$(KERNEL_CROSS)" \
	CC="$(KERNEL_CROSS)gcc" \
	LD="$(KERNEL_CROSS)ld" \
	KERNEL_SOURCE_ROOT="$(LINUX_DIR)" \
	MACHINE="x86_64" \
	ICP_BUILD_OUTPUT="$(PKG_BUILD_DIR)/build" \
	ICP_ENV_DIR="$(PKG_BUILD_DIR)/quickassist/build_system/build_files/env_files" \
	ICP_BUILDSYSTEM_PATH="$(PKG_BUILD_DIR)/quickassist/build_system" \
	ICP_TOOLS_TARGET="accelcomp" \
	LIB_SHARED_FLAGS="-L$(STAGING_DIR)/usr/lib" \
	LD_LIBRARY_PATH="$(LD_LIBRARY_PATH):$(PKG_BUILD_DIR)/build" 

define Build/Prepare
	(mkdir -p '$(PKG_BUILD_DIR)' && zcat '$(DL_DIR)/$(PKG_SOURCE)' | tar -C '$(PKG_BUILD_DIR)' -xf -)
	(cd '$(PKG_BUILD_DIR)' && tar xzf 'QAT$(QAT_VERSION)/$(QAT_SOURCE)')
	$(Build/Patch)
endef

define Build/Compile
	$(call Build/Compile/Default,-C $(QAT_BUILD_DIR) ARCH_USER=x86_64)
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR)/usr/include
	$(INSTALL_DIR) $(STAGING_DIR)/usr/lib
	$(INSTALL_DIR) $(STAGING_DIR)/usr/icp/quickassist
	$(INSTALL_DIR) $(STAGING_DIR)/usr/icp/build
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/build/*.a $(STAGING_DIR)/usr/lib/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/build/*.so $(STAGING_DIR)/usr/lib/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/quickassist/include/*.h $(STAGING_DIR)/usr/include/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/quickassist/include/dc/*.h $(STAGING_DIR)/usr/include/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/quickassist/include/lac/*.h $(STAGING_DIR)/usr/include/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/quickassist/lookaside/access_layer/include/*.h $(STAGING_DIR)/usr/include
	$(CP) $(PKG_BUILD_DIR)/quickassist $(STAGING_DIR)/usr/icp
	$(CP) $(PKG_BUILD_DIR)/build $(STAGING_DIR)/usr/icp
endef

define KernelPackage/crypto-qat-c2xxx/install
	$(INSTALL_DIR) $(1)/lib/modules/$(LINUX_VERSION)
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/lib/firmware
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/quickassist/config/c2xxx_qa_dev0_single_ae.conf $(1)/etc/c2xxx_qa_dev0.conf
	$(INSTALL_BIN) ./files/qat.init $(1)/etc/init.d/qat
	$(INSTALL_BIN) ./files/qat_watchdog.init $(1)/etc/init.d/qat_watchdog
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/adf_ctl $(1)/usr/sbin/adf_ctl
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/icp_gige_watchdog $(1)/usr/sbin/icp_gige_watchdog
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/build/*.a $(1)/lib/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/build/*.so $(1)/lib/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/build/*.bin $(1)/lib/firmware/
endef

$(eval $(call KernelPackage,crypto-qat-c2xxx))
