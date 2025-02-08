ARG MTA_VERSION=1.6.0-rc-22946

FROM alpine:3.21 AS builder

ARG MTA_VERSION
ARG TARGETARCH
ARG TARGETVARIANT

RUN apk add --no-cache --update \
        tar \
        gzip \
        unzip \
        wget \
    && if [[ "$TARGETARCH" == "amd64" ]]; then \
        TARSUFFIX="_x64"; \
        BINSUFFIX="64"; \
    elif [[ "$TARGETARCH" == "386" ]]; then \
        TARSUFFIX=""; \
        BINSUFFIX=""; \
    elif [[ "$TARGETARCH" == "arm64" ]]; then \
        TARSUFFIX="_arm64"; \
        BINSUFFIX="-arm64"; \
    elif [[ "$TARGETARCH/$TARGETVARIANT" == "arm/v7" ]]; then \
        TARSUFFIX="_arm"; \
        BINSUFFIX="-arm"; \
    else \
        echo "Unsupported target: ${TARGETARCH}${TARGETVARIANT:+/$TARGETVARIANT}" ; \
        exit 1; \
    fi \
    && wget -P /tmp \
        "https://nightly.multitheftauto.com/multitheftauto_linux${TARSUFFIX}-${MTA_VERSION}.tar.gz" \
        "https://linux.multitheftauto.com/dl/baseconfig.tar.gz" \
    && mkdir -p /rootfs/app/mods/deathmatch \
                /rootfs/defaults/config \
                /rootfs/usr/local/bin \
    && find /rootfs/app/mods/deathmatch -type f -exec mv "{}" "{}.sample" \; \
    && tar -xzf "/tmp/multitheftauto_linux${TARSUFFIX}-${MTA_VERSION}.tar.gz" -C /rootfs/app --strip-components 1 \
    && tar -xzf /tmp/baseconfig.tar.gz -C /rootfs/defaults/config --strip-components 1 \
    && ln -sfT "/app/mta-server${BINSUFFIX}" /rootfs/usr/local/bin/mta-server \
    && rm -rf /tmp/* \
    ;

FROM debian:bookworm-slim

ENV \
    DEBIAN_FRONTEND="noninteractive" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    PGID=1000 \
    PUID=1000 \
    TERM="xterm" \
    MTA_RESOURCES_URL="https://mirror.multitheftauto.com/mtasa/resources/mtasa-resources-latest.zip"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        bash \
        gosu \
        libncursesw6 \
        locales \
        unzip \
        wget \
    && locale-gen en_US.UTF-8 \
    && groupadd -g "$PGID" mta \
    && useradd -u "$PUID" -g "$PGID" -d /app -s /bin/false mta \
    && usermod -G users mta \
    && mkdir -p \
        /app \
    && apt-get clean \
    && rm -rf \
        /tmp/* \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /var/log/* \
        /usr/share/man \
    ;

COPY --from=builder --chown=mta:mta /rootfs/ /
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint

WORKDIR /app

ENTRYPOINT [ "docker-entrypoint" ]
CMD ["mta-server", "-x", "-n", "-u"]

EXPOSE  22003/udp \
        22005/tcp \
        22126/udp
