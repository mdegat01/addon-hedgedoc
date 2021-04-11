# https://github.com/hassio-addons/addon-base/releases
ARG BUILD_FROM=ghcr.io/hassio-addons/base/amd64:9.1.5

# https://quay.io/repository/hedgedoc/hedgedoc
FROM quay.io/hedgedoc/hedgedoc:1.7.2-alpine AS build

# hadolint ignore=DL3006
FROM ${BUILD_FROM}

ENV CMD_SOURCE_URL https://github.com/hedgedoc/hedgedoc/tree/1.7.2

# hadolint ignore=DL3009
RUN set -eux; \
    apk update; \
    apk add --no-cache \
        ca-certificates=20191127-r5 \
        netcat-openbsd=1.130-r2 \
        mariadb-client=10.5.8-r0 \
        nodejs=14.16.1-r0 \
        npm=14.16.1-r0 \
        openssl=1.1.1k-r0 \
        ; \
    node --version; \
    update-ca-certificates; \
    \
    echo "Add user for HedgeDoc"; \
    mkdir -p /data/hedgedoc; \
    addgroup -S abc; \
    adduser -u 12345 -h /data/hedgedoc/ -D -S abc -G abc;

COPY --from=build --chown=abc:abc /hedgedoc /opt/hedgedoc
COPY rootfs /

WORKDIR /data/hedgedoc

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="mdegat01" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="mdegat01's Home Assistant Add-ons" \
    org.opencontainers.image.authors="mdegat01" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://github.com/mdegat01/hassio-addons" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
