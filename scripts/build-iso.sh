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
IMAGE_NAME="${IMAGE%%:*}"
IMAGE_TAG="${IMAGE##*:}"

ISO_DIR="$(cd "$(dirname "$0")/.." && pwd)/output"

BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"

echo "==> DOB ISO builder"
echo "    Image:  ${IMAGE}"
echo "    Output: ${ISO_DIR}/"

# The ISO builder needs rootless podman to resolve the local image.
# It reads the image from the container storage volume we mount in.
if ! podman image exists "${IMAGE}"; then
    echo "ERROR: image '${IMAGE}' not found." >&2
    echo "Build it first: podman build -t ${IMAGE} ." >&2
    exit 1
fi

mkdir -p "${ISO_DIR}"

echo "==> Running bootc-image-builder..."
podman run --rm \
    -v "${ISO_DIR}":/output \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    "${BIB_IMAGE}" \
    --type iso \
    "${IMAGE}"

echo "==> Done."
echo "    ISO written to: ${ISO_DIR}/$(ls ${ISO_DIR} | grep -i '\.iso$' | head -n1)"
