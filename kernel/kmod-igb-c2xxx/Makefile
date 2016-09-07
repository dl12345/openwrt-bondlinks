#
# Copyright (C) 2010 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_BASE:=igb
KMOD_NAME:=$(PKG_BASE)-c2xxx
PKG_NAME:=kmod-$(KMOD_NAME)
PKG_VERSION:=5.3.5.3
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_BASE)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://downloads.sourceforge.net/project/e1000/igb%20stable/5.3.5.3/
PKG_MD5SUM:=3e74ca3ac738413ced9adb00d3f69977

PKG_MAINTAINER:=DL <dl12345@github.com>
PKG_LICENSE:=GPL v3

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

PKG_UNPACK:=zcat $(DL_DIR)/$(PKG_SOURCE) | $(TAR) -C $(PKG_BUILD_DIR) --strip-components=1 -xf -

MAKE_PATH:=src

MAKE_VARS:= \
	KSRC="$(LINUX_DIR)" 

MAKE_OPTS:= \
	ARCH="$(LINUX_KARCH)" \
	CROSS_COMPILE="$(KERNEL_CROSS)" 

# If the +kmod-ptp dependency goes before the @PCI_SUPPORT dependency
# a missing dependencies error will result. 

define KernelPackage/$(KMOD_NAME)
  SUBMENU:=Network Devices
  TITLE:=Intel(R) I354 Quad GbE Controller 
  DEPENDS:=+kmod-ptp @PCI_SUPPORT 
  KCONFIG:=CONFIG_IGB \
    CONFIG_IGB_HWMON=n \
    CONFIG_IGB_DCA=n
  FILES:=$(PKG_BUILD_DIR)/src/$(PKG_BASE).ko
  AUTOLOAD:=$(call AutoLoad,35,$(PKG_BASE))
endef

define KernelPackage/$(KMOD_NAME)/description
 Kernel modules for Intel(R) I354 Quad Gigabit Ethernet Controller
 Warning: do not select the core package kmod-igb as this is an
 updated version of the igb driver that shares the same module name
endef

$(eval $(call KernelPackage,$(KMOD_NAME)))
