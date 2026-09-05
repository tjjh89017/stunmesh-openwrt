#!/bin/sh
# reindex.sh runs inside a plain debian:trixie-slim container, as root
# (see build.yml's docker run --user root -- needed to apt-get install
# this script's own build dependencies below). It needs no OpenWrt SDK
# tool: every dependency below comes from apt, and apk-tools is built
# from source (see the next comment block).
#
# Why this exists: .github/workflows/build.yml's "build" job now has
# "package" as its own matrix dimension, so each job builds exactly one
# package and passes index: '0' to .github/actions/build (skipping
# "make package/index" there). "make package/index" only ever indexes
# whatever got compiled in that same invocation, so a per-package build
# would only ever produce a single-package index; copying several of those
# into one feed directory would just clobber each other. This script is
# what rebuilds one real, shared, signed index -- once every package's
# .apk for a release has been collected -- covering every package in it.
#
# apk (apk-tools v3) is a host tool: it runs on the CI runner's own
# x86_64 Linux, not on the target device's architecture, so this script
# does not need a different container per target arch -- one container
# pull per *release* handles every arch built for that release. The
# caller (build.yml's "feed" job) invokes this once per release, with
# every target arch's merged package directory bind-mounted under /feed.
#
# Inputs, bind-mounted or passed as env by the caller:
#   /feed/<arch>/*.apk  every package's .apk for one release, one directory
#                       per target arch, e.g.
#                       /feed/x86_64/stunmesh-go-1.13.3-r1.apk
#   /private-key.pem    EC private key to sign the rebuilt index with. May
#                       be empty (0 bytes): an intentionally unsigned build
#                       (a fork PR, which gets no APK_PRIVATE_KEY secret).
#   /pubkeys/*.pem      the real, already-published public key(s)
#                       (keys/stunmesh.pem) used to verify what this
#                       script just (re)signed -- so a wrong apk
#                       invocation, or a signature that does not actually
#                       verify, fails this script (and so the whole "feed"
#                       job) instead of quietly publishing a broken or
#                       falsely "signed" feed to GitHub Pages.
#   EXPECTED_PACKAGES  space-separated package names that must all appear
#                       in every rebuilt index, from the matrix action's
#                       "define Package/<name>" discovery.
#
# The apk-tools commands below were confirmed against a real .apk pulled
# from this feed's own GitHub Pages site -- not just inferred from
# openwrt/openwrt's package/Makefile, which turned out to use a "--sign"
# flag name apk-tools does not have (it is "--sign-key"; "apk mkndx
# --help" is the source of truth, not the Makefile):
#   apk mkndx --allow-untrusted [--sign-key KEYFILE] --output packages.adb *.apk
#   apk adbdump --format json packages.adb
#   apk verify --keys-dir DIR packages.adb
#
# Why this script builds its own apk-tools instead of using a released
# one (apk-tools 3.0.5, 3.0.7): run 33145097157 and 33148529465 both
# crashed here --
# "Segmentation fault (core dumped)" from "apk mkndx" on SNAPSHOT's
# aarch64_cortex-a53 packages, reliably (2 of the retries in
# 33148529465, on the actual GitHub Actions runner). The exact same
# three .apk files, the exact same SDK image digest, and a byte-identical
# SDK tarball (sha256sum matched the failed runs' logs) did NOT crash
# when reproduced locally -- ruling out a bug in this script's own
# invocation or in the package files themselves, and pointing at a
# memory-safety bug whose trigger depends on the machine's allocator/heap
# state (classic non-deterministic, machine-dependent segfault fingerprint).
# apk-tools upstream (https://gitlab.alpinelinux.org/alpine/apk-tools)
# confirms exactly this: commit 7593499e ("adb: validate ADB block size
# and memory allocation", 2026-08-14) fixes __adb_m_stream() in src/adb.c
# -- the ADB-block reader mkndx uses to parse each input .apk's own
# embedded metadata -- which previously called malloc(sz) with an
# unvalidated, stream-supplied sz and never checked the result for NULL
# before reading into it. This fix landed after apk-tools-3.0.7
# (2026-07-28) and is not in any tagged release yet. Build master HEAD
# (no pinned commit) until a release contains the fix.

set -eu

echo "::group::apt-get: apk-tools build dependencies"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
	gcc libc6-dev meson ninja-build git ca-certificates pkg-config \
	libssl-dev zlib1g-dev libzstd-dev >/dev/null
echo "::endgroup::"

echo "::group::build apk-tools (master)"
# Cloned from the official GitHub mirror, not gitlab.alpinelinux.org
# directly: that host's own connection kept timing out in CI (run
# 33460943658), breaking the "Publish feed" job.
git clone --quiet --depth 1 https://github.com/alpinelinux/apk-tools.git /tmp/apk-tools
# Disable everything not needed to run mkndx/adbdump/verify: lua (help
# text), python bindings, scdoc (manpages), and tests. None of those are
# installed above, so leaving any of them enabled would fail meson's
# dependency resolution for no benefit here.
meson setup /tmp/apk-tools/build /tmp/apk-tools \
	-Dhelp=disabled -Ddocs=disabled -Dlua=disabled -Dpython=disabled -Dtests=disabled \
	--buildtype=release >/dev/null
ninja -C /tmp/apk-tools/build src/apk >/dev/null
APK=/tmp/apk-tools/build/src/apk
"$APK" --version
echo "::endgroup::"

sign_key=""
if [ -s /private-key.pem ]; then
	sign_key="/private-key.pem"
fi

status=0

for arch_dir in /feed/*/; do
	arch=$(basename "$arch_dir")
	echo "::group::index $arch"

	if ! ls "$arch_dir"*.apk >/dev/null 2>&1; then
		echo "no .apk files under $arch_dir, skipping"
		echo "::endgroup::"
		continue
	fi

	if [ -n "$sign_key" ]; then
		( cd "$arch_dir" && "$APK" mkndx --allow-untrusted --sign-key "$sign_key" --output packages.adb ./*.apk )
	else
		( cd "$arch_dir" && "$APK" mkndx --allow-untrusted --output packages.adb ./*.apk )
	fi

	# Validate: the index just written actually parses, and lists every
	# package this release/arch was supposed to get. A malformed index
	# (wrong flags, an apk-tools behavior change) is caught here, before
	# anything is published.
	ndx_json="$("$APK" adbdump --format json "$arch_dir/packages.adb")"
	echo "packages.adb for $arch:"
	echo "$ndx_json"
	for want in $EXPECTED_PACKAGES; do
		case "$ndx_json" in
			*"\"name\": \"$want\""*) ;;
			*)
				echo "::error::$arch_dir/packages.adb is missing expected package '$want'"
				status=1
				;;
		esac
	done

	# Validate: the signature just written verifies against the real
	# public key this repo publishes and every router trusts. Skipped
	# only when there is no private key to sign with in the first place
	# (an intentionally unsigned fork-PR build).
	if [ -n "$sign_key" ]; then
		if ! "$APK" verify --keys-dir /pubkeys "$arch_dir/packages.adb"; then
			echo "::error::$arch_dir/packages.adb failed signature verification against the published public key"
			status=1
		fi
	fi

	echo "::endgroup::"
done

exit "$status"
