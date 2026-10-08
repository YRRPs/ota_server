#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
network=yrrp-ota-test-$$
container=yrrp-ota-test-$$

cleanup() {
    docker rm -f "${container}" >/dev/null 2>&1 || true
    docker network rm "${network}" >/dev/null 2>&1 || true
    docker image rm -f yrrp-ota-release-test yrrp-ota-base-test >/dev/null 2>&1 || true
    rm -rf "${scratch}"
}
trap cleanup EXIT

require_file() {
    test -s "$1" || {
        echo "required implementation file missing: $1" >&2
        exit 1
    }
}

require_file "${repo}/Dockerfile"
require_file "${repo}/nginx/nginx.conf"

"${repo}/tests/make-fixture.sh" "${scratch}/fixture"
docker build -t yrrp-ota-base-test "${repo}"
docker build -t yrrp-ota-release-test "${scratch}/fixture"
docker network create "${network}" >/dev/null

docker run -d \
    --name "${container}" \
    --network "${network}" \
    --read-only \
    --tmpfs /tmp:rw,noexec,nosuid,nodev,mode=1777 \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    yrrp-ota-release-test >/dev/null

for _ in $(seq 1 30); do
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "${container}")
    [ "${health}" = healthy ] && break
    [ "${health}" = unhealthy ] && {
        docker logs "${container}" >&2
        exit 1
    }
    sleep 1
done
test "${health}" = healthy

test "$(docker exec "${container}" id -u)" != 0
if docker exec "${container}" touch /rootfs-write-test 2>/dev/null; then
    echo 'container root filesystem is writable' >&2
    exit 1
fi
test -z "$(docker port "${container}")"

container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${container}")
base_url=http://${container_ip}:8080

request() {
    curl --silent --show-error --include "$@"
}

health_response=$(request "${base_url}/healthz")
grep -q 'HTTP/1.1 200 OK' <<<"${health_response}"

metadata_response=$(request "${base_url}/updates/salami.json")
grep -qi 'Content-Type: application/json' <<<"${metadata_response}"
grep -qi 'Cache-Control: no-cache' <<<"${metadata_response}"
grep -q 'synthetic-ota.zip' <<<"${metadata_response}"

listing_response=$(request "${base_url}/install/salami/")
grep -q '20990101-000000/' <<<"${listing_response}"
build_listing=$(request "${base_url}/install/salami/20990101-000000/")
grep -q 'synthetic-ota.zip' <<<"${build_listing}"
grep -q 'boot.img' <<<"${build_listing}"

test "$(curl --silent --output /dev/null --write-out '%{http_code}' "${base_url}/")" = 404
test "$(curl --silent --output /dev/null --write-out '%{http_code}' "${base_url}/updates/")" = 404

head_response=$(curl --silent --show-error --head "${base_url}/install/salami/20990101-000000/synthetic-ota.zip")
grep -q 'HTTP/1.1 200 OK' <<<"${head_response}"

range_headers=$(curl --silent --show-error --dump-header - --output /dev/null --range 0-8 "${base_url}/install/salami/20990101-000000/synthetic-ota.zip")
grep -q 'HTTP/1.1 206 Partial Content' <<<"${range_headers}"
grep -qi 'Content-Range: bytes 0-8/24' <<<"${range_headers}"
test "$(curl --silent --show-error --range 0-8 "${base_url}/install/salami/20990101-000000/synthetic-ota.zip")" = synthetic

incremental_response=$(request "${base_url}/updates/salami/4070822400.json")
grep -q 'HTTP/1.1 200 OK' <<<"${incremental_response}"
grep -qi 'Content-Type: application/json' <<<"${incremental_response}"
grep -qi 'Cache-Control: no-cache' <<<"${incremental_response}"
grep -q 'synthetic-incremental.zip' <<<"${incremental_response}"

fallback_response=$(request "${base_url}/updates/salami/1.json")
grep -q 'HTTP/1.1 200 OK' <<<"${fallback_response}"
grep -qi 'Cache-Control: no-cache' <<<"${fallback_response}"
grep -q 'synthetic-ota.zip' <<<"${fallback_response}"
if grep -qi '^Location:' <<<"${fallback_response}"; then
    echo 'incremental fallback must not redirect' >&2
    exit 1
fi

for path in /updates/salami/abc.json /updates/salami/1/2.json /updates/salami/1.json.bak /updates/salami/; do
    test "$(curl --silent --output /dev/null --write-out '%{http_code}' "${base_url}${path}")" = 404
done
test "$(curl --silent --output /dev/null --write-out '%{http_code}' --request POST --data x "${base_url}/updates/salami/1.json")" = 403
test "$(curl --silent --output /dev/null --write-out '%{http_code}' --request POST --data x "${base_url}/healthz")" = 403

printf 'OTA container contract passed\n'
