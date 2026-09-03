# ============================================
# DOB — A Fedora Atomic OS born from a dream
# ============================================
# Phase 1: Base image & build pipeline
#
# Base: Fedora 44 bootc (minimal). The KDE Plasma
# desktop is layered on via the kde-desktop group.
#
# Build:
#   podman build -t dob:latest .
#
# ISO:
#   See Makefile / scripts/build-iso.sh

FROM quay.io/fedora/fedora-bootc:44

# --- Metadata ----------------------------------------------------------
LABEL org.opencontainers.image.title="DOB"
LABEL org.opencontainers.image.description="A Fedora Atomic OS born from a dream"
LABEL org.opencontainers.image.version="1.0"

# --- Layer the KDE Plasma desktop + DOB packages -----------------------
# The kde-desktop comps group pulls in the full Plasma 6 stack.
# (dnf expands comps groups; rpm-ostree does not support them here.)
# Additional packages are defined in configs/packages.txt.
COPY configs/packages.txt /tmp/packages.txt
RUN dnf -y install \
        @kde-desktop \
        $(grep -vE '^\s*#|^\s*$' /tmp/packages.txt | tr '\n' ' ') && \
    dnf clean all && \
    rm /tmp/packages.txt

# --- Enable the graphical login manager (SDDM) -------------------------
# The kde-desktop group wires display-manager.service to plasmalogin.
# We prefer sddm (more themable for DOB branding), so clear the
# existing symlink first, then enable sddm and boot to the desktop.
RUN rm -f /etc/systemd/system/display-manager.service && \
    systemctl enable sddm && \
    systemctl set-default graphical.target

# --- Phase 2: Branding ---------------------------------------------------
# Desktop wallpaper (KDE default for new users via /etc/skel)
COPY assets/wallpaper/ /usr/share/wallpapers/DOB-Mountains/contents/images/

# GRUB 2 boot menu theme: mountain background, "DOB" title, red accent
COPY assets/grub/ /usr/share/grub/themes/dob/

# Plymouth boot splash: mountain silhouette + pulsing progress
COPY assets/plymouth/ /usr/share/plymouth/themes/dob/
RUN plymouth-set-default-theme dob && \
    plymouth-set-default-theme --rebuild-initrd 2>/dev/null || true

# Bake in DOB system configuration ---------------------------------
# configs/etc/ is copied into /etc/. Contains:
#   - /etc/default/grub    (GRUB_THEME + plymouth.theme cmdline)
#   - /etc/skel/           (default KDE wallpaper for new users)
COPY configs/etc/ /etc/
