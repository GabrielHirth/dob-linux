# DOB 🌀

**A Fedora Atomic OS born from a dream.**

DOB is a Fedora Atomic (bootc) based operating system built from a single
Containerfile. It features a Frosted Glass (Aero) themed KDE Plasma desktop
with red-tinted icons, dreamlike easter eggs, and a secret "Dream Mode"
activated by the Konami code that gradually descends into surrealist chaos.

Supports **x86_64** and **ARM64 (Apple Silicon)** architectures.

---

## Overview

```
Containerfile + packages.txt + configs/
        │
        ▼  (podman build)
   OCI Image: dob:latest        ← ARM64 or x86_64
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
- **Architectures:** x86_64 (Intel/AMD), aarch64 (Apple Silicon / ARM64)

---

## macOS / Apple Silicon Build Instructions

### Prerequisites

Install podman and QEMU via Homebrew:

```bash
# Podman (runs a Linux VM for building)
brew install podman

# QEMU (for testing ARM64 ISOs locally)
brew install qemu
```

### Initialize podman machine

Podman on macOS runs inside a lightweight Linux VM. Initialize and start it:

```bash
# Create the VM (ARM64 on Apple Silicon) — MUST be rootful
# bootc-image-builder (ISO generation) refuses to run on rootless podman.
podman machine init --rootful --arch arm64

# Start the VM
podman machine start

# Verify it's running and rootful
podman info | grep -i arch
# Should show: arch: aarch64

podman info | grep -i rootless
# Should show: rootless: false
```

> **Already created the machine without `--rootful`?** Convert it:
> ```bash
> podman machine stop
> podman machine set --rootful
> podman machine start
> podman info | grep -i rootless   # expect: rootless: false
> ```
> Note: switching to rootful changes the storage location, so any images
> built earlier as rootless won't be visible — rebuild them (`make build`).

### Build & test on macOS

```bash
# 1. Build the OCI image (ARM64 — auto-detected)
podman build -t dob:latest .

# 2. Generate the ARM64 ISO
# Runs bootc-image-builder directly — no sudo needed on macOS,
# but the podman machine MUST be rootful (see init step above).
./scripts/build-iso.sh dob:latest

# 3. Test in QEMU
# The Makefile auto-detects arm64 on Apple Silicon and uses the right QEMU
make test

# Or run QEMU directly:
qemu-system-aarch64 \
    -M virt -cpu cortex-a72 \
    -m 4096 -smp 4 \
    -bios $(brew --prefix qemu)/share/qemu/edk2-aarch64-code.fd \
    -cdrom output/bootiso/install.iso \
    -boot d \
    -display gtk
```

### Apple Silicon hardware (bare metal)

To boot DOB natively on Apple Silicon, you need a UEFI shim installed.
The easiest path:

1. Install [Asahi Linux](https://asahilinux.org/) first (provides the
   UEFI bootloader and hardware drivers for Apple Silicon).
2. Once Asahi is installed, DOB can be installed as a second OS.

> **Note:** Apple Silicon Macs require a signed UEFI shim to boot Linux.
> Asahi Linux provides this. Without it, only macOS can boot.

---

## Linux Build Instructions

### Prerequisites

```bash
# Fedora / RHEL
sudo dnf install podman qemu-system-x86

# Ubuntu / Debian
sudo apt-get install podman qemu-system-x86
```

### Build & test on Linux

```bash
# 1. Build the OCI image (auto-detects x86_64)
make build

# 2. Generate the ISO
make iso

# 3. Boot in QEMU
make test

# Or check detected arch and QEMU config
make info
```

### Cross-architecture builds

To build an ARM64 image on an x86_64 host (or vice versa):

```bash
# Build ARM64 image on x86_64 host
podman build --arch arm64 -t dob:latest .

# Or specify explicitly
ARCH=arm64 make iso
```

---

## Build & Test

```bash
# 1. Build the OCI image
make build

# 2. Generate a bootable ISO
make iso

# 3. Boot it in QEMU for testing
make test

# Show detected architecture and QEMU config
make info
```

### Makefile targets

| Target  | What it does                                  |
|---------|-----------------------------------------------|
| `build` | `podman build` → `dob:latest` OCI image        |
| `iso`   | Generate bootable ISO via bootc-image-builder |
| `test`  | Boot the ISO in QEMU (arm64 or x86_64)        |
| `info`  | Show detected arch and QEMU config            |
| `clean` | Remove built image and ISO                     |
| `help`  | List all targets                               |

---

## Project Structure

```
dob1.5-linux/
├── Containerfile            # The entire OS definition
├── Makefile                 # Build automation (arm64 + x86_64)
├── CLAUDE.md                # Project context for Claude sessions
├── HANDOFF.md               # Session handoff prompt
├── assets/
│   ├── wallpaper/           # DOB mountain wallpaper
│   ├── grub/                # GRUB 2 boot theme
│   └── plymouth/            # Plymouth boot splash
├── configs/
│   ├── packages.txt         # RPM packages (grows across phases)
│   └── etc/                 # System config baked into image
├── scripts/
│   ├── build-iso.sh         # ISO generation helper
│   └── generate-brand-assets.sh
├── docs/superpowers/specs/  # Design specs
└── output/                  # Generated ISOs (gitignored)
```

---

## Roadmap

| Phase | What it adds                                  |
|-------|-----------------------------------------------|
| **1** | Base image & build pipeline ✅                |
| **2** | Branding: GRUB, Plymouth boot splash, wallpaper ✅ |
| **3** | Aero theming, red-tinted icons                |
| **4** | Easter eggs: terminal MOTDs, subtle surprises |
| **5** | Dream Mode: Konami code + gradual escalation  |

---

## Verification

After booting the ISO, inside the VM:

```bash
# Atomic/ostree status
rpm-ostree status

# Confirm DOB packages were layered
rpm-ostree list | grep -i kvantum

# Check architecture
uname -m
# Should show: aarch64 (ARM64) or x86_64
```
