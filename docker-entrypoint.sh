#!/usr/bin/env bash

set -e

mkdir -p /config/resources

# /app/mods/deathmatch is a symlink to /config, so everything below lands in the
# config volume. The i386 build additionally keeps its engine libraries and its
# module directory there, which is what the symlink and .so cases cover.
echo "**** checking defaults ****"
for src in /defaults/*; do
    dst="/config/${src#/defaults/}"

    if [[ -L "$src" ]]; then
        if [[ ! -d "$dst" || -L "$dst" ]]; then
            ln -vsfT "$(readlink "$src")" "$dst"
        fi
    elif [[ "$src" == *.so ]]; then
        ln -vsfT "$src" "$dst"
    elif [[ ! -e "$dst" ]]; then
        cp -v "$src" "$dst"
    fi
done

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

# /app is owned by root and never written to by the server, so only the config
# volume needs to follow PUID/PGID.
echo "**** changing permissions ****"
chown -Rc mta:mta /config
echo "done"

exec gosu mta:mta "$@"
