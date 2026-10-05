FROM nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de

LABEL org.opencontainers.image.source="https://github.com/Yim-s-Riced-ROM-Project/ota_server" \
      org.opencontainers.image.description="YRRP static OTA server base" \
      org.opencontainers.image.licenses="Apache-2.0"

USER root
RUN rm -f /etc/nginx/conf.d/default.conf \
    && install -d -o nginx -g nginx /srv/ota/updates /srv/ota/install/salami

COPY nginx/nginx.conf /etc/nginx/nginx.conf

USER 101:101
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=5s \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
