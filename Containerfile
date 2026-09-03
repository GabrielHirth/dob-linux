# ============================================
# DOB — A Fedora Atomic OS born from a dream
# ============================================
# Phase 1: Base image & build pipeline
#
# Build:
#   podman build -t dob:latest .
#
# ISO:
#   See Makefile / scripts/build-iso.sh

FROM quay.io/kinoite/fedora-kinoite:44

# --- Metadata ----------------------------------------------------------
LABEL org.opencontainers.image.title="DOB"
LABEL org.opencontainers.image.description="A Fedora Atomic OS born from a dream"
LABEL org.opencontainers.image.version="1.0"

# --- Layer DOB packages onto the immutable base -----------------------
# Packages are defined in configs/packages.txt (one per line, '#' comments).
COPY configs/packages.txt /tmp/packages.txt
RUN rpm-ostree install --assumeyes \
        $(grep -vE '^\s*#|^\s*$' /tmp/packages.txt | tr '\n' ' ') && \
    rpm-ostree cleanup -m && \
    rm /tmp/packages.txt

# --- Bake in DOB system configuration ---------------------------------
# configs/etc/ is copied into /etc/. Later phases add:
#   - Plymouth/boot splash themes
#   - GRUB customization
#   - systemd services (Dream Mode, easter eggs)
#   - User-level defaults
COPY configs/etc/ /etc/
