# DOB — Fedora KDE Live ISO Conversion (design)

Date: 2026-09-03
Status: Approved
Branch: `convert-fedora-kde`

## 1. Why

DOB is currently a Fedora Atomic (bootc) OS: a Containerfile built into an
OCI image, then to an ISO via `bootc-image-builder`. GRUB theming is broken
on this path because the bootc/ostree `composefs` storage backend defeats
`grub2-probe`: `grub2-mkconfig` copies the GRUB theme files to
`/boot/grub2/themes/` but never writes the theme block into `grub.cfg`, so
the installed GRUB menu stays untitled no matter what.

Fix: abandon the Atomic/bootc approach and rebuild DOB as a **normal Fedora
44 KDE** distribution, delivered as a live ISO built with Fedora's standard
spin tooling (kickstart + livemedia-creator). On a normal Fedora there is no
composefs, so GRUB/Plymouth/wallpaper theming works through the standard
mechanisms.

## 2. Decisions (locked)

| Decision | Choice |
|----------|--------|
| Deliverable | Fedora KDE Live ISO (kickstart + livemedia-creator) |
| Architectures | x86_64 + aarch64 (each host builds its native arch) |
| Content carried over | Everything from Phase 1+2 (packages, GRUB theme, Plymouth, wallpaper) |
| Phase scope | Conversion only — no Phase 3 (Aero) in this plan |
| Build host | Inside the existing podman machine (Fedora Linux VM) via `podman machine ssh` + `livemedia-creator --no-virt`. No new VM. |
| Base kickstart | `fedora-live-kde.ks` (Fedora's KDE live spin), customized for DOB |

## 3. Repo restructure

Branch `convert-fedora-kde`:

```
dob-linux/
├── kickstart/
│   └── dob-live-kde.ks            # DOB kickstart (fedora-live-kde.ks + %packages + %post)
├── assets/                        # UNCHANGED (wallpaper, grub, plymouth)
├── configs/
│   ├── packages.txt               # reused (trimmed of bootc-only bits)
│   └── etc/                       # reused (skel, grub, plymouth)
├── scripts/
│   ├── build-live-iso.sh          # NEW — podman machine ssh + livemedia-creator --no-virt
│   └── generate-brand-assets.sh   # UNCHANGED
├── Makefile                       # REWRITTEN (live-iso / build / test / clean / info)
├── Containerfile                  # REMOVED
├── docs/superpowers/specs/2026-09-03-dob-fedora-kde-conversion-design.md  # this file
├── README.md / CLAUDE.md          # updated for the kickstart/live pipeline
```

## 4. Build flow

Per host architecture (native only — same reality as today):

1. `make build` — inside the podman machine, run a Fedora container that
   installs `livemedia-creator` and `lorax-lmc-novirt`, then runs
   `livemedia-creator --no-virt` against the DOB kickstart.
2. Output: `output/dob-live-<arch>.iso`.
3. `make test` — QEMU boots the ISO (native arch).

`scripts/build-live-iso.sh` encapsulates the podman-machine invocation:

```bash
podman machine ssh -- \
  podman run --rm --privileged \
    -v "$PWD":/work:z \
    fedora:44 \
    bash /work/scripts/_lmc-build.sh <arch>
```

`_lmc-build.sh` (inside the container) installs `livemedia-creator
lorax-lmc-novirt`, stages the kickstart + assets, and runs
`livemedia-creator --no-virt --iso-only --ks ...`.

Arch handling: the podman machine's native arch (aarch64 on Apple Silicon,
x86_64 on WSL2) is detected and used, mirroring the old Makefile's
`uname -m` logic.

## 5. Kickstart content (`kickstart/dob-live-kde.ks`)

Based on Fedora's `fedora-live-kde.ks` (fetched from
`https://pagure.io/fedora-kickstarts/raw/main/f/fedora-live-kde.ks`), with:

- **`%packages`**: KDE live group + DOB packages from `configs/packages.txt`
  (kvantum, firefox, sddm, plymouth, plymouth-plugin-script, …), trimmed of
  bootc-only entries.
- **`%post`**:
  - copy DOB GRUB theme → `/boot/grub2/themes/dob/`
  - write `GRUB_THEME=...` into `/etc/default/grub`
  - run `grub2-mkconfig -o /boot/grub2/grub.cfg` (works on normal Fedora)
  - set Plymouth theme to DOB
  - bake KDE skel wallpaper (from `configs/etc/skel/`)
- No composefs anywhere. No bootc.

Assets are copied into the image from `assets/` and referenced by absolute
paths (`/usr/share/...`) exactly as the current Containerfile does, so the
existing asset set and paths are reused unchanged.

## 6. Makefile targets

| Target | What it does |
|--------|--------------|
| `build` | Build the DOB live ISO (native arch) |
| `iso`   | Alias for `build` |
| `test`  | Boot the ISO in QEMU (native arch) |
| `info`  | Show detected arch + QEMU config |
| `clean` | Remove `output/` |
| `help`  | List targets |

## 7. Testing / verification

- ISO builds cleanly for the host arch.
- QEMU boot reaches the KDE desktop.
- Installed system has themed GRUB:
  `grep -i theme /boot/grub2/grub.cfg` → non-empty.
- Plymouth splash shows DOB theme.
- KDE wallpaper is DOB mountain for new users.

## 8. Docs

- `README.md`: rewritten for kickstart/live pipeline; drop bootc, rootful
  podman, and composefs gotchas (no longer apply).
- `CLAUDE.md`: status table + gotchas updated for the conversion.

## 9. Out of scope (future)

- Phase 3 Aero frosted-glass theming + red-tinted icons.
- Phase 4 easter eggs. Phase 5 Dream Mode.
- Cross-architecture builds (x86_64 ISO on aarch64 host and vice versa).
- CI (GitHub Actions) build — deferred unless needed.
