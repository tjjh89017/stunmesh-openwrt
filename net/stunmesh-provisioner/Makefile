# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Copyright (C) 2026 Date Huang <tjjh89017@hotmail.com>

include $(TOPDIR)/rules.mk

PKG_NAME:=stunmesh-provisioner
PKG_VERSION:=0.4.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/tjjh89017/stunmesh-provisioner/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=0b26b2dda5f0d198fa428fc61ceaf9ca47a9d02065cef69dcaf78c9e704d566b

PKG_MAINTAINER:=Date Huang <tjjh89017@hotmail.com>
PKG_LICENSE:=LGPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE LICENSE.GPL

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

# stunmesh-provisioner's module has two binaries: cmd/stunmesh-agent and
# cmd/stunmesh-provd, built as two packages below (Package/stunmesh-agent,
# Package/stunmesh-provd). GO_PKG_BUILD_PKG lists both so one Go build
# step produces both; each package's install macro picks its own binary.
GO_PKG:=github.com/tjjh89017/stunmesh-provisioner
GO_PKG_BUILD_PKG:=$(GO_PKG)/cmd/stunmesh-agent $(GO_PKG)/cmd/stunmesh-provd
GO_PKG_LDFLAGS_X:=main.version=$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

# Named after the binary it ships, not the upstream repo/directory name.
define Package/stunmesh-agent
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=VPN
  TITLE:=stunmesh-provisioner agent (DHT-provisioned WireGuard config fetcher)
  URL:=https://github.com/tjjh89017/stunmesh-provisioner
  DEPENDS:=$(GO_ARCH_DEPENDS) +kmod-wireguard +wireguard-tools +ca-bundle
endef

define Package/stunmesh-agent/description
  stunmesh-provisioner provisions stunmesh-go nodes on OpenWrt devices from a
  central controller. This package ships stunmesh-agent, the on-device half:
  it fetches an encrypted WireGuard/stunmesh-go config bundle published to
  OpenDHT (via dhtproxy) by the controller, decrypts it with this node's
  identity key, and applies it through uci/ubus. stunmesh-agent runs once
  per invocation (cron- and hotplug-driven, not a daemon); it is not useful
  standalone until an operator runs the manual key exchange with a
  stunmesh-provd controller -- see this repo's docs/quick-start.md. The
  controller itself is the separate stunmesh-provd package.
endef

define Package/stunmesh-agent/conffiles
/etc/config/stunmesh-agent
endef

define Package/stunmesh-agent/install
	$(call GoPackage/Package/Install/Bin,$(PKG_INSTALL_DIR))
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/stunmesh-agent $(1)/usr/sbin/stunmesh-agent
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/contrib/openwrt/stunmesh-agent.init $(1)/etc/init.d/stunmesh-agent
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/contrib/openwrt/hotplug-iface $(1)/etc/hotplug.d/iface/95-stunmesh-agent
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/stunmesh-agent.config $(1)/etc/config/stunmesh-agent
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) ./files/stunmesh-agent.upgrade $(1)/lib/upgrade/keep.d/stunmesh-agent
endef

# No PROVIDES/replaces shim for the earlier "stunmesh-provisioner" name:
# it shipped too briefly for a migration path to be worth building.
# Anyone who has it installed can "apk del stunmesh-provisioner && apk
# add stunmesh-agent" by hand.
$(eval $(call GoBinPackage,stunmesh-agent))
$(eval $(call BuildPackage,stunmesh-agent))

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
  router." This package is for operators who want to run it on a router
  anyway. It installs disabled -- see /etc/config/stunmesh-provd and
  docs/quick-start.md in this repo before enabling it.
endef

define Package/stunmesh-provd/conffiles
/etc/config/stunmesh-provd
endef

define Package/stunmesh-provd/install
	$(call GoPackage/Package/Install/Bin,$(PKG_INSTALL_DIR))
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/stunmesh-provd $(1)/usr/sbin/stunmesh-provd
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/contrib/openwrt/stunmesh-provd.init $(1)/etc/init.d/stunmesh-provd
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/stunmesh-provd.config $(1)/etc/config/stunmesh-provd
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) ./files/stunmesh-provd.upgrade $(1)/lib/upgrade/keep.d/stunmesh-provd
endef

# Overrides the default postinst (which would auto-enable the service)
# so it stays disabled until the operator enables it by hand.
define Package/stunmesh-provd/postinst
#!/bin/sh
exit 0
endef

$(eval $(call GoBinPackage,stunmesh-provd))
$(eval $(call BuildPackage,stunmesh-provd))
