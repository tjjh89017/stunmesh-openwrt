# Same base image as openwrt/gh-action-sdk@v11 (its own Dockerfile has
# these two ARGs and this one FROM line). This wraps that image's own
# entrypoint with a patched copy: see openwrt-sdk-entrypoint.sh for why.
ARG CONTAINER=ghcr.io/openwrt/sdk
ARG ARCH=mips_24kc
FROM $CONTAINER:$ARCH

LABEL "com.github.actions.name"="OpenWrt SDK (prebuilt Go bootstrap)"

# No RUN chmod here: the base image's filesystem is not writable at
# build time by a RUN step (matches gh-action-sdk@v11's own Dockerfile).
# The file must already be executable in the build context; ADD/COPY
# preserve that bit.
ADD openwrt-sdk-entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
