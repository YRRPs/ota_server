FROM nginx:1.31-alpine@sha256:df221db836e1754089190208cee7eeda94f233197056426eda74a43ab1abeac2

LABEL org.opencontainers.image.source="https://github.com/YRRPs/ota_server" \
      org.opencontainers.image.description="YRRP static OTA server base" \
      org.opencontainers.image.licenses="Apache-2.0"

USER root
RUN rm -f /etc/nginx/conf.d/default.conf \
    && install -d -o nginx -g nginx /srv/ota/updates /srv/ota/install/salami \
        /srv/ota/updates/salami/gapps /srv/ota/install/salami/gapps

COPY nginx/nginx.conf /etc/nginx/nginx.conf

USER 101:101
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=5s \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
