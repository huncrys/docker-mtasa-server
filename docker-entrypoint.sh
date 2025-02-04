#!/usr/bin/env bash

set -e

mkdir -p \
    /cache \
    /config \
    /modules \
    /resources

(
    echo "**** checking configs ****"
    cd /defaults/config
    
    for file in *; do
        [[ -f "/config/$file" ]] || cp -v "$file" "/config/$file"
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

if [[ -n "$(find /resources -maxdepth 0 -empty)" ]]; then
    echo "**** downloading resources ****"
    wget -nv -O /tmp/resources.zip "${MTA_RESOURCES_URL}"
    echo -n "unpacking to /resources... "
    unzip -q /tmp/resources.zip -d /resources
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
        /cache \
        /config \
        /modules \
        /resources
)

echo "**** linking files ****"
printf "'/config/' -> '/app/mods/deathmatch/*'\n"
find /config -mindepth 1 -maxdepth 1 ! -name "*.sample" -print0 | xargs -0 -L 1 basename | xargs -I{} ln -sfT "/config/{}" "/app/mods/deathmatch/{}"
ln -vsfT /cache /app/mods/deathmatch/resource-cache
ln -vsfT /resources /app/mods/deathmatch/resources

exec gosu mta:mta "$@"
