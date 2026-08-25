ARG MTA_VERSION=1.6.0
ARG MTA_REVISION=24138

FROM --platform=$BUILDPLATFORM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS fetcher

RUN --mount=type=cache,target=/var/cache/apk \
    apk add -uU \
        gzip \
        tar \
        unzip \
        wget \
        xz \
    ;

FROM fetcher AS fetch-luajit

ARG MTA_VERSION
ARG MTA_REVISION
ARG TARGETARCH
ARG TARGETVARIANT
ENV MTA_VARIANT=luajit

RUN --mount=type=bind,source=fetch.sh,target=/usr/local/bin/fetch.sh fetch.sh

FROM fetcher AS fetch-official

ARG MTA_VERSION
ARG MTA_REVISION
ARG TARGETARCH
ARG TARGETVARIANT
ENV MTA_VARIANT=official

RUN --mount=type=bind,source=fetch.sh,target=/usr/local/bin/fetch.sh fetch.sh

FROM debian:trixie-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132 AS runtime

ENV \
    DEBIAN_FRONTEND="noninteractive" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    PGID=1000 \
    PUID=1000 \
    TERM="xterm" \
    TZ=Europe/Budapest \
    MTA_RESOURCES_URL="https://mirror.multitheftauto.com/mtasa/resources/mtasa-resources-latest.zip"

ARG TARGETPLATFORM
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-cache-$TARGETPLATFORM \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=apt-lib-$TARGETPLATFORM \
<<'EOF'
    apt-get update
    apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        gosu \
        libncursesw6 \
        libssl3t64 \
        locales \
        tzdata \
        unzip \
        wget \
    ;

    locale-gen en_US.UTF-8

    groupadd -g "$PGID" mta
    useradd -l -u "$PUID" -g "$PGID" -d /app -s /bin/false mta
    usermod -G users mta
EOF

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint

VOLUME /config \
       /modules

WORKDIR /app

ENTRYPOINT [ "docker-entrypoint" ]
CMD ["mta-server", "-x", "-n", "-u"]

EXPOSE  22003/udp \
        22005/tcp \
        22126/udp

FROM runtime AS luajit

COPY --from=fetch-luajit --chown=root:root /rootfs/ /

# The official packages statically link libmysqlclient into dbconmy.so, which pulls in OpenSSL 1.1
# dynamically. Trixie only ships OpenSSL 3, so without libssl1.1 from bullseye the MySQL driver
# fails to load. The pin keeps every other package off the bullseye repository.
# Note: bullseye LTS ends 2026-08-31, after which it stops receiving security updates.
FROM runtime AS official

COPY <<'EOF' /etc/apt/sources.list.d/bullseye-security.sources
Types: deb
URIs: http://security.debian.org/debian-security
Suites: bullseye-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-bullseye-security-automatic.gpg
EOF

COPY <<'EOF' /etc/apt/preferences.d/bullseye-security
Package: *
Pin: release n=bullseye-security
Pin-Priority: -1

Package: libssl1.1
Pin: release n=bullseye-security
Pin-Priority: 500
EOF

ARG TARGETPLATFORM
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-cache-$TARGETPLATFORM \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=apt-lib-$TARGETPLATFORM \
<<'EOF'
    apt-get update
    apt-get install -y --no-install-recommends libssl1.1
EOF

COPY --from=fetch-official --chown=root:root /rootfs/ /
