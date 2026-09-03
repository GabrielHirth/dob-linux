#!/usr/bin/env bash
# ============================================
# DOB — ISO generation helper
# ============================================
# Generates a bootable ISO from the DOB OCI
# image using bootc-image-builder (bib).
#
# Usage:
#   ./scripts/build-iso.sh [image:tag] [--arch aarch64|x86_64]
#
# Defaults to dob:latest and host architecture.
# Requires podman and network access.

set -euo pipefail

IMAGE="${1:-dob:latest}"
# Normalize so the local image is referenced as localhost/<name>:<tag>
IMAGE_NAME="${IMAGE#*/}"
IMAGE_NAME="${IMAGE_NAME%%:*}"
IMAGE_TAG="${IMAGE##*:}"
LOCAL_REF="localhost/${IMAGE_NAME}:${IMAGE_TAG}"

# Parse optional --arch flag
ARCH="${2:-}"
if [ -z "$ARCH" ]; then
    UNAME_M="$(uname -m)"
    case "$UNAME_M" in
        aarch64|arm64) ARCH="aarch64" ;;
        *)             ARCH="x86_64"  ;;
    esac
fi

ISO_DIR="$(cd "$(dirname "$0")/.." && pwd)/output"

BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"

echo "==> DOB ISO builder"
echo "    Image:       ${LOCAL_REF}"
echo "    Architecture: ${ARCH}"
echo "    Output:      ${ISO_DIR}/"
echo "    (runs bootc-image-builder as a privileged rootful container via sudo)"

if ! podman image exists "${LOCAL_REF}"; then
    echo "ERROR: image '${LOCAL_REF}' not found." >&2
    echo "Build it first: podman build -t ${IMAGE} ." >&2
    exit 1
fi

mkdir -p "${ISO_DIR}"

# bib needs loop devices + mounts, so it must run as a privileged container.
#
# macOS (Podman Machine): the VM is rootful by default — use podman directly.
# Linux rootful: use sudo to access rootful storage.
if command -v podman machine &>/dev/null 2>&1; then
    # macOS — Podman Machine handles rootful storage internally
    echo "==> Detected macOS/Podman Machine — running without sudo..."
    SUDO=""
else
    # Linux — need sudo for rootful podman storage
    echo "==> Detected Linux — copying image into rootful storage..."
    podman save "${LOCAL_REF}" | sudo podman load
    SUDO="sudo"
fi

echo "==> Running bootc-image-builder (${ARCH})..."
${SUDO} podman run --rm --privileged --network host \
    -v "${ISO_DIR}":/output \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    "${BIB_IMAGE}" \
    --local \
    --rootfs ext4 \
    --type iso \
    "${LOCAL_REF}"

echo "==> Done."
echo "    ISO written to: ${ISO_DIR}/bootiso/install.iso"
