# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Copyright (C) 2026 Date Huang <tjjh89017@hotmail.com>

include $(TOPDIR)/rules.mk

PKG_NAME:=stunmesh-provisioner
PKG_VERSION:=0.2.1
PKG_RELEASE:=3

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/tjjh89017/stunmesh-provisioner/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=7c071f7e88689cd5692b138e91956f993451032cc882f536e75d234590d885b3

PKG_MAINTAINER:=Date Huang <tjjh89017@hotmail.com>
PKG_LICENSE:=LGPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE LICENSE.GPL

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

# stunmesh-provisioner's module has two binaries: cmd/stunmesh-agent (the
# OpenWrt-side agent, meant to run on the device) and cmd/stunmesh-provd
# (the controller; upstream's own docs say it "is a normal Linux machine,
# not an OpenWrt router"). Upstream ships tested OpenWrt integration
# (contrib/openwrt/) for both binaries' init/hotplug scripts; the UCI
# config templates each package installs are this feed's own. Both are
# built here as two separate OpenWrt packages from this one Makefile
# (Package/stunmesh-agent and Package/stunmesh-provd, below, each named
# after the binary it installs): some operators want the controller on a
# router anyway, and whether that actually works well for a given
# deployment is that operator's call, not something to gatekeep at
# packaging time. GO_PKG_BUILD_PKG lists both so one Go build step
# produces both binaries; each package's own install macro then picks
# only the one binary it ships.
GO_PKG:=github.com/tjjh89017/stunmesh-provisioner
GO_PKG_BUILD_PKG:=$(GO_PKG)/cmd/stunmesh-agent $(GO_PKG)/cmd/stunmesh-provd
GO_PKG_LDFLAGS_X:=main.version=$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

# Named after the binary it ships, stunmesh-agent, not the upstream repo
# (stunmesh-provisioner) or directory -- consistent with the
# stunmesh-provd package below, and with how net/stunmesh-go's own
# package is named after its binary. This package was briefly published
# under the name "stunmesh-provisioner" (this feed's first release of
# it); see the note above $(eval $(call BuildPackage,stunmesh-agent))
# below for why that rename ships with no compatibility shim.
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

# NOTE: files/stunmesh-agent.config's UCI type ("stunmesh-agent", renamed
# from "provd") does not yet match what the init/hotplug scripts below
# read: those still come from the upstream 0.2.1 tarball's
# contrib/openwrt/, which still loads UCI package "provd". Do not merge
# this rename until upstream ships a contrib/openwrt/ that reads
# "stunmesh-agent" and PKG_VERSION here is bumped to that release --
# see the PR description.
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

# No PROVIDES/replaces compatibility shim for the earlier
# "stunmesh-provisioner" package name: this feed published that name for
# the first time only hours before this rename, so realistically nobody
# has it installed. apk's PROVIDES exists for virtual/alternative
# packages satisfying a dependency, not for migrating an already
# -installed package's own name forward on upgrade (that needs a
# "replaces" relationship apk does not resolve automatically here
# either); building that path correctly for one package's few-hour-old
# name would add untested complexity for near-zero benefit. Anyone who
# did install "stunmesh-provisioner" in that window can
# "apk del stunmesh-provisioner && apk add stunmesh-agent" by hand.
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
  anyway: its procd init script comes from upstream's contrib/openwrt/
  (adapted from what this feed originally wrote for it); its UCI config
  template below is this feed's own, not upstream's. Whether the
  controller performs well on your hardware is your call to make. It
  installs disabled -- see /etc/config/stunmesh-provd and
  docs/quick-start.md in this repo before enabling it.
endef

# NOTE: like stunmesh-agent above, this package's init script now comes
# from upstream's contrib/openwrt/stunmesh-provd.init (a parallel
# stunmesh-provisioner PR adds it there, adapted from this feed's former
# files/stunmesh-provd.init). The 0.2.1 tarball has no such file. Do not
# merge this change until upstream ships it and PKG_VERSION here is
# bumped to that release -- see the PR description.
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

# Installed disabled: an operator must provision the tree (stunmesh-provd
# init / node add) and review /etc/config/stunmesh-provd before this
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
