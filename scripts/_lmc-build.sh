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
