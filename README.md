# stunmesh-openwrt

OpenWrt package feed for [stunmesh-go](https://github.com/tjjh89017/stunmesh-go),
a WireGuard helper that connects peers behind NAT with STUN and no rendezvous server.

Signed apk feed: **https://tjjh89017.github.io/stunmesh-openwrt/**

The package is built from source with the OpenWrt Go toolchain. stunmesh-go needs
Go 1.25+, so it targets **OpenWrt 25.12 and SNAPSHOT** (24.10 ships Go 1.23).
On 24.10 use the upstream
[`openwrt-install.sh`](https://github.com/tjjh89017/stunmesh-go/blob/main/scripts/openwrt-install.sh)
instead.

## Install from the signed feed (recommended)

Every push to `main` publishes a signed apk repository to GitHub Pages, one per
OpenWrt release and architecture. On the router:

```sh
wget -O /etc/apk/keys/stunmesh.pem https://tjjh89017.github.io/stunmesh-openwrt/stunmesh.pem
. /etc/os-release
echo "https://tjjh89017.github.io/stunmesh-openwrt/openwrt-25.12/$OPENWRT_ARCH/packages.adb" \
  > /etc/apk/repositories.d/stunmesh.list
apk update
apk add stunmesh-go
vi /etc/stunmesh/config.yaml
service stunmesh enable
service stunmesh start
```

Replace `openwrt-25.12` with `SNAPSHOT` on snapshot builds, or with whatever
stable branch you run; https://tjjh89017.github.io/stunmesh-openwrt/ lists the
available feeds. `apk upgrade` then picks up new versions like any other package.

The key fingerprint can be checked against `keys/stunmesh.pem` in this repo.

## Install a single package by hand

The feed directories are plain files, so a package can also be fetched
directly from https://tjjh89017.github.io/stunmesh-openwrt/ and installed
with `apk add ./stunmesh-go-*.apk` (after installing the key as above, or
with `--allow-untrusted`).

The service restarts itself when `/etc/stunmesh/config.yaml` changes or the
network is reloaded, since stunmesh-go reads the WireGuard device once at startup.

## Build from the SDK

```sh
echo "src-git stunmesh https://github.com/tjjh89017/stunmesh-openwrt.git" >> feeds.conf.default
./scripts/feeds update -a && ./scripts/feeds install stunmesh-go
make package/stunmesh-go/compile V=s
```

## Layout

```
net/stunmesh-go/Makefile              package definition (golang-package.mk)
net/stunmesh-go/files/stunmesh.init   procd service
net/stunmesh-go/files/config.yaml     template installed to /etc/stunmesh/ (conffile)
keys/stunmesh.pem                     public half of the apk signing key (private half: APK_PRIVATE_KEY secret)
.github/actions/build                 composite action: signed SDK build + index for one arch/release
.github/actions/matrix                composite action: stable branches >= 25.12 with a published SDK image, plus arch list
.github/workflows/build.yml           CI matrix on push/PR; on main also publishes the feed to Pages
```

## Updating to a new stunmesh-go release

Bump `PKG_VERSION`, reset `PKG_RELEASE` to 1, and refresh `PKG_HASH`:

```sh
curl -sL "https://codeload.github.com/tjjh89017/stunmesh-go/tar.gz/v<ver>" | sha256sum
```

Packaging-only changes (init script, config template) bump `PKG_RELEASE`
instead. Every push to `main` rebuilds and republishes the feed; there are no
separate releases.

## Signing key

Packages and indexes are signed by the SDK with the EC P-256 key in the
`APK_PRIVATE_KEY` repository secret; `keys/stunmesh.pem` is its public half.
To rotate: generate a new pair, update the secret and `keys/stunmesh.pem`,
and reinstall the key on every router.

```sh
openssl ecparam -name prime256v1 -genkey -noout -out apk-private-key.pem
openssl ec -in apk-private-key.pem -pubout -out keys/stunmesh.pem
gh secret set APK_PRIVATE_KEY < apk-private-key.pem
```

## License

LGPL-3.0-or-later, same as stunmesh-go. See [LICENSE](LICENSE) (LGPL-3.0)
and [LICENSE.GPL](LICENSE.GPL) (GPL-3.0, which the LGPL supplements).
