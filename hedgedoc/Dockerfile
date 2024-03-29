ARG BUILD_FROM=ghcr.io/hassio-addons/base

# https://github.com/hedgedoc/hedgedoc/releases
# https://quay.io/repository/hedgedoc/hedgedoc
FROM quay.io/hedgedoc/hedgedoc:1.9.4-alpine AS build

# https://github.com/hassio-addons/addon-base/releases
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

RUN set -eux; \
    apk update; \
    apk add --no-cache \
        ca-certificates=20220614-r0 \
        netcat-openbsd=1.130-r3 \
        mariadb-client=10.6.9-r0 \
        nodejs=16.16.0-r0 \
        npm=8.10.0-r0 \
        openssl=1.1.1q-r0 \
        ; \
    node --version; \
    update-ca-certificates; \
    \
    echo "Add user for HedgeDoc"; \
    mkdir -p /data/hedgedoc; \
    addgroup -S abc; \
    adduser -u 12345 -h /data/hedgedoc/ -D -S abc -G abc;

# Set up Hedgedoc 
ENV CMD_SOURCE_URL="https://github.com/hedgedoc/hedgedoc/tree/1.9.3"
COPY --from=build --chown=abc:abc /hedgedoc /opt/hedgedoc

COPY --chown=abc:abc rootfs /

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
