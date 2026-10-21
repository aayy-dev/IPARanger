#!/bin/sh
# Build IPARanger, bundling the patched ipatool + appinst from the sibling
# forks, then package it.
#
# The two CLIs live in their own repos (the source of truth); this rebuilds
# them every time so IPARanger always ships the current versions. They are
# gitignored under Resources/ipatool/ — a plain `make package` without this
# script would ship an app with no CLIs. (Mirrors ipadecrypt's app/build.sh.)
#
# Override locations with env vars:
#   IPATOOL_SRC   ipatool fork checkout      (default ~/Git/ipatool-fork)
#   APPINST_SRC   AppSync appinst dir        (default ~/Git/AppSync/appinst)
#   IPATOOL_VERSION  version baked into ipatool --version (default 2.7.1)
#   THEOS         Theos install              (default ~/theos)
#   INSTALL=1     also install over ssh to $IPARANGER_DEVICE (default iphone)
set -eu
cd "$(dirname "$0")"

IPATOOL_SRC="${IPATOOL_SRC:-$HOME/Git/ipatool-fork}"
APPINST_SRC="${APPINST_SRC:-$HOME/Git/AppSync/appinst}"
IPATOOL_VERSION="${IPATOOL_VERSION:-2.7.1}"
THEOS="${THEOS:-$HOME/theos}"
MAKE="${MAKE:-make}"
export THEOS
dest="$PWD/Resources/ipatool"
mkdir -p "$dest"

echo "==> ipatool (arm64) from $IPATOOL_SRC"
[ -x "$IPATOOL_SRC/tools/build-ios.sh" ] || { echo "ipatool fork not found at $IPATOOL_SRC (set IPATOOL_SRC)" >&2; exit 1; }
VERSION="$IPATOOL_VERSION" GOTOOLCHAIN="${GOTOOLCHAIN:-go1.26.5}" "$IPATOOL_SRC/tools/build-ios.sh" "$dest/ipatool"

echo "==> appinst (arm64+arm64e) from $APPINST_SRC"
[ -f "$APPINST_SRC/Makefile" ] || { echo "appinst source not found at $APPINST_SRC (set APPINST_SRC)" >&2; exit 1; }
( cd "$APPINST_SRC" && THEOS_PACKAGE_SCHEME=rootless "$MAKE" >/dev/null )
cp "$APPINST_SRC/.theos/obj/appinst" "$dest/appinst"
chmod +x "$dest/ipatool" "$dest/appinst"
echo "    ipatool:  $(file -b "$dest/ipatool" | cut -c1-40)"
echo "    appinst:  $(file -b "$dest/appinst" | cut -c1-40)"

echo "==> package IPARanger"
THEOS_PACKAGE_SCHEME=rootless "$MAKE" package FINALPACKAGE=1

DEB=$(ls -t packages/dev.aayy.iparanger_*.deb | head -1)
[ -n "$DEB" ] || { echo "no .deb produced" >&2; exit 1; }
echo "built $DEB"
[ "${INSTALL:-0}" = 0 ] && exit 0

DEVICE="${IPARANGER_DEVICE:-iphone}"
REMOTE="/var/mobile/Documents/$(basename "$DEB")"
scp "$DEB" "$DEVICE:$REMOTE"
ssh "$DEVICE" "sudo dpkg -i '$REMOTE' && uicache -p /var/jb/Applications/IPARanger.app"
echo "installed on $DEVICE"
