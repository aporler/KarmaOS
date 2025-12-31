#!/usr/bin/env bash
# KarmaOS 26.01 ISO Builder
# Creates a BOOTABLE hybrid ISO (UEFI + BIOS) for VirtualBox, QEMU, UTM, real hardware

set -euo pipefail

VERSION="26.01"
CODENAME="noble"
ARCH="amd64"

BUILD_DIR="$(pwd)/build"
OUTPUT_DIR="$(pwd)/dist"
CHROOT_DIR="${BUILD_DIR}/chroot"
ISO_DIR="${BUILD_DIR}/iso"

echo "=============================================="
echo "  KarmaOS ${VERSION} ISO Builder"
echo "  Base: Ubuntu ${CODENAME} (24.04 LTS)"
echo "  Architecture: ${ARCH}"
echo "=============================================="

# Install dependencies
echo "==> Installing build dependencies..."
sudo apt-get update
sudo apt-get install -y \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-utils \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-amd64-signed \
    shim-signed \
    mtools \
    dosfstools

# Clean previous builds
echo "==> Cleaning previous builds..."
sudo rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}" "${CHROOT_DIR}" "${ISO_DIR}"

# ============================================
# STEP 1: Bootstrap Ubuntu base system
# ============================================
echo "==> Bootstrapping Ubuntu ${CODENAME} base system..."
sudo debootstrap --arch=${ARCH} ${CODENAME} "${CHROOT_DIR}" http://archive.ubuntu.com/ubuntu

# ============================================
# STEP 2: Configure chroot
# ============================================
echo "==> Configuring chroot environment..."

# Mount necessary filesystems
sudo mount --bind /dev "${CHROOT_DIR}/dev"
sudo mount --bind /dev/pts "${CHROOT_DIR}/dev/pts"
sudo mount --bind /proc "${CHROOT_DIR}/proc"
sudo mount --bind /sys "${CHROOT_DIR}/sys"

# Configure APT sources
sudo tee "${CHROOT_DIR}/etc/apt/sources.list" > /dev/null <<EOF
deb http://archive.ubuntu.com/ubuntu ${CODENAME} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu ${CODENAME}-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu ${CODENAME}-security main restricted universe multiverse
EOF

# Set hostname
echo "karmaos" | sudo tee "${CHROOT_DIR}/etc/hostname" > /dev/null

# Configure hosts
sudo tee "${CHROOT_DIR}/etc/hosts" > /dev/null <<EOF
127.0.0.1   localhost
127.0.1.1   karmaos

::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# ============================================
# STEP 3: Install packages in chroot
# ============================================
echo "==> Installing packages (this takes 10-20 minutes)..."

sudo chroot "${CHROOT_DIR}" /bin/bash -c "
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Install kernel and essential packages first
apt-get install -y \
    linux-image-generic \
    linux-headers-generic \
    linux-firmware \
    casper \
    lupin-casper \
    discover \
    laptop-detect \
    os-prober

# Install bootloader packages
apt-get install -y \
    grub-common \
    grub2-common \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-amd64-signed \
    shim-signed

# Install desktop environment
apt-get install -y \
    kde-plasma-desktop \
    plasma-nm \
    plasma-pa \
    sddm \
    sddm-theme-breeze

# Install applications
apt-get install -y \
    firefox \
    konsole \
    dolphin \
    kate \
    gwenview \
    okular \
    libreoffice \
    vlc

# Install utilities
apt-get install -y \
    network-manager \
    wpasupplicant \
    systemsettings \
    partitionmanager \
    vim \
    wget \
    curl \
    git \
    htop \
    pulseaudio \
    fonts-noto \
    fonts-liberation \
    sudo \
    locales

# Generate locales
locale-gen en_US.UTF-8

# Configure SDDM
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/karmaos.conf <<SDDM
[Theme]
Current=breeze

[Users]
MaximumUid=60000
MinimumUid=1000
SDDM

# Create live user for the live session
useradd -m -s /bin/bash -G sudo,adm,cdrom,audio,video,plugdev karmaos || true
echo 'karmaos:karmaos' | chpasswd
echo 'karmaos ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/karmaos

# Enable autologin for live session
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf <<AUTOLOGIN
[Autologin]
User=karmaos
Session=plasma
AUTOLOGIN

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*
"

# Unmount chroot filesystems
sudo umount "${CHROOT_DIR}/sys" || true
sudo umount "${CHROOT_DIR}/proc" || true
sudo umount "${CHROOT_DIR}/dev/pts" || true
sudo umount "${CHROOT_DIR}/dev" || true

# ============================================
# STEP 4: Create ISO structure
# ============================================
echo "==> Creating ISO directory structure..."

mkdir -p "${ISO_DIR}"/{casper,isolinux,boot/grub}

# Create squashfs filesystem
echo "==> Creating squashfs (this takes 5-10 minutes)..."
sudo mksquashfs "${CHROOT_DIR}" "${ISO_DIR}/casper/filesystem.squashfs" \
    -comp xz -Xbcj x86 -b 1M -no-duplicates

# Calculate filesystem size
printf $(sudo du -sx --block-size=1 "${CHROOT_DIR}" | cut -f1) | sudo tee "${ISO_DIR}/casper/filesystem.size" > /dev/null

# Copy kernel and initrd
KERNEL=$(ls "${CHROOT_DIR}"/boot/vmlinuz-* | head -1)
INITRD=$(ls "${CHROOT_DIR}"/boot/initrd.img-* | head -1)

