# ============================================
# DOB — Build automation
# ============================================

IMAGE_NAME := dob
IMAGE_TAG  := latest
ISO_DIR    := ./output
ISO_FILE   := $(ISO_DIR)/$(IMAGE_NAME)-$(IMAGE_TAG).iso

# bootc-image-builder must run as a privileged container (it needs loop
# devices + mounts), which rootless podman cannot provide. So `make iso`
# elevates to rootful podman via sudo, and the local image is copied into
# rootful storage first with `podman save | sudo podman load`.

# QEMU display backend. Adjust for your environment:
#   sdl   - SDL window (needs libsdl)
#   gtk   - GTK window (good on most Linux)
#   none  - headless (use -nographic instead)
QEMU_DISPLAY ?= gtk

.PHONY: build iso test clean

## Build the OCI image from the Containerfile
build:
	podman build -t $(IMAGE_NAME):$(IMAGE_TAG) .

## Generate a bootable ISO from the OCI image (requires sudo for privileged bib)
iso:
	@mkdir -p $(ISO_DIR)
	# Copy the rootless image into rootful storage so the privileged
	# bib container can read it with --local.
	podman save localhost/$(IMAGE_NAME):$(IMAGE_TAG) | sudo podman load
	sudo podman run --rm --privileged --network host \
		-v $(abspath $(ISO_DIR)):/output \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--local \
		--rootfs ext4 \
		--type iso \
		localhost/$(IMAGE_NAME):$(IMAGE_TAG)

## Boot the ISO in QEMU for testing
test: iso
	qemu-system-x86_64 \
		-m 4096 \
		-smp 4 \
		-cdrom $(ISO_FILE) \
		-boot d \
		-enable-kvm \
		-display $(QEMU_DISPLAY)

## Remove built artifacts
clean:
	podman rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	rm -rf $(ISO_DIR)

## Show available targets
help:
	@grep -E '^[a-zA-Z_-]+:' Makefile | sed 's/://' | sort
