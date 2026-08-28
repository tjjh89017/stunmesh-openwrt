# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Copyright (C) 2026 Date Huang <tjjh89017@hotmail.com>

include $(TOPDIR)/rules.mk

PKG_NAME:=stunmesh-provisioner
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/tjjh89017/stunmesh-provisioner/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=f367c6f40be28383226b8a685e866e383f6142f66f959270968eb7e4eabb8054

PKG_MAINTAINER:=Date Huang <tjjh89017@hotmail.com>
PKG_LICENSE:=LGPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE LICENSE.GPL

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

# stunmesh-provisioner's module has two binaries: cmd/stunmesh-provd (the
# controller, meant to run off-router as a systemd service or container --
# see the upstream README) and cmd/stunmesh-agent (the OpenWrt-side agent,
# meant to run on the device). Only stunmesh-agent belongs on the router, so
# GO_PKG_BUILD_PKG points at that one subpackage and stunmesh-provd is never
# built here.
GO_PKG:=github.com/tjjh89017/stunmesh-provisioner
GO_PKG_BUILD_PKG:=$(GO_PKG)/cmd/stunmesh-agent
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
  stunmesh-provd controller -- see the upstream docs/quick-start.md.
  stunmesh-provd itself (the controller) is not part of this package; it is
  meant to run off-router.
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
