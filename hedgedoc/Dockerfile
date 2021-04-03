ARG BUILD_FROM=ghcr.io/hassio-addons/base/amd64:9.1.5

FROM quay.io/hedgedoc/hedgedoc:1.7.2-alpine AS build

# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# hadolint ignore=DL3009
RUN set -eux; \
    apk update; \
    apk add --no-cache \
        ca-certificates=20191127-r5 \
        nginx=1.18.0-r13 \
        netcat-openbsd=1.130-r2 \
        mariadb-client=10.5.8-r0 \
        nodejs=14.16.0-r0 \
        npm=14.16.0-r0 \
        ; \
    node --version; \
    nginx -v; \
    \
    echo "Set up NGinx"; \
    update-ca-certificates; \
    rm -f -r /etc/nginx; \
    mkdir -p \
      /var/log/nginx \
      /var/lib/nginx \
      /var/tmp/nginx \
      ; \
    touch /var/log/nginx/error.log; \
    \
    echo "Add Hedgedoc user"; \
    mkdir -p /data/hedgedoc; \
    addgroup -S abc; \
    adduser -u 12345 -h /data/hedgedoc/ -D -S abc -G abc;

COPY --from=build --chown=abc:abc /hedgedoc /opt/hedgedoc
COPY rootfs /

WORKDIR /data/hedgedoc
