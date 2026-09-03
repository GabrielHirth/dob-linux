#!/usr/bin/env bash
# ============================================
# DOB — build the live ISO inside the podman machine
# ============================================
# Runs scripts/_lmc-build.sh inside a Fedora 44 container on the podman
# machine. Builds the machine's NATIVE arch (aarch64 on Apple Silicon,
# x86_64 on WSL2).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

UNAME_M="$(uname -m)"
case "$UNAME_M" in
    aarch64|arm64) ARCH="aarch64" ;;
    *)             ARCH="x86_64"  ;;
esac

echo "==> DOB live ISO builder"
echo "    Architecture: ${ARCH}"

# Fedora container on the podman machine; repo bind-mounted at /work.
# --privileged so anaconda can loop-mount the squashfs during image build.
podman machine ssh -- \
  podman run --rm --privileged \
    -v "${ROOT}":/work:z \
    fedora:44 \
    bash /work/scripts/_lmc-build.sh "${ARCH}"
