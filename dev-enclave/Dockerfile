# The dev enclave a wallet's e2e boots: enclave-runtime's QEMU dev bundle and the released
# cosigner, in one image. build.sh fetches both as pins.env pins them; compose.yml is how it runs,
# and says why it runs that way.
FROM docker:27.5.1-cli AS docker

# glibc, for the bundle's host binaries (built on 22.04). The rest is what the harness calls.
FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends bash ca-certificates curl iproute2 jq openssl python3 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=docker /usr/local/bin/docker /usr/local/bin/docker
COPY bundle /enclave
COPY cosigner.wasm /cosigner/cosigner.wasm
COPY entrypoint.sh /entrypoint.sh

# Up once the harness has enrolled its first passkey, the last thing it does before it serves. A
# run directory is cleared at every start, so a passkey from an earlier boot cannot answer for this
# one. The start period covers a boot on a slow runner.
HEALTHCHECK --interval=5s --start-period=30m --retries=3 \
    CMD test -s "$ENCLAVE_DIR/bundle/target/qemu-nitro/${ENCLAVE_NAME:-vtxos}/alice.json"
ENTRYPOINT ["/entrypoint.sh"]
