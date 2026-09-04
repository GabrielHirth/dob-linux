# DOB — Project Context

## What is DOB?

DOB is a **Fedora KDE Live** based operating system born from a dream.
A Frosted Glass (Aero) themed KDE Plasma desktop with red-tinted icons
(mischief), a mountainous background, dreamlike nonsensical easter eggs, and
a secret "Dream Mode" activated by the Konami code that gradually descends
into surrealist chaos.

**User:** Gabriel — has Linux experience but is new to distro building.
**Target hardware:** x86_64 (Linux) + ARM64 (Apple Silicon macOS).
**Build environment:** WSL2 on Windows (primary), macOS (secondary).

---

## Current Status: Conversion Complete — Phase 1+2 on Fedora KDE Live

| Phase | Status | Summary |
|-------|--------|---------|
| 1 — Base image & build pipeline | ✅ Complete | Fedora 44 KDE live ISO builds via livemedia-creator |
| 2 — Branding (GRUB, Plymouth, wallpaper) | ✅ Complete | GRUB theme, Plymouth splash, KDE wallpaper working |
| 3 — Aero theming + red-tinted icons | ⬜ Not started | |
| 4 — Easter eggs | ⬜ Not started | |
| 5 — Dream Mode (Konami code) | ⬜ Not started | |

**Note:** DOB was previously a Fedora Atomic (bootc) OS. The conversion to a normal Fedora KDE live ISO is complete on branch `convert-fedora-kde`. The bootc pipeline was abandoned because composefs broke GRUB theming.

---

## What's Built (convert-fedora-kde branch)

### Files

```
dob-linux/
├── kickstart/
│   └── dob-live-kde.ks            # DOB kickstart (fedora-live-kde.ks + DOB branding)
├── Makefile                        # build / iso / test / clean targets
├── assets/
│   ├── wallpaper/DOBMountains.jpg  # Mountain wallpaper (3840x2160)
│   ├── grub/                       # GRUB 2 theme (DOB title, mountain bg, red accent)
│   │   ├── theme.txt
│   │   ├── background.png
│   │   └── font.pf2
│   └── plymouth/                   # Plymouth boot splash
│       ├── dob.plymouth
│       ├── dob.script
│       ├── dob-logo.png
│       └── progress-01.png .. progress-12.png
├── configs/
│   ├── packages.txt                # DOB extra packages (kvantum, firefox, ...)
│   └── etc/                        # System config baked into image
│       ├── default/grub            # (overwritten by kickstart %post)
│       └── skel/                   # KDE default wallpaper for new users
├── scripts/
│   ├── _lmc-build.sh               # In-container livemedia-creator helper
│   ├── build-live-iso.sh           # Podman machine build wrapper
│   └── generate-brand-assets.sh    # Regenerates GRUB/Plymouth assets from wallpaper
├── docs/superpowers/specs/         # Design specs
├── README.md                       # Build instructions + project overview
└── CLAUDE.md                       # This file — project context for Claude instances
```

### Key Technical Decisions

- **Base:** Fedora 44 KDE live spin (`fedora-live-kde.ks` from `spin-kickstarts` package)
- **Build pipeline:** kickstart → `livemedia-creator --no-virt` inside a Fedora 44 container on the podman machine
- **No bootc, no ostree, no composefs** — plain Fedora, so GRUB/Plymouth/wallpaper theming works through standard mechanisms
- **GRUB theme** applied in kickstart `%post`: writes `/etc/default/grub` with `GRUB_THEME`, runs `grub2-mkconfig`
- **Plymouth theme** applied in kickstart `%post`: `plymouth-set-default-theme dob`
- **KDE wallpaper** baked via `/etc/skel` copied in kickstart `%post --nochroot`
- **ISO output:** `output/dob-live-<arch>.iso` (e.g. `dob-live-aarch64.iso`)
- **Build host:** podman machine (Fedora Linux VM) — runs `livemedia-creator --no-virt` inside a `fedora:44` container
- **Arch:** native only — podman machine builds its own arch (aarch64 on Apple Silicon, x86_64 on WSL2)

### Build Commands

```bash
# Build the live ISO (native arch, inside podman machine)
make build

# Alias
make iso

# Boot in QEMU (native arch)
make test

# Show detected arch and QEMU config
make info

# Clean artifacts
make clean

# Regenerate GRUB/Plymouth assets from a new wallpaper
# (replace assets/wallpaper/DOBMountains.jpg first)
./scripts/generate-brand-assets.sh
```

---

## Phase 3-5 Roadmap (Future)

- **Phase 3:** Aero (frosted glass) theming via Kvantum + red-tinted icon set
- **Phase 4:** Easter eggs — terminal MOTDs, subtle surprises, nonsensical boot messages
- **Phase 5:** Dream Mode — Konami code activation → gradual escalation from ominous pop-up to full surrealist chaos

---

## Gotchas (Fedora KDE Live pipeline)

- **livemedia-creator needs Linux + KVM** (or `--no-virt`). The build runs inside a Fedora container on the **podman machine** (your existing Linux VM), so no extra VM is needed.
- **No cross-arch builds** — the podman machine builds its native arch only (aarch64 on Apple Silicon, x86_64 on WSL2). macOS host cannot build directly; it only QEMU-tests the ARM64 ISO.
- **`spin-kickstarts` package** provides `/usr/share/spin-kickstarts/fedora-live-kde.ks` inside the build container.
- **`%post --nochroot`** uses `$INSTALL_ROOT` (not `/`) to copy repo assets into the image filesystem.
- **Bootc/composefs gotchas are obsolete** — no rootful podman required, no composefs, no GRUB probe issues.
- **`configs/etc/ostree/prepare-root.conf`** (a bootc leftover) is currently copied into the image but harmless — will be removed in cleanup.

---

## Repository

Git repo at `https://github.com/GabrielHirth/dob-linux.git`
Active branch: `convert-fedora-kde` (tracks `origin/convert-fedora-kde`)