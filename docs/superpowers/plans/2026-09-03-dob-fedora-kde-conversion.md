# DOB Fedora KDE Live ISO Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert DOB from a Fedora Atomic (bootc) Containerfile build to a normal Fedora 44 KDE live ISO built with livemedia-creator, restoring working GRUB/Plymouth/wallpaper theming.

**Architecture:** Replace the bootc pipeline (Containerfile + `bootc-image-builder`) with Fedora's standard spin tooling: a custom kickstart compiled into a live ISO by `livemedia-creator --no-virt`, run inside a Fedora container on the existing podman machine. Branding is applied in the kickstart `%post`/`%post --nochroot`, where plain-Fedora GRUB config works normally (no composefs).

**Tech Stack:** Kickstart (Anaconda), livemedia-creator / lorax-lmc-novirt, podman machine, QEMU, Makefile, bash.

**Spec:** `docs/superpowers/specs/2026-09-03-dob-fedora-kde-conversion-design.md`

## Global Constraints

- Build host: the existing **podman machine** (a Fedora Linux VM). Invoked via `podman machine ssh -- <cmd>`. No new VM, no CI.
- livemedia-creator runs inside a **Fedora 44 container** with `--no-virt` (no KVM). The repo is bind-mounted into the container at `/work`.
- **Native arch only**: the podman machine builds its own arch (aarch64 on Apple Silicon, x86_64 on WSL2). No cross-arch.
- `assets/` and `configs/etc/` are **reused unchanged** — do not modify their contents.
- **No composefs, no bootc** anywhere in the new pipeline.
- The `Containerfile` is **removed**; bootc/rootful/composefs gotchas are dropped from docs.
- Output ISO: `output/dob-live-<arch>.iso`.
- Kickstart based on Fedora's `fedora-live-kde.ks` (provided by the `spin-kickstarts` package at `/usr/share/spin-kickstarts/`).

---

### Task 1: Author the DOB kickstart

**Files:**
- Create: `kickstart/dob-live-kde.ks`

**Interfaces:**
- Consumes: `configs/packages.txt` (DOB package additions, trimmed in Task 5), `assets/grub/`, `assets/plymouth/`, `assets/wallpaper/`, `configs/etc/` (all referenced by absolute path under `/work` in `%post --nochroot`).
- Produces: `kickstart/dob-live-kde.ks` — the build input for Task 2. Uses `%include fedora-live-kde.ks` from `/usr/share/spin-kickstarts/` (available in the build container via the `spin-kickstarts` package, Task 2).

- [ ] **Step 1: Create the kickstart**

Write `kickstart/dob-live-kde.ks`:

```kickstart
# ============================================
# DOB — Fedora KDE Live kickstart
# ============================================
# Based on Fedora's fedora-live-kde.ks. Adds DOB packages and DOB branding
# (GRUB theme, Plymouth splash, KDE wallpaper). No composefs, no bootc —
# plain Fedora, so theming works through the normal mechanisms.
#
# Run by livemedia-creator --no-virt inside a Fedora container where the
# repo is bind-mounted at /work (see scripts/_lmc-build.sh).

%include /usr/share/spin-kickstarts/fedora-live-kde.ks

# --- DOB packages -------------------------------------------------------
# Extra DOB packages (kvantum, firefox, sddm, plymouth, ...), filtered from
# configs/packages.txt by _lmc-build.sh (Task 2) into %packages.
%packages
@kde-desktop
sddm
plymouth
plymouth-plugin-script
kvantum
firefox
%end

# --- DOB branding -------------------------------------------------------
# Copy repo assets + configs into the image. Runs outside the chroot
# (--nochroot) so /work (the bind-mounted repo) is reachable; $INSTALL_ROOT
# is the image's filesystem root.
%post --nochroot
cp -a /work/assets/grub/.        "$INSTALL_ROOT"/usr/share/grub/themes/dob/
cp -a /work/assets/plymouth/.    "$INSTALL_ROOT"/usr/share/plymouth/themes/dob/
cp -a /work/assets/wallpaper/.   "$INSTALL_ROOT"/usr/share/wallpapers/DOB-Mountains/contents/images/
cp -a /work/configs/etc/.        "$INSTALL_ROOT"/etc/
%end

# --- DOB %post (in-chroot) ----------------------------------------------
# Apply GRUB theme + Plymouth theme now that assets are in place. Plain
# Fedora: grub2-mkconfig reads /etc/default/grub and writes the theme into
# grub.cfg (this is what bootc/composefs broke).
%post
# GRUB theme
cat > /etc/default/grub << GRUB_EOF
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="DOB"
GRUB_THEME="/usr/share/grub/themes/dob/theme.txt"
GRUB_FONT="/usr/share/grub/themes/dob/font.pf2"
GRUB_CMDLINE_LINUX="rhgb quiet plymouth.theme=dob"
GRUB_EOF
grub2-mkconfig -o /boot/grub2/grub.cfg

# Plymouth splash
plymouth-set-default-theme dob

# Set DOB as default (SDDM already enabled by fedora-live-kde.ks)
%end
```

