ARG MTA_VERSION=1.6.0
ARG MTA_REVISION=23757

FROM --platform=$BUILDPLATFORM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS builder

RUN --mount=type=cache,target=/var/cache/apk \
    apk add -uU \
        glab \
        gzip \
        jq \
        tar \
        unzip \
        wget \
    ;

ARG MTA_VERSION
ARG MTA_REVISION
ARG IS_LUAJIT
ARG TARGETARCH
ARG TARGETVARIANT

RUN --mount=type=bind,source=fetch.sh,target=/usr/local/bin/fetch.sh fetch.sh

FROM debian:trixie-slim@sha256:28de0877c2189802884ccd20f15ee41c203573bd87bb6b883f5f46362d24c5c2

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

COPY --from=builder --chown=mta:mta /rootfs/ /
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint

VOLUME /config \
       /modules

WORKDIR /app

ENTRYPOINT [ "docker-entrypoint" ]
CMD ["mta-server", "-x", "-n", "-u"]

EXPOSE  22003/udp \
        22005/tcp \
        22126/udp
