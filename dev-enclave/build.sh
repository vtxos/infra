#!/usr/bin/env bash
# Build the dev enclave image from what pins.env pins: enclave-runtime's dev bundle and the released
# cosigner, each refused unless its sha256 matches.
#
#   dev-enclave/build.sh [tag]      default dev-enclave:local
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ../pins.env
tag="${1:-dev-enclave:local}"

# url sha256 file: kept when it already matches, fetched and checked when it does not.
fetch() {
    if [[ -f "$3" ]] && echo "$2  $3" | sha256sum -c --status -; then return; fi
    curl -fL --retry 3 --retry-all-errors -o "$3.part" "$1"
    echo "$2  $3.part" | sha256sum -c -
    mv "$3.part" "$3"
}
fetch "https://github.com/vtxos/enclave-runtime/releases/download/$DEV_ENCLAVE_RELEASE/$DEV_ENCLAVE_RELEASE.tar.gz" \
    "$DEV_ENCLAVE_SHA256" bundle.tar.gz
fetch "https://github.com/vtxos/cosigner/releases/download/$COSIGNER_RELEASE/cosigner.wasm" \
    "$COSIGNER_SHA256" cosigner.wasm

rm -rf bundle && mkdir bundle && tar xzf bundle.tar.gz -C bundle --strip-components=1
runtime="$(. bundle/image.env; echo "$ENCLAVE_RUNTIME_REV")"

docker build -t "$tag" \
    --label "org.vtxos.runtime=$runtime" --label "org.vtxos.cosigner=$COSIGNER_RELEASE" .
echo "$tag: enclave-runtime $runtime, cosigner $COSIGNER_RELEASE"
