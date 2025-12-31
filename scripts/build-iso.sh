#!/usr/bin/env bash
# KarmaOS 26.01 ISO Builder
# Builds a custom Ubuntu 24.04 LTS based ISO from scratch

set -euo pipefail

VERSION="26.01"
CODENAME="noble"
ARCH="amd64"

BUILD_DIR="$(pwd)/build"
OUTPUT_DIR="$(pwd)/dist"

echo "==> KarmaOS ${VERSION} ISO Builder"
echo "    Base: Ubuntu ${CODENAME} (24.04 LTS)"
echo "    Architecture: ${ARCH}"

# Install live-build if needed
if ! command -v lb &> /dev/null; then
    echo "==> Installing live-build..."
    sudo apt-get update
    sudo apt-get install -y live-build debootstrap
fi

# Clean previous builds
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"
cd "${BUILD_DIR}"

echo "==> Configuring live-build..."

lb config \
    --distribution "${CODENAME}" \
    --archive-areas "main restricted universe multiverse" \
    --linux-flavours generic \
    --architectures "${ARCH}" \
    --bootappend-live "boot=live quiet splash" \
    --debian-installer false \
    --iso-application "KarmaOS" \
    --iso-preparer "KarmaOS Team" \
    --iso-publisher "https://github.com/aporler/KarmaOS" \
    --iso-volume "KarmaOS ${VERSION}" \
    --memtest none \
    --binary-images iso-hybrid

# Force GRUB-EFI and disable syslinux
echo "LB_BOOTLOADER=\"grub-efi\"" >> config/binary
echo "LB_SYSLINUX_THEME=\"\"" >> config/binary

# Create package list
mkdir -p config/package-lists

# Disable syslinux (not available in Ubuntu 24.04)
mkdir -p config/binary_syslinux
echo "" > config/binary_syslinux/.empty

cat > config/package-lists/karmaos.list.chroot <<EOF
# KarmaOS Base System Packages

# Desktop Environment
kde-plasma-desktop
plasma-nm
plasma-pa
sddm
sddm-theme-breeze

# Core Applications
firefox
konsole
dolphin
kate
gwenview
okular

# Office Suite
libreoffice
libreoffice-plasma

# Network & Drivers
network-manager
wpasupplicant
linux-firmware

# System Tools
systemsettings
partitionmanager

# Utilities
vim
wget
curl
git
htop

# Fonts
fonts-noto
fonts-liberation

# Multimedia
pulseaudio
vlc
EOF

# Install hooks for customization
mkdir -p config/hooks/live
mkdir -p config/hooks/normal

# Disable syslinux installation
cat > config/hooks/normal/9999-disable-syslinux.hook.binary <<'HOOK'
#!/bin/bash
# Prevent syslinux installation errors
exit 0
HOOK

chmod +x config/hooks/normal/9999-disable-syslinux.hook.binary

cat > config/hooks/live/0010-karmaos-branding.hook.chroot <<'HOOK'
#!/bin/bash
# KarmaOS Branding and Configuration

set -e

echo "==> Applying KarmaOS branding..."

# Set hostname
echo "karmaos" > /etc/hostname

# Configure SDDM
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/karmaos.conf <<EOF
[Theme]
Current=breeze

[Users]
MaximumUid=60000
MinimumUid=1000
EOF

# Disable unnecessary services
systemctl disable apt-daily.timer || true
systemctl disable apt-daily-upgrade.timer || true

echo "==> KarmaOS branding applied"
HOOK

chmod +x config/hooks/live/0010-karmaos-branding.hook.chroot

echo "==> Building ISO (this may take 15-30 minutes)..."
sudo lb build || {
    # If build fails on isohybrid but ISO exists, continue
    if [ -f binary*.iso ]; then
        echo "WARNING: Build had errors but ISO was created"
    else
        echo "ERROR: Build failed and no ISO found"
        exit 1
    fi
}

# Move ISO to output directory
if [ -f *.iso ]; then
    ISO_FILE=$(ls *.iso | head -n 1)
    FINAL_ISO="${OUTPUT_DIR}/karmaos-${VERSION}-${ARCH}.iso"
    mv "${ISO_FILE}" "${FINAL_ISO}"
    
    # Generate checksum
    cd "${OUTPUT_DIR}"
    sha256sum "$(basename ${FINAL_ISO})" > SHA256SUMS
    
    echo "==> Build complete!"
    echo "    ISO: ${FINAL_ISO}"
    echo "    Size: $(du -h ${FINAL_ISO} | cut -f1)"
    echo "    SHA256: SHA256SUMS"
else
    echo "ERROR: ISO build failed - no .iso file found"
    exit 1
fi
