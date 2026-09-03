#!/usr/bin/env bash
# ============================================
# DOB — Brand asset generator
# ============================================
# Generates GRUB background, GRUB font, and Plymouth assets
# from the wallpaper image. Run after swapping the wallpaper or
# on first build.
#
# Usage:
#   ./scripts/generate-brand-assets.sh [wallpaper-path]
#
# Defaults to assets/wallpaper/DOBMountains.jpg
# Requires: ImageMagick (magick/convert), grub-mkfont

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WALLPAPER="${1:-$PROJECT_DIR/assets/wallpaper/DOBMountains.jpg}"
GRUB_DIR="$PROJECT_DIR/assets/grub"
PLYMOUTH_DIR="$PROJECT_DIR/assets/plymouth"
FONT_SRC="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

echo "==> DOB brand asset generator"
echo "    Wallpaper: $WALLPAPER"

# --- Verify prerequisites ------------------------------------------------
for cmd in magick convert grub-mkfont; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: $cmd not found." >&2
        echo "Install ImageMagick (magick/convert) and grub-common (grub-mkfont)." >&2
        exit 1
    }
done
test -f "$WALLPAPER" || { echo "ERROR: wallpaper not found: $WALLPAPER" >&2; exit 1; }
test -f "$FONT_SRC"  || { echo "ERROR: font not found: $FONT_SRC" >&2; exit 1; }

mkdir -p "$GRUB_DIR" "$PLYMOUTH_DIR"

# --- GRUB background ------------------------------------------------------
# GRUB 2 works best with PNG, 1600x900 (or similar 16:9)
echo "  [GRUB] Generating background..."
convert "$WALLPAPER" \
    -resize 1920x1080! \
    -quality 95 \
    "$GRUB_DIR/background.png"

# --- GRUB font (.pf2) -----------------------------------------------------
# GRUB needs its own font format; generate from DejaVu Bold
echo "  [GRUB] Generating font..."
grub-mkfont \
    -o "$GRUB_DIR/font.pf2" \
    -s 24 \
    "$FONT_SRC"
echo "  [GRUB] font.pf2 created (size 24, DejaVu Bold)"

# --- Plymouth logo --------------------------------------------------------
# Extract a centered square crop from the wallpaper for Plymouth
# Plymouth themes can use a PNG logo; we generate a square one.
echo "  [Plymouth] Generating logo..."
convert "$WALLPAPER" \
    -resize 512x512! \
    -gravity center \
    -crop 512x512+0+0 \
    "$PLYMOUTH_DIR/dob-logo.png"

# --- Plymouth progress indicator (simple pulse frames) ---
# Generate 12 frames of a subtle pulsing red circle
echo "  [Plymouth] Generating progress frames..."
for i in $(seq 1 12); do
    # Animate opacity to create a pulsing effect
    OPACITY=$(echo "scale=2; 0.3 + 0.7 * (s(3.14159 * $i / 12) * s(3.14159 * $i / 12))" | bc -l 2>/dev/null || echo "0.5")
    convert -size 64x64 xc:transparent \
        -fill "rgba(200,50,50,${OPACITY})" \
        -draw "circle 32,32 32,6" \
        "$PLYMOUTH_DIR/progress-$(printf '%02d' $i).png"
done
echo "  [Plymouth] 12 progress frames generated"

echo "==> All brand assets generated."
echo "    GRUB:      $GRUB_DIR/background.png + font.pf2"
echo "    Plymouth:  $PLYMOUTH_DIR/dob-logo.png + progress frames"
