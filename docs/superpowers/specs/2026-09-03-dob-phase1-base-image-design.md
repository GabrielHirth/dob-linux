# DOB — Phase 1: Base Image & Build Pipeline (Design Spec)

**Date:** 2026-09-03
**Status:** Approved
**Version:** 1.0

## Context

DOB is a Fedora Atomic-based operating system born from a dream. It features a Frosted Glass (Aero) themed KDE Plasma desktop with red-tinted icons, dreamlike easter eggs, and a secret "Dream Mode" activated by the Konami code that gradually descends into surrealist chaos.

This is Phase 1 of a 5-phase build. The goal is to establish the **build foundation**: a Containerfile that defines the DOB OS image, a build pipeline using `podman` and `bootc-image-builder`, and a testable bootable ISO. This phase produces a working (but unstyled) Fedora KDE desktop — all DOB personality (branding, theming, easter eggs, Dream Mode) comes in later phases.

**Target:** Fedora 44 Atomic (KDE/Kinoite), bootc-native OCI image, bootable ISO output.

## Architecture

```
Containerfile + packages.txt + configs/
        │
        ▼  (podman build)
   OCI Image: dob:latest
        │
        ▼  (bootc-image-builder)
   Bootable ISO: output/dob-latest.iso
        │
        ▼  (qemu or bare metal)
   Running DOB desktop
```

- **Base image:** `quay.io/kinoite/fedora-kinoite:44` — Fedora Atomic with KDE Plasma pre-installed.
- **Package layering:** `rpm-ostree install` inside the Containerfile.
- **Config injection:** `COPY configs/etc/ /etc/` bakes system configuration into the image.

## Components

1. **Containerfile** — single source of truth for the OS definition.
2. **configs/packages.txt** — RPM package list (grows across phases).
3. **Makefile** — build/iso/test/clean automation.
4. **scripts/build-iso.sh** — ISO generation helper wrapping bootc-image-builder.
5. **README.md** — build instructions and project overview.

## Scope

**In scope (Phase 1):** working Fedora Atomic KDE desktop, build pipeline, testable ISO.

**Out of scope (later phases):** branding (GRUB/Plymouth/wallpaper), Aero theming + red-tinted icons, easter eggs/terminal MOTDs, Dream Mode/Konami code.

## Verification

1. `make build` → `dob:latest` OCI image
2. `make iso` → bootable ISO in `./output/`
3. `make test` → boots QEMU to KDE Plasma
4. Inside VM: `rpm-ostree status` shows layered packages; `kvantum` installed
