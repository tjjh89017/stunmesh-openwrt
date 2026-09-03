# Same base image as openwrt/gh-action-sdk@v11.
ARG CONTAINER=ghcr.io/openwrt/sdk
ARG ARCH=mips_24kc
FROM $CONTAINER:$ARCH

LABEL "com.github.actions.name"="OpenWrt SDK (prebuilt Go bootstrap)"

# Base image is read-only at build time, so the file must already be
# executable in the build context; ADD preserves that bit.
ADD openwrt-sdk-entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
