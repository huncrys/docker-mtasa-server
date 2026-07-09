#!/usr/bin/env sh
# shellcheck shell=busybox

set -euo pipefail

if [[ "$TARGETARCH" == "amd64" ]]; then
    TARSUFFIX="_x64"
    BINSUFFIX="64"
elif [[ "$TARGETARCH" == "386" ]]; then
    TARSUFFIX=""
    BINSUFFIX=""
elif [[ "$TARGETARCH" == "arm64" ]]; then
    TARSUFFIX="_arm64"
    BINSUFFIX="-arm64"
elif [[ "$TARGETARCH/$TARGETVARIANT" == "arm/v7" ]]; then
    TARSUFFIX="_arm"
    BINSUFFIX="-arm"
else
    echo "Unsupported target: ${TARGETARCH}${TARGETVARIANT:+/$TARGETVARIANT}" >&2
    exit 1
fi

if [[ -n "${IS_LUAJIT:-}" ]]; then
    TARNAME="multitheftauto_linux${TARSUFFIX}-${MTA_VERSION}-luajit-${MTA_REVISION}.tar.xz"
    BASE_URL="https://nightly.mtasa.hu/luajit"
else
    TARNAME="multitheftauto_linux${TARSUFFIX}-${MTA_VERSION}-rc-${MTA_REVISION}.tar.gz"
    BASE_URL="https://nightly.mtasa.hu/official"
fi

wget -nv -P /tmp \
    "${BASE_URL}/${TARNAME}" \
    "https://linux.multitheftauto.com/dl/baseconfig.tar.gz" \
;

mkdir -p \
    /rootfs/config \
    /rootfs/app/mods/deathmatch \
    /rootfs/usr/local/bin \
;

tar -xaf "/tmp/${TARNAME}" -C /rootfs/app --strip-components 1
mv /rootfs/app/mods/deathmatch /rootfs/defaults

tar -xzf /tmp/baseconfig.tar.gz -C /rootfs/defaults --strip-components 1
ln -sfT "/app/mta-server${BINSUFFIX}" /rootfs/usr/local/bin/mta-server

rm -f \
    "/tmp/${TARNAME}" \
    "/tmp/baseconfig.tar.gz" \
;
