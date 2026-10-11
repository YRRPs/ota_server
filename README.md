# YRRP OTA server

Hardened Nginx base image for latest YRRP release. Repository publishes server base only. Signed release image is built and deployed locally on trusted TrueNAS builder and never pushed to registry.

## Routes

| Route | Purpose |
| --- | --- |
| `/healthz` | Container health |
| `/updates/salami.json` | Vanilla channel: LineageOS 23.2 updater metadata |
| `/updates/salami/<incr>.json` | Vanilla incremental metadata, falls back internally to `salami.json` |
| `/updates/salami/gapps.json` | Gapps channel: updater metadata |
| `/updates/salami/gapps/<incr>.json` | Gapps incremental metadata, falls back internally to `gapps.json` |
| `/install/salami/` | Scoped clean-install file browser (vanilla builds; also lists the `gapps/` directory) |
| `/install/salami/<build-id>/` | One immutable signed vanilla release |
| `/install/salami/gapps/` | Gapps clean-install file browser |
| `/install/salami/gapps/<build-id>/` | One immutable signed gapps release |
| `/updates/xueying/gapps.json` | xueying gapps channel: updater metadata |
| `/updates/xueying/gapps/<incr>.json` | xueying gapps incremental metadata, falls back internally to `xueying/gapps.json` |
| `/install/xueying/gapps/` | xueying gapps clean-install file browser |
| `/install/xueying/gapps/<build-id>/` | One immutable signed xueying gapps release |

Each device and build type pair is a channel (`salami/vanilla`, `salami/gapps`, `xueying/gapps`). Vanilla keeps its original URLs; other types insert the type after the device. `/updates/salami/vanilla.json` does not exist. xueying has no vanilla channel, so `/updates/xueying.json` and `/install/xueying/` return 404. Every channel gets explicit locations; there is no generic device or type route.

Nginx denies every other route and accepts GET/HEAD only. Static serving supports byte ranges required by LineageOS updater.

## Base image

```bash
docker build -t yrrp-ota-base .
```

Published image:

```text
ghcr.io/yrrps/ota-server:main
```

Release image must inherit base by immutable digest and copy this exact tree:

```text
/srv/ota/updates/salami.json
/srv/ota/updates/salami/gapps.json
/srv/ota/install/salami/<build-id>/
/srv/ota/install/salami/gapps/<build-id>/
/srv/ota/updates/xueying/gapps.json
/srv/ota/install/xueying/gapps/<build-id>/
```

Release directory contains signed OTA once, six signed install images, `SHA256SUMS.txt`, and `release.json`. Never include target-files, GApps, signing keys, unsigned builds, or previous releases.

## Runtime

Production container joins existing external `proxy-net`, uses hostname and alias `ota-server`, and listens internally on port 8080. It publishes no host port. User-managed reverse proxy handles HTTPS.

```bash
OTA_RELEASE_IMAGE=yrrp-ota-release:20261005-000000 docker compose up -d
```

Runtime uses non-root Nginx, read-only root filesystem, `/tmp` tmpfs, no Linux capabilities, and no-new-privileges.

## Test

```bash
./tests/test-container.sh
```

Tests build synthetic release only. No real OTA or signing material enters test context.

## Directory browsing

Nginx autoindex defaults off. This image enables it only under `/install/salami/` (including `/install/salami/gapps/`). Root and `/updates/` remain unlisted.

## Scope

Repository does not configure TLS, reverse proxy, DNS, release signing, or TrueNAS deployment. Those live in YRRP `project` and `android_build_server` repositories.
