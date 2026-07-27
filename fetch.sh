#!/usr/bin/env sh
# shellcheck shell=busybox

set -euo pipefail

if [[ "$TARGETARCH" == "amd64" ]]; then
    TARSUFFIX="_x64"
    BINSUFFIX="64"
    SO_DIR="x64"
elif [[ "$TARGETARCH" == "386" ]]; then
    TARSUFFIX=""
    BINSUFFIX=""
    SO_DIR="mods/deathmatch"
elif [[ "$TARGETARCH" == "arm64" ]]; then
    TARSUFFIX="_arm64"
    BINSUFFIX="-arm64"
    SO_DIR="arm64"
elif [[ "$TARGETARCH/$TARGETVARIANT" == "arm/v7" ]]; then
    TARSUFFIX="_arm"
    BINSUFFIX="-arm"
    SO_DIR="arm"
else
    echo "Unsupported target: ${TARGETARCH}${TARGETVARIANT:+/$TARGETVARIANT}" >&2
    exit 1
fi

if [[ "$MTA_VARIANT" == "luajit" ]]; then
    TARNAME="multitheftauto_linux${TARSUFFIX}-${MTA_VERSION}-luajit-${MTA_REVISION}.tar.xz"
elif [[ "$MTA_VARIANT" == "official" ]]; then
    TARNAME="multitheftauto_linux${TARSUFFIX}-${MTA_VERSION}-rc-${MTA_REVISION}.tar.gz"
else
    echo "Unsupported variant: ${MTA_VARIANT}" >&2
    exit 1
fi

BASE_URL="https://nightly.mtasa.hu/${MTA_VARIANT}"

wget -nv -P /tmp \
    "${BASE_URL}/${TARNAME}" \
    "https://linux.multitheftauto.com/dl/baseconfig.tar.gz" \
;

mkdir -p \
    /rootfs/config \
    /rootfs/modules \
    /rootfs/app/mods/deathmatch \
    /rootfs/usr/local/bin \
;

tar -xaf "/tmp/${TARNAME}" -C /rootfs/app --strip-components 1
mv /rootfs/app/mods/deathmatch /rootfs/defaults

tar -xzf /tmp/baseconfig.tar.gz -C /rootfs/defaults --strip-components 1
ln -sfT "/app/mta-server${BINSUFFIX}" /rootfs/usr/local/bin/mta-server

# The server hardcodes its own layout: everything it writes goes to
# mods/deathmatch, and modules are loaded from ${SO_DIR}/modules. Both are
# pointed at the volumes here, where the target architecture is known, so the
# entrypoint does not have to detect it at runtime.
ln -sfT /config /rootfs/app/mods/deathmatch

if [[ "$SO_DIR" == "mods/deathmatch" ]]; then
    # i386 keeps the engine libraries and the module directory inside
    # mods/deathmatch, which is the config volume - only the entrypoint can
    # link those in, so hand it the module link as a default.
    ln -sfT /modules /rootfs/defaults/modules
else
    ln -sfT /modules "/rootfs/app/${SO_DIR}/modules"
fi

rm -f \
    "/tmp/${TARNAME}" \
    "/tmp/baseconfig.tar.gz" \
;
