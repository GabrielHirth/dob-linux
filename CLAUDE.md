# DOB — Project Context

## What is DOB?

DOB is a **Fedora Atomic (bootc)** based operating system born from a dream.
A Frosted Glass (Aero) themed KDE Plasma desktop with red-tinted icons
(mischief), a mountainous background, dreamlike nonsensical easter eggs, and
a secret "Dream Mode" activated by the Konami code that gradually descends
into surrealist chaos.

**User:** Gabriel — has Linux experience but is new to distro building.
**Target hardware:** x86_64 (Linux) + ARM64 (Apple Silicon macOS).
**Build environment:** WSL2 on Windows (primary), macOS (secondary).

---

## Current Status: Phase 2 Branding — IN PROGRESS

| Phase | Status | Summary |
|-------|--------|---------|
| 1 — Base image & build pipeline | ✅ Complete | OCI image builds, ISO boots to KDE Plasma desktop |
| 2 — Branding (GRUB, Plymouth, wallpaper) | 🔧 In progress | All assets authored, Containerfile updated, Plymouth verified. Need final ISO regen + boot test. |
| 3 — Aero theming + red-tinted icons | ⬜ Not started | |
| 4 — Easter eggs | ⬜ Not started | |
| 5 — Dream Mode (Konami code) | ⬜ Not started | |

---

## What's Built

### Files

```
dob1.5-linux/
├── Containerfile                       # OS definition — fedora-bootc:44 + KDE + branding
├── Makefile                            # build / iso / test / clean targets
├── assets/
│   ├── wallpaper/DOBMountains.jpg      # Placeholder mountain wallpaper (3840x2160)
│   ├── grub/theme.txt                  # GRUB 2 theme (DOB title, mountain bg, red accent)
│   ├── grub/background.png             # GRUB background (1920x1080)
│   ├── grub/font.pf2                   # GRUB font (DejaVu Sans Bold 24)
│   ├── plymouth/dob.plymouth           # Plymouth theme manifest
│   ├── plymouth/dob.script             # Plymouth animation script
│   ├── plymouth/dob-logo.png           # Plymouth center logo (512x512)
│   └── plymouth/progress-{01..12}.png  # Plymouth progress frames
├── configs/
│   ├── packages.txt                    # Packages layered via dnf (fedora-bootc:44)
│   ├── etc/default/grub                # GRUB_THEME + plymouth.theme=dob cmdline
│   └── etc/skel/.config/...            # KDE default wallpaper for new users
├── scripts/
│   ├── build-iso.sh                    # ISO helper (wraps bootc-image-builder)
│   └── generate-brand-assets.sh        # Regenerates GRUB/Plymouth assets from wallpaper
├── docs/superpowers/specs/             # Design specs (Phase 1 + Phase 2)
├── README.md                           # Build instructions + project overview
└── CLAUDE.md                           # This file — project context for Claude instances
```

### Key Technical Decisions

- **Base image:** `quay.io/fedora/fedora-bootc:44` (the Kinoite desktop image is NOT publicly pullable)
- **KDE is layered** via `dnf -y install @kde-desktop` in the Containerfile — rpm-ostree doesn't support comps groups
- **SDDM:** `rm -f /etc/systemd/system/display-manager.service` before `systemctl enable sddm` (kde-desktop wires it to plasmalogin)
- **ISO build requires rootful privileged podman:**
  ```
  podman save localhost/dob:latest | sudo podman load
  sudo podman run --rm --privileged --network host \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      quay.io/centos-bootc/bootc-image-builder:latest \
      --local --rootfs ext4 --type iso \
      localhost/dob:latest
  ```
  - `--privileged`: bib needs loop devices
  - `--network host`: rootful container DNS resolves mirrors to IPv6 only (WSL2 issue), host networking fixes this
  - `--rootfs ext4`: bib requires an explicit root filesystem type
- **Plymouth theme** goes into `/etc/plymouth/plymouthd.conf` (not `plymouthd.defaults`)
- **ISO output path:** `output/bootiso/install.iso` (not `output/dob-latest.iso` — bib puts it in a subdir)
- **Asset generation** is done on the host via ImageMagick + `grub-mkfont` — run `scripts/generate-brand-assets.sh`

### Build Commands

```bash
# Build OCI image (auto-detects architecture)
podman build -t dob:latest .

# Build ARM64 image on x86_64 host
podman build --arch arm64 -t dob:latest .

# Generate ISO (requires sudo for rootful privileged bib)
./scripts/build-iso.sh        # or: make iso

# Boot test in QEMU (auto-detects arch)
make test

# Cross-build ISO for ARM64
ARCH=arm64 make iso

# Regenerate GRUB/Plymouth assets from a new wallpaper
# (replace assets/wallpaper/DOBMountains.jpg first)
./scripts/generate-brand-assets.sh
```

---

## Phase 2: What's Left

1. **Final ISO regen + boot test** — The Containerfile and all assets are ready but the ISO hasn't been rebuilt with the Phase 2 assets yet. Run:
   ```bash
   podman build -t dob:latest .
   ./scripts/generate-brand-assets.sh   # regenerate from current wallpaper
   ./scripts/build-iso.sh               # generate ISO
   make test                            # boot test in QEMU
   ```
2. **User's mountain image** — The placeholder `assets/wallpaper/DOBMountains.jpg` is a generated ImageMagick scene. Gabriel will provide a real mountain image. When they do, drop it into `assets/wallpaper/DOBMountains.jpg`, run `./scripts/generate-brand-assets.sh`, rebuild, and regenerate ISO.
3. **Verify GRUB theme in QEMU** — The GRUB theme is authored but hasn't been boot-tested yet.
4. **Verify Plymouth splash in QEMU** — Same — authored but not boot-tested.
5. **Verify KDE wallpaper default** — The `/etc/skel` config sets it, but needs a live test.

---

## Phase 3-5 Roadmap (Future)

- **Phase 3:** Aero (frosted glass) theming via Kvantum + red-tinted icon set
- **Phase 4:** Easter eggs — terminal MOTDs, subtle surprises, nonsensical boot messages
- **Phase 5:** Dream Mode — Konami code activation → gradual escalation from ominous pop-up to full surrealist chaos

---

## Gotchas

- **WSL2 + rootful podman DNS:** Rootful container DNS (`10.255.255.254`) resolves to IPv6 only. Mirror fetches hang. Fix: `--network host` on the bib container.
- **KDE group sets plasmalogin:** `@kde-desktop` wires `display-manager.service` to `plasmalogin.service`. Must clear it before enabling SDDM.
- **rpm-ostree doesn't do groups:** Use `dnf install @kde-desktop` inside the Containerfile (works in build environment where it's a real rootfs).
- **Plymouth script plugin:** `plymouth-plugin-script` is a separate package — must be explicitly added to `packages.txt`.
- **`plymouth-set-default-theme` writes to `/etc/plymouth/plymouthd.conf`**, not `plymouthd.defaults`. This is correct and expected.
- **bib ISO output:** Writes to `output/bootiso/install.iso`, not `output/<name>.iso`.

---

## Repository

Not a git repository at the working directory level (the repo is at `/home/gabrielh/dob1.5-linux`).
Recent commits:
- `eeee159` — add plymouth-plugin-script for Plymouth theme support
- `ea98d5d` — add plymouth package for Phase 2 boot splash
- `6183c12` — update README with correct ISO path and verified status
- `491b7a5` — correct ISO output path to match bootc-image-builder layout
