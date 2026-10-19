FROM nginx:1.31-alpine@sha256:892bb2152464f0c5d8972593a5f5afaf8054552580b699d95f8ff4af08c2d33d

LABEL org.opencontainers.image.source="https://github.com/YRRPs/ota_server" \
      org.opencontainers.image.description="YRRP static OTA server base" \
      org.opencontainers.image.licenses="Apache-2.0"

USER root
RUN rm -f /etc/nginx/conf.d/default.conf \
    && install -d -o nginx -g nginx /srv/ota/updates /srv/ota/install/salami \
        /srv/ota/updates/salami/gapps /srv/ota/install/salami/gapps \
        /srv/ota/updates/xueying/gapps /srv/ota/install/xueying/gapps

COPY nginx/nginx.conf /etc/nginx/nginx.conf

USER 101:101
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=5s \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
