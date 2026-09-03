# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Copyright (C) 2026 Date Huang <tjjh89017@hotmail.com>

include $(TOPDIR)/rules.mk

PKG_NAME:=stunmesh-go
PKG_VERSION:=1.15.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/tjjh89017/stunmesh-go/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=bb8a79fecbaf40d332ec9797cbc17c164bf81f89503ca8717aed70614662c556

PKG_MAINTAINER:=Date Huang <tjjh89017@hotmail.com>
PKG_LICENSE:=LGPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE LICENSE.GPL

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

GO_PKG:=github.com/tjjh89017/stunmesh-go
GO_PKG_BUILD_PKG:=$(GO_PKG)
# Every built-in storage plugin (cloudflare, opendht) is pure Go and opts in
# through this tag; the contrib/ out-of-process plugins are not built.
GO_PKG_TAGS:=builtin_all

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/stunmesh-go
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=VPN
  TITLE:=WireGuard NAT traversal helper using STUN
  URL:=https://github.com/tjjh89017/stunmesh-go
  DEPENDS:=$(GO_ARCH_DEPENDS) +kmod-wireguard +ca-bundle
endef

define Package/stunmesh-go/description
  stunmesh-go discovers each WireGuard node's public endpoint via STUN,
  encrypts it with a Curve25519 sealed box, and shares it through a
  pluggable storage backend (Cloudflare DNS, OpenDHT, or your own script).
  Peers behind NAT find each other with no rendezvous server or relay.
endef

define Package/stunmesh-go/conffiles
/etc/stunmesh/config.yaml
endef

define Package/stunmesh-go/install
	$(call GoPackage/Package/Install/Bin,$(PKG_INSTALL_DIR))
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/stunmesh-go $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/stunmesh.init $(1)/etc/init.d/stunmesh
	$(INSTALL_DIR) $(1)/etc/stunmesh
	$(INSTALL_CONF) ./files/config.yaml $(1)/etc/stunmesh/config.yaml
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) ./files/stunmesh-go.upgrade $(1)/lib/upgrade/keep.d/stunmesh-go
endef

$(eval $(call GoBinPackage,stunmesh-go))
$(eval $(call BuildPackage,stunmesh-go))
