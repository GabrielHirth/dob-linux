# ============================================
# DOB — Build automation
# ============================================
# Supports x86_64 and arm64 (aarch64) architectures.
# On Apple Silicon macOS, podman machine provides the ARM64 build environment.

IMAGE_NAME := dob
IMAGE_TAG  := latest
ISO_DIR    := ./output

# Architecture: auto-detect from host, or override with ARCH=arm64
UNAME_M    := $(shell uname -m)
ifeq ($(UNAME_M),aarch64)
  ARCH     ?= aarch64
else ifeq ($(UNAME_M),arm64)
  ARCH     ?= aarch64
else
  ARCH     ?= x86_64
endif

# QEMU binary and display backend — adjust for your environment
# Linux: qemu-system-<arch> + gtk or sdl
# macOS: qemu-system-aarch64 (arm64) or qemu-system-x86_64 + gtk/cocoa
ifeq ($(ARCH),aarch64)
  QEMU_BIN  ?= qemu-system-aarch64
  QEMU_ARGS ?= -M virt -cpu cortex-a72
  # UEFI firmware — Homebrew on macOS, or /usr/share/edk2 on Linux
  ifeq ($(shell uname -s),Darwin)
    QEMU_BIOS ?= $(shell brew --prefix qemu 2>/dev/null)/share/qemu/edk2-aarch64-code.fd
  else
    QEMU_BIOS ?= /usr/share/edk2/aarch64/QEMU_EFI.fd
  endif
else
  QEMU_BIN  ?= qemu-system-x86_64
  QEMU_ARGS ?=
  QEMU_BIOS ?=
endif

QEMU_DISPLAY ?= gtk
QEMU_MEM     ?= 4096
QEMU_SMP     ?= 4

ISO_FILE := $(ISO_DIR)/bootiso/install.iso

# bootc-image-builder must run as a privileged container (it needs loop
# devices + mounts), which rootless podman cannot provide. So `make iso`
# elevates to rootful podman via sudo, and the local image is copied into
# rootful storage first with `podman save | sudo podman load`.
# On macOS, podman machine handles the rootful/privileged escalation.

.PHONY: build iso test clean help

## Build the OCI image (auto-detects architecture)
build:
	podman build -t $(IMAGE_NAME):$(IMAGE_TAG) .

## Generate a bootable ISO from the OCI image
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

## Boot the ISO in QEMU for testing (supports arm64 + x86_64)
test: iso
	$(QEMU_BIN) \
		-m $(QEMU_MEM) \
		-smp $(QEMU_SMP) \
		$(QEMU_ARGS) \
		$(if $(QEMU_BIOS),-bios $(QEMU_BIOS)) \
		-cdrom $(ISO_FILE) \
		-boot d \
		-display $(QEMU_DISPLAY)

## Show detected architecture and QEMU config
info:
	@echo "Architecture: $(ARCH)"
	@echo "QEMU binary:  $(QEMU_BIN)"
	@echo "QEMU args:    $(QEMU_ARGS)"
	@echo "QEMU BIOS:    $(QEMU_BIOS)"
	@echo "ISO path:     $(ISO_FILE)"

## Remove built artifacts
clean:
	podman rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	rm -rf $(ISO_DIR)

## Show available targets
help:
	@grep -E '^[a-zA-Z_-]+:' Makefile | sed 's/://' | sort
