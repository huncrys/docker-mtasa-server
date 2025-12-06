#!/usr/bin/env sh
# shellcheck shell=busybox

set -euo pipefail

export GLAB_CHECK_UPDATE=false

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

TARNAME="multitheftauto_linux${TARSUFFIX}-${MTA_VERSION}-rc-${MTA_REVISION}.tar.gz"
if [[ -n "$IS_LUAJIT" ]]; then
    package_version=$(glab api --hostname oaklab.hu 'projects/crys%2Fmtasa-blue/packages' --paginate | jq -r '[. |= sort_by(.version) | reverse | .[] | select(.version | contains(env.MTA_VERSION + "-r" + env.MTA_REVISION))][0].version')
    BASE_URL="https://oaklab.hu/api/v4/projects/crys%2Fmtasa-blue/packages/generic/mtasa-blue/${package_version}"
else
    BASE_URL="https://nightly.multitheftauto.com"
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

tar -xzf "/tmp/${TARNAME}" -C /rootfs/app --strip-components 1
mv /rootfs/app/mods/deathmatch /rootfs/defaults

tar -xzf /tmp/baseconfig.tar.gz -C /rootfs/defaults --strip-components 1
ln -sfT "/app/mta-server${BINSUFFIX}" /rootfs/usr/local/bin/mta-server

rm -f \
    "/tmp/${TARNAME}" \
    "/tmp/baseconfig.tar.gz" \
;