sudo cp "${KERNEL}" "${ISO_DIR}/casper/vmlinuz"
sudo cp "${INITRD}" "${ISO_DIR}/casper/initrd"

# ============================================
# STEP 5: Configure ISOLINUX (BIOS boot)
# ============================================
echo "==> Configuring ISOLINUX for BIOS boot..."

# Copy ISOLINUX files
sudo cp /usr/lib/ISOLINUX/isolinux.bin "${ISO_DIR}/isolinux/"
sudo cp /usr/lib/syslinux/modules/bios/*.c32 "${ISO_DIR}/isolinux/"

# Create ISOLINUX config
sudo tee "${ISO_DIR}/isolinux/isolinux.cfg" > /dev/null <<EOF
UI vesamenu.c32
TIMEOUT 50
PROMPT 0
DEFAULT live

MENU TITLE KarmaOS ${VERSION} Boot Menu
MENU BACKGROUND #003366
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std

LABEL live
    MENU LABEL Start KarmaOS ${VERSION} (Live)
    KERNEL /casper/vmlinuz
    APPEND initrd=/casper/initrd boot=casper quiet splash ---

LABEL live-safe
    MENU LABEL Start KarmaOS (Safe Mode)
    KERNEL /casper/vmlinuz
    APPEND initrd=/casper/initrd boot=casper xforcevesa nomodeset quiet splash ---

LABEL memtest
    MENU LABEL Memory Test
    KERNEL /isolinux/memtest

LABEL hd
    MENU LABEL Boot from Hard Disk
    LOCALBOOT 0x80
EOF

# ============================================
# STEP 6: Configure GRUB (UEFI boot)
# ============================================
echo "==> Configuring GRUB for UEFI boot..."

# Create GRUB config
sudo tee "${ISO_DIR}/boot/grub/grub.cfg" > /dev/null <<EOF
set timeout=5
set default=0

menuentry "Start KarmaOS ${VERSION}" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}

menuentry "Start KarmaOS (Safe Mode)" {
    linux /casper/vmlinuz boot=casper xforcevesa nomodeset quiet splash ---
    initrd /casper/initrd
}

menuentry "Boot from Hard Disk" {
    exit
}
EOF

# Create EFI boot image
echo "==> Creating EFI boot image..."
mkdir -p "${ISO_DIR}/EFI/boot"

# Create FAT image for EFI
dd if=/dev/zero of="${ISO_DIR}/boot/grub/efi.img" bs=1M count=10
mkfs.vfat "${ISO_DIR}/boot/grub/efi.img"

# Mount and setup EFI image
MOUNT_EFI=$(mktemp -d)
sudo mount "${ISO_DIR}/boot/grub/efi.img" "${MOUNT_EFI}"
sudo mkdir -p "${MOUNT_EFI}/EFI/boot"

# Copy EFI bootloader
if [ -f /usr/lib/shim/shimx64.efi.signed ]; then
    sudo cp /usr/lib/shim/shimx64.efi.signed "${MOUNT_EFI}/EFI/boot/bootx64.efi"
    sudo cp /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed "${MOUNT_EFI}/EFI/boot/grubx64.efi"
else
    # Fallback: create GRUB EFI directly
    sudo grub-mkimage -o "${MOUNT_EFI}/EFI/boot/bootx64.efi" \
        -p /boot/grub -O x86_64-efi \
        fat iso9660 part_gpt part_msdos normal boot linux loopback chain \
        efifwsetup efi_gop efi_uga ls search search_label search_fs_uuid \
        search_fs_file gfxterm gfxterm_background gfxterm_menu test all_video \
        loadenv exfat ext2 ntfs btrfs hfsplus udf
fi

# Copy GRUB config to EFI
sudo mkdir -p "${MOUNT_EFI}/boot/grub"
sudo cp "${ISO_DIR}/boot/grub/grub.cfg" "${MOUNT_EFI}/boot/grub/"

sudo umount "${MOUNT_EFI}"
rmdir "${MOUNT_EFI}"

# Also copy to EFI/boot for direct boot
sudo cp /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed "${ISO_DIR}/EFI/boot/grubx64.efi" 2>/dev/null || true
if [ -f /usr/lib/shim/shimx64.efi.signed ]; then
    sudo cp /usr/lib/shim/shimx64.efi.signed "${ISO_DIR}/EFI/boot/bootx64.efi"
fi

# ============================================
# STEP 7: Create bootable ISO
# ============================================
echo "==> Creating bootable hybrid ISO..."

FINAL_ISO="${OUTPUT_DIR}/karmaos-${VERSION}-${ARCH}.iso"

xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "KarmaOS_${VERSION}" \
    -output "${FINAL_ISO}" \
    -eltorito-boot isolinux/isolinux.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
    "${ISO_DIR}"

# ============================================
# STEP 8: Generate checksums and finish
# ============================================
echo "==> Generating checksums..."
cd "${OUTPUT_DIR}"
sha256sum "$(basename ${FINAL_ISO})" > SHA256SUMS

echo ""
echo "=============================================="
echo "  BUILD COMPLETE!"
echo "=============================================="
echo "  ISO: ${FINAL_ISO}"
echo "  Size: $(du -h ${FINAL_ISO} | cut -f1)"
echo ""
echo "  Boot compatibility:"
echo "    ✓ BIOS (Legacy) - VirtualBox, older PCs"
echo "    ✓ UEFI - Modern PCs, QEMU, UTM"
echo "    ✓ Hybrid - USB boot on any system"
echo "=============================================="