- [ ] **Step 2: Validate syntax**

Run: `python3 -c "import pykickstart; print('ok')" 2>/dev/null || pip install pykickstart` then:
`python3 -m pykickstart.validator kickstart/dob-live-kde.ks` (or `ksvalidator kickstart/dob-live-kde.ks` if available).
Expected: no syntax errors. If `%include` path unresolved because spin-kickstarts isn't installed locally, that is acceptable — note it in the report; resolution happens in the build container (Task 2). `ksvalidator` does not need the included file to check DOB-section syntax.

- [ ] **Step 3: Commit**

```bash
git add kickstart/dob-live-kde.ks
git commit -m "feat: add DOB Fedora KDE live kickstart"
```

---

### Task 2: Author the in-container build helper

**Files:**
- Create: `scripts/_lmc-build.sh`

**Interfaces:**
- Consumes: `kickstart/dob-live-kde.ks` (Task 1), `configs/packages.txt`, arch argument.
- Produces: `output/dob-live-<arch>.iso` (written to the bind-mounted repo at `/work/output`), plus the filtered package list injected into the kickstart `%packages`.

- [ ] **Step 1: Create the helper script**

Write `scripts/_lmc-build.sh` (runs INSIDE the Fedora container; arch passed as `$1`):

```bash
#!/usr/bin/env bash
# ============================================
# DOB — in-container live ISO build helper
# ============================================
# Runs inside a Fedora 44 container on the podman machine. The repo is
# bind-mounted at /work. Builds output/dob-live-<arch>.iso via
# livemedia-creator --no-virt (no KVM needed).
# Usage: _lmc-build.sh <x86_64|aarch64>
set -euo pipefail
ARCH="${1:?usage: _lmc-build.sh <x86_64|aarch64>}"
cd /work

# --- install tooling ----------------------------------------------------
dnf -y install \
    livemedia-creator \
    lorax-lmc-novirt \
    spin-kickstarts \
    pykickstart \
    >/dev/null

# --- prepare a filtered kickstart ---------------------------------------
# Drop bootc-only / N/A packages from configs/packages.txt and inject the
# remaining DOB packages into the %packages section of a build kickstart.
# The DOB kickstart already lists the core KDE group; this adds the extras.
grep -vE '^\s*#|^\s*$' configs/packages.txt > /work/.dob-packages.txt

# --- run the build ------------------------------------------------------
mkdir -p /work/output
livemedia-creator --no-virt --iso-only \
    --ks /work/kickstart/dob-live-kde.ks \
    --releasever 44 \
    --resultdir /work/output \
    --project "DOB" --volid "DOB" \
    --make-iso \
    --iso-name dob-live-${ARCH}.iso

echo "==> Built /work/output/dob-live-${ARCH}.iso"
```

- [ ] **Step 2: Syntax check**

Run: `bash -n scripts/_lmc-build.sh`
Expected: exit 0, no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/_lmc-build.sh
git commit -m "feat: add in-container livemedia-creator build helper"
```

> **Note (interfaces):** The `%packages` list is currently hardcoded in the kickstart (Task 1). The package-filtering line in this helper is the hook for Task 5 to make the kickstart read from `configs/packages.txt` at build time. Task 5 will update the kickstart to consume the filtered list. Do not expand scope here.

---

### Task 3: Author the podman-machine build wrapper

**Files:**
- Create: `scripts/build-live-iso.sh`

**Interfaces:**
- Consumes: `scripts/_lmc-build.sh` (Task 2). Produces: runs the build inside the podman machine; ISO lands in `output/`.
- Consumed by: Task 4 (Makefile calls this script).

- [ ] **Step 1: Create the wrapper**

Write `scripts/build-live-iso.sh`:

```bash
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
```

- [ ] **Step 2: Syntax check**

Run: `bash -n scripts/build-live-iso.sh`
Expected: exit 0, no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/build-live-iso.sh
git commit -m "feat: add podman-machine live ISO build wrapper"
```

---

### Task 4: Rewrite Makefile and remove Containerfile

**Files:**
- Modify: `Makefile` (full rewrite)
- Delete: `Containerfile`

**Interfaces:**
- Consumes: `scripts/build-live-iso.sh` (Task 3), QEMU binary config.
- Produces: `build` / `iso` / `test` / `info` / `clean` / `help` targets; removes the obsolete bootc pipeline.

- [ ] **Step 1: Rewrite Makefile**

Replace the entire `Makefile` with:

```make
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
```

- [ ] **Step 2: Remove Containerfile**

Run: `git rm Containerfile`

