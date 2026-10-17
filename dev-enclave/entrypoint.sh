#!/usr/bin/env bash
# The dev enclave, serving the cosigner this image was built with (or GUEST, a component mounted
# in), configured with GUEST_ENV: `NAME=VALUE` pairs separated by commas, which go into the
# component as it is uploaded and so into PCR16.
#
# The harness is enclave-runtime's dev-enclave.sh, run unmodified. It starts QEMU, MinIO and Pebble
# as containers of the host's Docker, which bind-mount the image, the run directory and Pebble's
# files by path, and the host's Docker resolves those paths on the host. So the bundle runs from
# ENCLAVE_DIR, a host directory mounted at the same path in here, copied there once per bundle.
set -euo pipefail

dir="${ENCLAVE_DIR:?mount a host directory at the same path inside, and name it in ENCLAVE_DIR}"
# ENCLAVE_BUNDLE=app: the image built for the wallet's app, whose relying party is vtxos.com.
case "${ENCLAVE_BUNDLE:-}" in
    "") image=/enclave ;;
    app) image=/enclave-app ;;
    *) echo "ENCLAVE_BUNDLE is app or unset, not $ENCLAVE_BUNDLE" >&2; exit 1 ;;
esac
bundle="$dir/bundle"
if ! cmp -s "$image/image.env" "$bundle/image.env" 2>/dev/null; then
    echo "copying the bundle into $bundle"
    rm -rf "$bundle"
    cp -a "$image" "$bundle"
    # Ours is root; the directory is the host user's, who must be able to clear it.
    chmod -R a+rwX "$bundle"
fi

# The run directory is the e2e's too: it enrols its passkeys there, as whoever runs it on the host.
umask 000

settings=()
IFS=, read -ra pairs <<<"${GUEST_ENV:-}"
for pair in "${pairs[@]}"; do settings+=(--guest-env "$pair"); done

exec "$bundle/deploy/qemu-nitro/dev-enclave.sh" --prebuilt "$bundle" \
    --guest "${GUEST:-/cosigner/cosigner.wasm}" \
    --name "${ENCLAVE_NAME:-vtxos}" --port "${ENCLAVE_PORT:-8443}" \
    "${settings[@]}"
