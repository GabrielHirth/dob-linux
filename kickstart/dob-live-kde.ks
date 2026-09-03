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
