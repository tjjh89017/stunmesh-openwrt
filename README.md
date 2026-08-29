# stunmesh-openwrt

OpenWrt package feed for two related projects:

- [stunmesh-go](https://github.com/tjjh89017/stunmesh-go) (package `stunmesh-go`) --
  a WireGuard helper that connects peers behind NAT with STUN and no rendezvous server.
- [stunmesh-provisioner](https://github.com/tjjh89017/stunmesh-provisioner) --
  a central-controller provisioning system for stunmesh-go nodes, packaged
  here as two packages:
  - `stunmesh-agent` -- the on-device half. It fetches an encrypted
    WireGuard/stunmesh-go config bundle from a `stunmesh-provd` controller
    (via OpenDHT/dhtproxy) and applies it through uci/ubus. Upstream tests
    this on OpenWrt.
  - `stunmesh-provd` -- the controller itself. Upstream's own docs say it
    "is a normal Linux machine, not an OpenWrt router." This package's
    procd init script comes from upstream's OpenWrt integration
    (adapted from what this feed originally wrote for it); its UCI config
    is this feed's own addition, for operators who want to run the
    controller on a router anyway. It installs disabled.

Signed apk feed: **https://tjjh89017.github.io/stunmesh-openwrt/**

Both packages are built from source with the OpenWrt Go toolchain. Both
upstream modules need Go 1.25+, so this feed targets **OpenWrt 25.12 and
SNAPSHOT** (24.10 ships Go 1.23). On 24.10, use stunmesh-go's own
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

### stunmesh-agent (the on-device half)

Same key, same feed as above -- just a different package:

```sh
apk add stunmesh-agent wireguard-tools kmod-wireguard
stunmesh-agent keygen --identity-key /etc/stunmesh/provd/identity.key
```

`keygen` prints this node's identity public key. Send it to the controller
operator running `stunmesh-provd`; they run `node add` and send back
`NAMESPACE`, `NODE_ID`, `CONTROLLER_PUBKEY`, and the `DHT_PROXY` list. Fill
those into `/etc/config/stunmesh-agent` (installed with placeholders and inline
instructions), then:

```sh
service stunmesh-agent enable
service stunmesh-agent start
```

`stunmesh-agent fetch` is not a daemon: `start` runs one fetch in the
background after `boot_delay` seconds and installs a cron line that repeats
it every `fetch_interval` minutes, plus a WAN-up hotplug trigger. See
[`docs/quick-start.md`](docs/quick-start.md) and upstream's
`contrib/openwrt/README.md` in
[stunmesh-provisioner](https://github.com/tjjh89017/stunmesh-provisioner)
for the full walkthrough (controller setup, `wg.yaml`, troubleshooting).

### stunmesh-provd (the controller, on a router)

```sh
apk add stunmesh-provd
stunmesh-provd --dir /etc/stunmesh/provd init <namespace>
stunmesh-provd --dir /etc/stunmesh/provd node add <namespace> <node_id>
```

Fill `/etc/config/stunmesh-provd` (installed disabled, with inline
instructions), then `service stunmesh-provd enable && service stunmesh-provd
start` runs the republish loop until `service stunmesh-provd stop`. See
[`docs/quick-start.md`](docs/quick-start.md) for the full controller walkthrough
(`wg.yaml`, `stunmesh.yaml`, publishing).

## Install a single package by hand

The feed directories are plain files, so a package can also be fetched
directly from https://tjjh89017.github.io/stunmesh-openwrt/ and installed
with `apk add ./stunmesh-go-*.apk`, `apk add ./stunmesh-agent-*.apk`, or
`apk add ./stunmesh-provd-*.apk` (after installing the key as above, or with
`--allow-untrusted`).

stunmesh-go's service restarts itself when `/etc/stunmesh/config.yaml`
changes or the network is reloaded, since it reads the WireGuard device once
at startup. stunmesh-agent is cron- and hotplug-driven instead, and
stunmesh-provd is a plain long-running daemon; see above.

## Build from the SDK

```sh
echo "src-git stunmesh https://github.com/tjjh89017/stunmesh-openwrt.git" >> feeds.conf.default
./scripts/feeds update -a && ./scripts/feeds install stunmesh-go stunmesh-agent stunmesh-provd
make package/stunmesh-go/compile V=s
make package/stunmesh-provisioner/compile V=s
```

`stunmesh-agent` and `stunmesh-provd` both come from
`net/stunmesh-provisioner/Makefile` (named after the upstream project, not
after either package), so `feeds install` accepts either package name, but
the actual build target is the *directory* name -- `make
package/stunmesh-provisioner/compile` builds both packages' `.apk` in one
pass; there is no `make package/stunmesh-agent/compile` or
`package/stunmesh-provd/compile` target.

## Layout

```
net/stunmesh-go/Makefile                          package definition (golang-package.mk)
net/stunmesh-go/files/stunmesh.init               procd service
net/stunmesh-go/files/config.yaml                 template installed to /etc/stunmesh/ (conffile)
net/stunmesh-provisioner/Makefile                 defines two packages, stunmesh-agent and
                                                   stunmesh-provd (golang-package.mk builds both
                                                   cmd/stunmesh-agent and cmd/stunmesh-provd in one
                                                   pass); both packages' init/hotplug scripts are
                                                   installed straight out of the fetched upstream
                                                   source tarball (contrib/openwrt/); the UCI config
                                                   templates below are this feed's own
net/stunmesh-provisioner/files/stunmesh-agent.config    stunmesh-agent template, /etc/config/stunmesh-agent (conffile)
net/stunmesh-provisioner/files/stunmesh-provd.config    stunmesh-provd template, /etc/config/stunmesh-provd (conffile)
keys/stunmesh.pem                     public half of the apk signing key (private half: APK_PRIVATE_KEY secret)
.github/actions/build                 composite action: SDK build for one arch/release/directory,
                                       signs and collects one subdirectory per package it owns
                                       ("select"), verifying each actually produced a file
.github/actions/matrix                composite action: stable branches >= 25.12 with a published SDK
                                       image, the arch list, and the package/directory map (discovered
                                       from every "define Package/<name>" in */*/Makefile, so a new
                                       package or directory needs no workflow edit)
.github/scripts/reindex.sh            runs inside the SDK container: rebuilds and signs one shared
                                       packages.adb per release/arch from every package's .apk, then
                                       verifies it parses, lists every expected package, and the
                                       signature checks out against keys/stunmesh.pem -- a failure
                                       here fails CI instead of publishing a broken feed
.github/workflows/build.yml           CI matrix (release x arch x directory) builds each directory
                                       once; a second matrix (release x arch x package) fans that back
                                       out into one artifact per real package; on main, the feed job
                                       merges them, rebuilds the shared index, and publishes to Pages
```

## Updating to a new release

Bump that package's `PKG_VERSION`, reset `PKG_RELEASE` to 1, and refresh `PKG_HASH`:

```sh
# stunmesh-go
curl -sL "https://codeload.github.com/tjjh89017/stunmesh-go/tar.gz/v<ver>" | sha256sum
# stunmesh-provisioner
curl -sL "https://codeload.github.com/tjjh89017/stunmesh-provisioner/tar.gz/v<ver>" | sha256sum
```

Packaging-only changes (init script, config template) bump `PKG_RELEASE`
instead. Every push to `main` rebuilds and republishes the feed for every
package in `net/*/Makefile`; there are no separate releases.

## Adding a package to this feed

Drop a new `<category>/<name>/Makefile` (following the layout above) anywhere
in the tree -- CI discovers it automatically (see `.github/actions/matrix`'s
"Packages" step) and adds it to every future build and to the shared feed
index. No workflow file needs editing.

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
