# DOB 🌀

**A Fedora Atomic OS born from a dream.**

DOB is a Fedora Atomic (bootc) based operating system built from a single
Containerfile. It features a Frosted Glass (Aero) themed KDE Plasma desktop
with red-tinted icons, dreamlike easter eggs, and a secret "Dream Mode"
activated by the Konami code that gradually descends into surrealist chaos.

This repository contains the **Phase 1** foundation: the build pipeline and
a bootable base image. DOB's personality (branding, theming, easter eggs,
Dream Mode) is layered on in later phases.

---

## Overview

```
Containerfile + packages.txt + configs/
        │
        ▼  (podman build)
   OCI Image: dob:latest
        │
        ▼  (bootc-image-builder)
   Bootable ISO: output/bootiso/install.iso
        │
        ▼  (qemu or bare metal)
   Running DOB desktop
```

- **Base:** Fedora 44 bootc (minimal) — `quay.io/fedora/fedora-bootc:44`
- **Desktop:** KDE Plasma layered via the `@kde-desktop` group + SDDM
- **Packages:** layered via `dnf install` in the Containerfile
- **Config:** baked in from `configs/etc/`

---

## Prerequisites

- **podman** (or docker) — for building the OCI image
  ```bash
  sudo dnf install podman        # Fedora/RHEL
  sudo apt-get install podman    # Ubuntu/Debian
  ```
- **bootc-image-builder** — pulled automatically as a container image
- **qemu-system-x86_64** — for testing the ISO locally
  ```bash
  sudo dnf install qemu-system-x86        # Fedora/RHEL
  sudo apt-get install qemu-system-x86    # Ubuntu/Debian
  ```
- ~5GB free disk space for the build
- KVM acceleration recommended for fast VM testing

---

## Build & Test

```bash
# 1. Build the OCI image
make build

# 2. Generate a bootable ISO
make iso

# 3. Boot it in QEMU to test
make test
```

Or use the helper script directly:

```bash
podman build -t dob:latest .
./scripts/build-iso.sh dob:latest
```

### Makefile targets

| Target  | What it does                                  |
|---------|-----------------------------------------------|
| `build` | `podman build` → `dob:latest` OCI image        |
| `iso`   | Generate bootable ISO via bootc-image-builder |
| `test`  | Boot the ISO in QEMU                           |
| `clean` | Remove built image and ISO                     |
| `help`  | List all targets                               |

---

## Project Structure

```
dob1.5-linux/
├── Containerfile            # The entire OS definition
├── Makefile                 # Build automation
├── configs/
│   ├── packages.txt         # RPM packages to layer (grows across phases)
│   └── etc/                 # System config files baked into /etc/
├── scripts/
│   └── build-iso.sh         # ISO generation helper
├── docs/superpowers/specs/  # Design specs
└── output/                  # Generated ISOs (gitignored)
```

---

## Roadmap

| Phase | What it adds                                  |
|-------|-----------------------------------------------|
| **1** | Base image & build pipeline (current)         |
| **2** | Branding: GRUB, Plymouth boot splash, wallpaper |
| **3** | Aero theming, red-tinted icons                |
| **4** | Easter eggs: terminal MOTDs, subtle surprises |
| **5** | Dream Mode: Konami code + gradual escalation  |

---

## Verification

The Phase 1 pipeline is verified: `make build` produces the `dob:latest`
OCI image (KDE Plasma 6, SDDM, Firefox, Kvantum — 1670 packages), `make iso`
produces a bootable `output/bootiso/install.iso`, and QEMU boots it to the
Fedora installer.

After installing and booting the ISO, inside the VM:

```bash
# Atomic/ostree status
rpm-ostree status

# Confirm DOB packages were layered
rpm-ostree list | grep -i kvantum

# Check the image labels
podman inspect dob:latest | jq '.[0].Config.Labels'
```
