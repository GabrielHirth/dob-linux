# DOB — Phase 2: Branding (Design Spec)

**Date:** 2026-09-03
**Status:** Approved
**Version:** 1.0

## Context

DOB is a Fedora Atomic-based operating system born from a dream. It features
a Frosted Glass (Aero) themed KDE Plasma desktop with red-tinted icons
(mischief), a mountainous background, dreamlike easter eggs, and a secret
"Dream Mode" activated by the Konami code.

Phase 1 established the build foundation: a working `dob:latest` OCI image
(KDE Plasma 6 desktop) and a bootable ISO via bootc-image-builder.

**This is Phase 2: Branding.** The goal is to replace the stock Fedora
boot-time branding with DOB's — a mountainous, red-accented, dreamlike look
that carries from the bootloader through the boot splash to the desktop
wallpaper. Theming (Aero/glass, red-tinted icons) and easter eggs remain for
later phases.

**Target:** Fedora 44 Atomic (bootc) OCI image → bootable ISO.

## Architecture

On Atomic/bootc images, `/boot` is populated at deploy time from the image
content, and the bootloader config (grub.cfg) is generated. Therefore **all
branding must be baked into the image** via the Containerfile so it persists
across updates and appears in the generated bootloader. Three components
share one visual anchor: the user-provided mountain wallpaper image.

```
assets/wallpaper/DOBMountains.jpg   (user-provided mountain scene)
        │
        ├─► /usr/share/wallpapers/DOB-Mountains/     (KDE desktop wallpaper)
        ├─► assets/grub/background.png  ──► /usr/share/grub/themes/dob/
        └─► assets/plymouth/ (derived)  ──► /usr/share/plymouth/themes/dob/
```

## Components

### 1. Desktop Wallpaper

- User-provided mountain image (`assets/wallpaper/DOBMountains.jpg`, any
  size/format) is baked into `/usr/share/wallpapers/DOB-Mountains/` so KDE
  lists it as an available wallpaper.
- Set as the **default for new users** via `/etc/skel/.config/` (Plasma
  desktop containment config), so any account logs into the DOB mountains.
- Reused as the GRUB theme background and Plymouth splash art.

### 2. GRUB Custom Theme

- Full GRUB 2 theme authored at `/usr/share/grub/themes/dob/`:
  - `theme.txt` — layout: top-title "DOB", menu box, boot messages, red
    accent (the mischief tint), mountain background.
  - `background.png` — generated from the wallpaper (resized/scaled for GRUB).
  - `font.pf2` — generated from a bundled system font via `grub2-mkfont`.
- Selected via `GRUB_THEME=/usr/share/grub/themes/dob/theme.txt` in
  `/etc/default/grub`, which the deploy-time grub.cfg generation reads.

### 3. Plymouth Custom Splash

- New theme authored at `/usr/share/plymouth/themes/dob/`:
  - `dob.plymouth` — theme manifest.
  - `dob.script` — animation: mountain silhouette with a pulsing progress
    indicator and "DOB" text.
  - Derived graphics (logo, progress frame) generated from the wallpaper.
- Enabled at build time with `plymouth-set-default-theme dob`.
- `plymouth.theme=dob` added to the kernel cmdline via `/etc/default/grub`
  for robustness.

## Asset Generation

The GRUB background, `.pf2` font, and Plymouth graphics are generated from
the wallpaper and a bundled font using ImageMagick and `grub2-mkfont` —
a small script (`scripts/generate-brand-assets.sh`) does this so assets are
reproducible and re-generable if the wallpaper changes. No manual binary
authoring.

## Directory Layout (added)

```
dob1.5-linux/
├── assets/
│   ├── wallpaper/DOBMountains.jpg   # user provides
│   ├── grub/                        # generated + authored
│   │   ├── theme.txt
│   │   ├── background.png
│   │   └── font.pf2
│   └── plymouth/                    # generated + authored
│       ├── dob.plymouth
│       ├── dob.script
│       └── (derived graphics)
├── configs/etc/
│   ├── default/grub                 # GRUB_THEME + plymouth.theme cmdline
│   └── skel/.config/                # default desktop wallpaper for new users
└── scripts/
    └── generate-brand-assets.sh
```

## Containerfile Changes

```dockerfile
# --- Phase 2: Branding ----------------------------------------------
# Desktop wallpaper
COPY assets/wallpaper/ /usr/share/wallpapers/DOB-Mountains/contents/images/
# GRUB theme
COPY assets/grub/ /usr/share/grub/themes/dob/
# Plymouth splash theme
COPY assets/plymouth/ /usr/share/plymouth/themes/dob/
RUN plymouth-set-default-theme dob && \
    plymouth-set-default-theme --rebuild-initrd 2>/dev/null || true
# (existing) COPY configs/etc/ /etc/  → picks up default/grub + skel
```

## Scope

**In scope (Phase 2):** desktop wallpaper, custom GRUB theme, custom Plymouth
splash — all baked into the image.

**Out of scope (later phases):** Aero/frosted-glass theming + red-tinted
icons (Phase 3), easter eggs / MOTDs (Phase 4), Dream Mode / Konami code
(Phase 5).

## Verification

1. `make build` — image builds with DOB artwork baked in.
2. `make iso` — bootable ISO produced.
3. Boot in QEMU and confirm:
   - GRUB menu shows the DOB theme (mountain background, "DOB" title, red accent).
   - Plymouth splash appears during boot with the DOB animation.
   - Desktop loads to the DOB mountain wallpaper.
