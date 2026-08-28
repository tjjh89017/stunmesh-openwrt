# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Copyright (C) 2026 Date Huang <tjjh89017@hotmail.com>

include $(TOPDIR)/rules.mk

PKG_NAME:=stunmesh-provisioner
PKG_VERSION:=0.1.1
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/tjjh89017/stunmesh-provisioner/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=6f0524e6907812f482e14c8840634fc915b983feca33ef44c4f9aa3059516c58

PKG_MAINTAINER:=Date Huang <tjjh89017@hotmail.com>
PKG_LICENSE:=LGPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE LICENSE.GPL

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

# stunmesh-provisioner's module has two binaries: cmd/stunmesh-agent (the
# OpenWrt-side agent, meant to run on the device -- upstream ships tested
# OpenWrt integration for it, contrib/openwrt/) and cmd/stunmesh-provd (the
# controller; upstream's own docs say it "is a normal Linux machine, not an
# OpenWrt router" and ship no OpenWrt integration for it at all). Both are
# built here as two separate OpenWrt packages from this one Makefile
# (Package/stunmesh-provisioner and Package/stunmesh-provd, below): some
# operators want the controller on a router anyway, and whether that
# actually works well for a given deployment is that operator's call, not
# something to gatekeep at packaging time. GO_PKG_BUILD_PKG lists both
# so one Go build step produces both binaries; each package's own
# install macro then picks only the one binary it ships.
GO_PKG:=github.com/tjjh89017/stunmesh-provisioner
GO_PKG_BUILD_PKG:=$(GO_PKG)/cmd/stunmesh-agent $(GO_PKG)/cmd/stunmesh-provd
GO_PKG_LDFLAGS_X:=main.version=$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/stunmesh-provisioner
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=VPN
  TITLE:=stunmesh-provisioner agent (DHT-provisioned WireGuard config fetcher)
  URL:=https://github.com/tjjh89017/stunmesh-provisioner
  DEPENDS:=$(GO_ARCH_DEPENDS) +kmod-wireguard +wireguard-tools +ca-bundle
endef

define Package/stunmesh-provisioner/description
  stunmesh-provisioner provisions stunmesh-go nodes on OpenWrt devices from a
  central controller. This package ships stunmesh-agent, the on-device half:
  it fetches an encrypted WireGuard/stunmesh-go config bundle published to
  OpenDHT (via dhtproxy) by the controller, decrypts it with this node's
  identity key, and applies it through uci/ubus. stunmesh-agent runs once
  per invocation (cron- and hotplug-driven, not a daemon); it is not useful
  standalone until an operator runs the manual key exchange with a
  stunmesh-provd controller -- see the upstream docs/quick-start.md. The
  controller itself is the separate stunmesh-provd package.
endef

define Package/stunmesh-provisioner/conffiles
/etc/config/provd
endef

define Package/stunmesh-provisioner/install
	$(call GoPackage/Package/Install/Bin,$(PKG_INSTALL_DIR))
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/stunmesh-agent $(1)/usr/sbin/stunmesh-agent
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/contrib/openwrt/stunmesh-agent.init $(1)/etc/init.d/stunmesh-agent
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/contrib/openwrt/hotplug-iface $(1)/etc/hotplug.d/iface/95-stunmesh-agent
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/provd.config $(1)/etc/config/provd
endef

$(eval $(call GoBinPackage,stunmesh-provisioner))
$(eval $(call BuildPackage,stunmesh-provisioner))

define Package/stunmesh-provd
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=VPN
  TITLE:=stunmesh-provisioner controller (publishes DHT-provisioned WireGuard bundles)
  URL:=https://github.com/tjjh89017/stunmesh-provisioner
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle
endef

define Package/stunmesh-provd/description
  stunmesh-provd is the stunmesh-provisioner *controller*: it holds every
  node's tunnel and identity keys and publishes their encrypted
  WireGuard/stunmesh-go config bundles to OpenDHT (via dhtproxy) for each
  node's stunmesh-agent to fetch. Upstream's own docs describe the
  controller as meant to run on "a normal Linux machine, not an OpenWrt
  router," and ship no OpenWrt integration for it (contrast with
  stunmesh-agent, which upstream does test on OpenWrt). This package is for
  operators who want to run it on a router anyway; this init script and UCI
  config are this feed's own addition, not upstream's, and whether the
  controller performs well on your hardware is your call to make. It
  installs disabled -- see /etc/config/provd_controller and
  docs/quick-start.md in stunmesh-provisioner before enabling it.
endef

define Package/stunmesh-provd/conffiles
/etc/config/provd_controller
endef

define Package/stunmesh-provd/install
	$(call GoPackage/Package/Install/Bin,$(PKG_INSTALL_DIR))
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/stunmesh-provd $(1)/usr/sbin/stunmesh-provd
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/stunmesh-provd.init $(1)/etc/init.d/stunmesh-provd
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/provd_controller.config $(1)/etc/config/provd_controller
endef

# Installed disabled: an operator must provision the tree (stunmesh-provd
# init / node add) and review /etc/config/provd_controller before this
# should run at all. The default postinst that "$(INSTALL_BIN) ... /etc/
# init.d/$1" would otherwise generate calls "/etc/init.d/$1 enable" on
# install; this empty override replaces it with a no-op so the service
# stays disabled until the operator runs that enable themselves.
define Package/stunmesh-provd/postinst
#!/bin/sh
exit 0
endef

$(eval $(call GoBinPackage,stunmesh-provd))
$(eval $(call BuildPackage,stunmesh-provd))
