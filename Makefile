# ============================================
# DOB — Build automation (Fedora KDE live ISO)
# ============================================
# Builds a normal Fedora KDE live ISO via livemedia-creator inside the
# podman machine (native arch). No bootc, no composefs.

IMAGE_NAME := dob
ISO_DIR    := ./output

UNAME_M    := $(shell uname -m)
ifeq ($(UNAME_M),aarch64)
  ARCH     ?= aarch64
else ifeq ($(UNAME_M),arm64)
  ARCH     ?= aarch64
else
  ARCH     ?= x86_64
endif

ifeq ($(ARCH),aarch64)
  QEMU_BIN  ?= qemu-system-aarch64
  QEMU_ARGS ?= -M virt -cpu cortex-a72
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

ISO_FILE := $(ISO_DIR)/dob-live-$(ARCH).iso

.PHONY: build iso test info clean help

## Build the DOB live ISO (native arch, inside the podman machine)
build:
	./scripts/build-live-iso.sh

## Alias for build
iso: build

## Boot the ISO in QEMU (native arch)
test: build
	$(QEMU_BIN) \
		-m $(QEMU_MEM) \
		-smp $(QEMU_SMP) \
		$(QEMU_ARGS) \
		$(if $(QEMU_BIOS),-bios $(QEMU_BIOS)) \
		-cdrom $(ISO_FILE) \
		-boot d \
		-display $(QEMU_DISPLAY)

## Show detected arch + QEMU config
info:
	@echo "Architecture: $(ARCH)"
	@echo "QEMU binary:  $(QEMU_BIN)"
	@echo "QEMU args:    $(QEMU_ARGS)"
	@echo "QEMU BIOS:    $(QEMU_BIOS)"
	@echo "ISO path:     $(ISO_FILE)"

## Remove build artifacts
clean:
	rm -rf $(ISO_DIR)

## Show available targets
help:
	@grep -E '^[a-zA-Z_-]+:' Makefile | sed 's/://' | sort