- [ ] **Step 3: Verify Makefile**

Run: `make help` then `make info`
Expected: targets listed; `info` shows correct arch, ISO path `output/dob-live-<arch>.iso`.

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "build: rewrite Makefile for Fedora KDE live ISO; drop Containerfile"
```

---

### Task 5: Trim packages.txt and wire it into the kickstart

**Files:**
- Modify: `configs/packages.txt` (remove bootc-only / invalid packages)
- Modify: `kickstart/dob-live-kde.ks` (make `%packages` read the filtered list)
- Modify: `scripts/_lmc-build.sh` (inject the filtered list into `%packages`)

**Interfaces:**
- Consumes: Task 1 kickstart, Task 2 helper. Produces: single source of truth (`configs/packages.txt`) for DOB packages.

- [ ] **Step 1: Review and trim packages.txt**

Read `configs/packages.txt`. Remove entries that are bootc/Atomic-specific or would break a normal Fedora install (e.g. `rpm-ostree`, `bootc` if present). Keep KDE/usability packages (kvantum, firefox, sddm, plymouth, plymouth-plugin-script, etc.). Keep only packages valid in Fedora 44. Note any removed in the report.

- [ ] **Step 2: Generate the %packages block at build time**

In `scripts/_lmc-build.sh`, replace the current package-filtering placeholder with a real injection. Before running livemedia-creator, write a build kickstart that appends the filtered packages to `%packages`:

```bash
# Build a kickstart with DOB extras injected into %packages.
# Inserts the filtered packages after the @kde-desktop line.
awk -v pkgs="$(paste -sd' ' /work/.dob-packages.txt)" \
    '/^@kde-desktop$/ { print; print pkgs; next } { print }' \
    /work/kickstart/dob-live-kde.ks > /work/dob-build.ks
```

Then point livemedia-creator at `/work/dob-build.ks` instead of the source kickstart (update the `--ks` argument).

- [ ] **Step 3: Update kickstart %packages to minimal**

Edit `kickstart/dob-live-kde.ks` so its `%packages` contains only the KDE group plus the always-required DOB packages (sddm, plymouth, plymouth-plugin-script), since the rest are injected at build time. Keep the `%post`/`%post --nochroot` sections unchanged.

- [ ] **Step 4: Validate**

Run: `bash -n scripts/_lmc-build.sh`
Expected: exit 0. Run: `grep -E 'bootc|rpm-ostree' configs/packages.txt || echo "clean"`
Expected: `clean` (no bootc/Atomic packages remain).

- [ ] **Step 5: Commit**

```bash
git add configs/packages.txt kickstart/dob-live-kde.ks scripts/_lmc-build.sh
git commit -m "chore: trim packages.txt and inject DOB packages into kickstart at build time"
```

---

### Task 6: Update README and CLAUDE.md

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: all prior tasks (final pipeline shape). Produces: accurate docs.

- [ ] **Step 1: Rewrite README.md**

Replace the bootc/Atomic build instructions with the Fedora KDE live ISO pipeline:
- Prereqs: podman machine (rootful not needed anymore), qemu.
- Build: `make build` / `make iso` → `output/dob-live-<arch>.iso`.
- Test: `make test`.
- Project structure (kickstart/, scripts/, assets/, configs/).
- Roadmap (Phase 1+2 complete on the new base; Phase 3+ unchanged).
- Verification: after installing the ISO, `grep -i theme /boot/grub2/grub.cfg` is non-empty; Plymouth shows DOB; KDE wallpaper is DOB mountain.

- [ ] **Step 2: Update CLAUDE.md**

- Move status table: Phase 1+2 re-scoped to the Fedora KDE base; mark conversion complete.
- Update "What's Built" file tree (remove Containerfile; add kickstart/, scripts/_lmc-build.sh, scripts/build-live-iso.sh).
- Replace bootc/composefs/rootful gotchas with live-ISO build gotchas (livemedia-creator wants Linux+KVM or --no-virt; runs inside podman machine; native arch only).
- Update build commands to `make build` / `make test`.

- [ ] **Step 3: Verify**

Run: `grep -c "bootc" README.md CLAUDE.md` — expected low/zero after rewrite (no longer the primary pipeline). Confirm `make help` targets documented in README match.

- [ ] **Step 4: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: update README and CLAUDE.md for Fedora KDE live ISO pipeline"
```

---

### Manual verification (outside task loop — final gate)

After all tasks pass review, the end-to-end build must run on the user's machine (cannot run in a sandbox — needs the podman machine):

```bash
make build                 # builds output/dob-live-<arch>.iso
make test                  # QEMU boots the ISO
```

Then inside the installed/live system:
```bash
grep -i theme /boot/grub2/grub.cfg     # non-empty = themed GRUB
```

This manual gate is a documented follow-up, not a task deliverable. Surface its completion in the final summary.
