#!/usr/bin/env bash
# ============================================
# DOB — ISO generation helper
# ============================================
# Generates a bootable ISO from the DOB OCI
# image using bootc-image-builder (bib).
#
# Usage:
#   ./scripts/build-iso.sh [image:tag]
#
# Defaults to dob:latest.
# Requires podman and network access.

set -euo pipefail

IMAGE="${1:-dob:latest}"
# Normalize so the local image is referenced as localhost/<name>:<tag>
IMAGE_NAME="${IMAGE#*/}"
IMAGE_NAME="${IMAGE_NAME%%:*}"
IMAGE_TAG="${IMAGE##*:}"
LOCAL_REF="localhost/${IMAGE_NAME}:${IMAGE_TAG}"

ISO_DIR="$(cd "$(dirname "$0")/.." && pwd)/output"

BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"

echo "==> DOB ISO builder"
echo "    Image:  ${LOCAL_REF}"
echo "    Output: ${ISO_DIR}/"
echo "    (runs bootc-image-builder as a privileged rootful container via sudo)"

if ! podman image exists "${LOCAL_REF}"; then
    echo "ERROR: image '${LOCAL_REF}' not found." >&2
    echo "Build it first: podman build -t ${IMAGE} ." >&2
    exit 1
fi

mkdir -p "${ISO_DIR}"

# bib needs loop devices + mounts, so it must run as a privileged container.
# Copy the rootless image into rootful storage first so bib can read it.
echo "==> Copying image into rootful storage..."
podman save "${LOCAL_REF}" | sudo podman load

echo "==> Running bootc-image-builder..."
sudo podman run --rm --privileged --network host \
    -v "${ISO_DIR}":/output \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    "${BIB_IMAGE}" \
    --local \
    --rootfs ext4 \
    --type iso \
    "${LOCAL_REF}"

echo "==> Done."
ISO_FILE="$(ls ${ISO_DIR} | grep -i '\.iso$' | head -n1)"
echo "    ISO written to: ${ISO_DIR}/${ISO_FILE}"
