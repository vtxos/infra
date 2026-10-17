#!/usr/bin/env bash
# Build the dev enclave image from what pins.env pins: vtxos/runtime at a commit, packed here into
# its QEMU dev bundle, and the released cosigner, refused unless its sha256 matches.
#
#   dev-enclave/build.sh [tag]      default dev-enclave:local
#
# Packing builds the enclave image, so this needs what that needs: Nix, cargo and Docker, and KVM
# and vsock for what prepare_enclave_host sets up.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ../pins.env
tag="${1:-dev-enclave:local}"

# The runtime at the pinned commit, packed with no image options: the bundle carries nothing of
# any guest's, which is given its settings when it boots.
[[ -d runtime/.git ]] || git clone -q https://github.com/vtxos/runtime runtime
git -C runtime fetch -q origin "$DEV_RUNTIME_REV"
git -C runtime checkout -q --detach "$DEV_RUNTIME_REV"
(cd runtime && rustup show >/dev/null)   # its rust-toolchain.toml, installed
bash -c '. runtime/scripts/lib.sh && prepare_enclave_host'
runtime/deploy/qemu-nitro/dev-enclave.sh --name pack --pack "$PWD/bundle"
# And again for the wallet's app, which a passkey is created for on an Android emulator: Android's
# relying party is vtxos.com, and the app claims the origin of the key its APK is signed with — the
# wallet's checked-in debug keystore, and its release key. The image fixes both, so they are a
# second bundle, which ENCLAVE_BUNDLE=app boots. The same as the wallet's `make up` builds.
runtime/deploy/qemu-nitro/dev-enclave.sh --name pack-app --pack "$PWD/bundle-app" --rp-id vtxos.com \
    --allowed-origin android:apk-key-hash:Lf1QIwQnlPBYPwDFhloUkYC-0tYAKSpKCQbEiyz118s \
    --allowed-origin android:apk-key-hash:u1pNepeObJUpSkSqH964HvFRqbhC_ejQP3GHA3-lreI

if ! { [[ -f cosigner.wasm ]] && echo "$COSIGNER_SHA256  cosigner.wasm" | sha256sum -c --status -; }; then
    curl -fL --retry 3 --retry-all-errors -o cosigner.wasm.part \
        "https://github.com/vtxos/cosigner/releases/download/$COSIGNER_RELEASE/cosigner.wasm"
    echo "$COSIGNER_SHA256  cosigner.wasm.part" | sha256sum -c -
    mv cosigner.wasm.part cosigner.wasm
fi

runtime="$(. bundle/image.env; echo "$ENCLAVE_RUNTIME_REV")"
docker build -t "$tag" \
    --label "org.vtxos.runtime=$runtime" --label "org.vtxos.cosigner=$COSIGNER_RELEASE" .
echo "$tag: runtime $runtime, cosigner $COSIGNER_RELEASE"
