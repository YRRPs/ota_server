#!/bin/sh
set -eu

output=${1:?usage: make-fixture.sh OUTPUT_DIR}
build_id=20990101-000000
release_dir=${output}/rootfs/install/salami/${build_id}

if [ -e "${output}" ]; then
    echo "fixture output already exists: ${output}" >&2
    exit 1
fi

mkdir -p "${output}/rootfs/updates/salami" "${release_dir}"
printf 'synthetic-incremental\n' > "${release_dir}/synthetic-incremental.zip"
printf '%s\n' '[{"datetime":4070908800,"files":[{"filename":"synthetic-incremental.zip","sha256":"synthetic","size":22,"url":"https://ota.example.invalid/install/salami/20990101-000000/synthetic-incremental.zip"}],"type":"UNOFFICIAL","version":"23.2"}]' > "${output}/rootfs/updates/salami/4070822400.json"
printf 'synthetic-range-payload\n' > "${release_dir}/synthetic-ota.zip"
printf 'synthetic-boot\n' > "${release_dir}/boot.img"
printf '%s\n' '[{"datetime":4070908800,"files":[{"filename":"synthetic-ota.zip","sha256":"synthetic","size":24,"url":"https://ota.example.invalid/install/salami/20990101-000000/synthetic-ota.zip"}],"type":"UNOFFICIAL","version":"23.2"}]' > "${output}/rootfs/updates/salami.json"
printf '%s\n' '{"schema":1,"synthetic":true}' > "${release_dir}/release.json"

gapps_dir=${output}/rootfs/install/salami/gapps/${build_id}
mkdir -p "${output}/rootfs/updates/salami/gapps" "${gapps_dir}"
printf 'gapps-incremental\n' > "${gapps_dir}/gapps-incremental.zip"
printf '%s\n' '[{"datetime":4070908800,"files":[{"filename":"gapps-incremental.zip","sha256":"synthetic","size":18,"url":"https://ota.example.invalid/install/salami/gapps/20990101-000000/gapps-incremental.zip"}],"type":"UNOFFICIAL","version":"23.2"}]' > "${output}/rootfs/updates/salami/gapps/4070822400.json"
printf 'gapps-ota-payload\n' > "${gapps_dir}/gapps-ota.zip"
printf '%s\n' '[{"datetime":4070908800,"files":[{"filename":"gapps-ota.zip","sha256":"synthetic","size":18,"url":"https://ota.example.invalid/install/salami/gapps/20990101-000000/gapps-ota.zip"}],"type":"UNOFFICIAL","version":"23.2"}]' > "${output}/rootfs/updates/salami/gapps.json"
printf '%s\n' '{"schema":3,"synthetic":true}' > "${gapps_dir}/release.json"
cat > "${output}/Dockerfile" <<'EOF'
FROM yrrp-ota-base-test
COPY --chown=101:101 rootfs/ /srv/ota/
EOF
