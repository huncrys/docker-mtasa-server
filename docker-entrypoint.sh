#!/usr/bin/env bash

set -e

mkdir -p \
    /config/resources \
    /modules

echo "**** linking config ****"
ln -vsfT /config /app/mods/deathmatch

(
    echo "**** checking defaults ****"
    cd /defaults
    
    for file in *; do
        if [ "${file: -3}" == ".so" ]; then
            ln -vsfT "/defaults/$file" "/config/$file"
        elif [ ! -f "/config/$file" ]; then
            cp -v "$file" "/config/$file"
        fi
    done
)

(
    echo "**** detecting module directory ****"
    arch=$(dpkg --print-architecture)
    if [[ "$arch" == "amd64" ]]; then
        SO_DIR="x64"
    elif [[ "$arch" == "i386" ]]; then
        SO_DIR="mods/deathmatch"
    elif [[ "$arch" == "armhf" ]]; then
        SO_DIR="arm"
    elif [[ "$arch" == "arm64" ]]; then
        SO_DIR="arm64"
    else
        echo "unsupported architecture: $arch"
        exit 1
    fi

    MODULE_DIR="/app/$SO_DIR/modules"
    echo "module directory: $MODULE_DIR"
    mkdir -p "$MODULE_DIR"

    echo "**** checking modules ****"
    
    cd /modules
    
    if [[ -n "$(find . -maxdepth 0 -empty)" ]]; then
        echo "no modules found"
        exit 0
    fi

    for module in *.so; do
        [[ -f "$MODULE_DIR/$module" ]] || ln -vsfT "/modules/$module" "${MODULE_DIR}/$module"
    done
)

if [[ -n "$(find /config/resources -maxdepth 0 -empty)" ]]; then
    echo "**** downloading resources ****"
    wget -nv -O /tmp/resources.zip "${MTA_RESOURCES_URL}"
    echo -n "unpacking to /config/resources... "
    unzip -q /tmp/resources.zip -d /config/resources
    echo "done"
fi

echo "**** applying PUID and PGID ****"
echo -n "changing userid of mta to $PUID... "
usermod -u "$PUID" mta | (grep -v "no changes" || true)
echo "done"
echo -n "changing groupid of mta to $PGID... "
groupmod -g "$PGID" mta
echo "done"

echo "**** changing permissions ****"
(
    set -x
    chown -R mta:mta \
        /app \
        /config
)

exec gosu mta:mta "$@"
