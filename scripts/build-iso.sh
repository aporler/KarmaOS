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
sudo mount --bind /run "${CHROOT_DIR}/run" || true
# Ensure chroot has a real resolv.conf (avoid symlinks resolving to host)
sudo rm -f "${CHROOT_DIR}/etc/resolv.conf"
sudo cp /etc/resolv.conf "${CHROOT_DIR}/etc/resolv.conf"

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

sudo chroot "${CHROOT_DIR}" /bin/bash -euxo pipefail -c '
export DEBIAN_FRONTEND=noninteractive

echo "==> Initial apt update"
apt-get update

# Install kernel and essential packages first
apt-get install -y --no-install-recommends \
    linux-image-generic \
    linux-firmware \
    casper \
    discover \
    laptop-detect \
    os-prober

# Optional: meta package name differs across releases
if apt-cache show linux-modules-extra-generic >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends linux-modules-extra-generic
fi

# Optional: present on some older releases, not on Ubuntu 24.04
if apt-cache show lupin-casper >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends lupin-casper
fi

# Force initramfs regen to ensure casper hooks are present
update-initramfs -u || true

# Install bootloader packages
apt-get install -y --no-install-recommends \
    grub-common \
    grub2-common \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-amd64-signed \
    shim-signed

# Install desktop environment
apt-get install -y --no-install-recommends \
    kde-plasma-desktop \
    plasma-nm \
    plasma-pa \
    sddm \
    sddm-theme-breeze

# Install applications
apt-get install -y --no-install-recommends \
    firefox \
    konsole \
    dolphin \
    kate \
    gwenview \
    okular \
    libreoffice \
    vlc

# Install utilities
apt-get install -y --no-install-recommends \
    network-manager \
    netplan.io \
    networkd-dispatcher \
    wpasupplicant \
    rfkill \
    wireless-tools \
    pciutils \
    usbutils \
    policykit-1 \
    polkit-kde-agent-1 \
    modemmanager \
    iputils-ping \
    dnsutils \
    isc-dhcp-client \
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

# Installer (Calamares)
apt-get install -y --no-install-recommends calamares

# KarmaOS-Welcome runtime deps
apt-get install -y --no-install-recommends \
    python3 \
    python3-gi \
    python3-gi-cairo \
    gir1.2-gtk-3.0 \
    gir1.2-vte-2.91 \
    x11-xkb-utils

# WebKit for web view (try modern version first, fallback to older if needed)
apt-get install -y --no-install-recommends gir1.2-webkit-6.0 || \
apt-get install -y --no-install-recommends gir1.2-webkit2-4.1 || \
echo "Warning: WebKit GTK not available, web page will not work"

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

# Create standard Ubuntu live user/group expected by casper/live scripts
if ! getent group ubuntu >/dev/null 2>&1; then
    groupadd ubuntu
fi
if ! id ubuntu >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g ubuntu -G sudo,adm,cdrom,audio,video,plugdev ubuntu
fi

# Passwordless sudo (typical for live sessions)
rm -f /etc/sudoers.d/karmaos 2>/dev/null || true
cat > /etc/sudoers.d/ubuntu <<SUDOERS
ubuntu ALL=(ALL) NOPASSWD:ALL
SUDOERS
chmod 0440 /etc/sudoers.d/ubuntu

# Enable autologin for live session (SDDM) using Plasma X11 session
cat > /etc/sddm.conf.d/autologin.conf <<AUTOLOGIN
[Autologin]
User=ubuntu
Session=plasma.desktop

[General]
DisplayServer=x11
WaylandEnable=false
AUTOLOGIN

# Enable services for live boot
systemctl enable sddm NetworkManager
'

echo "==> Installing KarmaOS branding + tools into chroot..."

# Ensure NetworkManager manages interfaces (netplan)
sudo install -d "${CHROOT_DIR}/etc/netplan"
sudo tee "${CHROOT_DIR}/etc/netplan/01-network-manager-all.yaml" > /dev/null <<'EOF'
network:
    version: 2
    renderer: NetworkManager
EOF

# Branding assets
sudo install -d "${CHROOT_DIR}/usr/share/karmaos"
sudo install -m 0644 "$(pwd)/images/KarmaOSBack.png" "${CHROOT_DIR}/usr/share/karmaos/KarmaOSBack.png"
sudo install -m 0644 "$(pwd)/images/KarmaOSLogoPixel.png" "${CHROOT_DIR}/usr/share/karmaos/KarmaOSLogoPixel.png"

# KarmaOS Welcome
sudo install -d "${CHROOT_DIR}/usr/local/lib/karmaos-welcome"
sudo install -m 0755 "$(pwd)/snaps/karmaos-welcome/src/karmaos-welcome-gui.py" "${CHROOT_DIR}/usr/local/lib/karmaos-welcome/karmaos-welcome-gui.py"
sudo tee "${CHROOT_DIR}/usr/local/bin/karmaos-welcome" > /dev/null <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/env python3 /usr/local/lib/karmaos-welcome/karmaos-welcome-gui.py
EOF
sudo chmod +x "${CHROOT_DIR}/usr/local/bin/karmaos-welcome"

# Autostart: apply wallpaper + open KarmaOS-Welcome
sudo install -d "${CHROOT_DIR}/usr/local/bin"
sudo tee "${CHROOT_DIR}/usr/local/bin/karmaos-apply-branding" > /dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Wait for PlasmaShell
for _ in $(seq 1 30); do
    if qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.version >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Set wallpaper to KarmaOSBack.png
qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
var allDesktops = desktops();
for (i=0; i<allDesktops.length; i++) {
    d = allDesktops[i];
    d.wallpaperPlugin = 'org.kde.image';
    d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
    d.writeConfig('Image', 'file:///usr/share/karmaos/KarmaOSBack.png');
}
" || true
EOF
sudo chmod +x "${CHROOT_DIR}/usr/local/bin/karmaos-apply-branding"

sudo install -d "${CHROOT_DIR}/etc/xdg/autostart"
sudo tee "${CHROOT_DIR}/etc/xdg/autostart/karmaos-branding.desktop" > /dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=KarmaOS Branding
Exec=/usr/local/bin/karmaos-apply-branding
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

sudo tee "${CHROOT_DIR}/etc/xdg/autostart/karmaos-welcome.desktop" > /dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=KarmaOS Welcome
Exec=/usr/local/bin/karmaos-welcome
X-GNOME-Autostart-enabled=true
NoDisplay=false
EOF

# Desktop shortcut: installer
sudo install -d "${CHROOT_DIR}/home/ubuntu/Desktop"

# Polkit rule: allow members of sudo group to run Calamares without password
sudo install -d "${CHROOT_DIR}/etc/polkit-1/rules.d"
sudo tee "${CHROOT_DIR}/etc/polkit-1/rules.d/49-nopasswd-calamares.rules" > /dev/null <<'EOF'
/* Allow live user (in sudo group) to run Calamares without authentication */
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.policykit.exec" ||
         action.id.indexOf("com.github.calamares") === 0) &&
        subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
EOF
sudo chmod 0644 "${CHROOT_DIR}/etc/polkit-1/rules.d/49-nopasswd-calamares.rules"

# Wrapper that launches installer with privileges (direct sudo, no pkexec)
sudo tee "${CHROOT_DIR}/usr/local/bin/karmaos-installer" > /dev/null <<'EOF'
#!/usr/bin/env bash
set -e

# In the live session, user 'ubuntu' has passwordless sudo.
exec sudo -E calamares
EOF
sudo chmod +x "${CHROOT_DIR}/usr/local/bin/karmaos-installer"

sudo tee "${CHROOT_DIR}/home/ubuntu/Desktop/Install KarmaOS.desktop" > /dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=Install KarmaOS
Comment=Install KarmaOS on your computer
Exec=/usr/local/bin/karmaos-installer
Icon=system-software-install
Terminal=false
Categories=System;
EOF
sudo chmod +x "${CHROOT_DIR}/home/ubuntu/Desktop/Install KarmaOS.desktop"

# Remove any stray installer launchers that might appear as "Install Debian"
sudo rm -f \
    "${CHROOT_DIR}/home/ubuntu/Desktop/Install Debian.desktop" \
    "${CHROOT_DIR}/home/ubuntu/Desktop/Install%20Debian.desktop" \
    "${CHROOT_DIR}/usr/share/applications/install-debian.desktop" \
    "${CHROOT_DIR}/usr/share/applications/debian-installer.desktop" || true
sudo chown -R 1000:1000 "${CHROOT_DIR}/home/ubuntu" || true

# Basic distro branding
sudo tee "${CHROOT_DIR}/etc/os-release" > /dev/null <<EOF
NAME="KarmaOS"
PRETTY_NAME="KarmaOS ${VERSION}"
ID=karmaos
ID_LIKE=ubuntu
VERSION_ID="${VERSION}"
VERSION="${VERSION}"
HOME_URL="https://github.com/aporler/KarmaOS"
SUPPORT_URL="https://github.com/aporler/KarmaOS/issues"
BUG_REPORT_URL="https://github.com/aporler/KarmaOS/issues"
EOF

echo "==> Configuring Calamares..."
sudo install -d "${CHROOT_DIR}/etc/calamares" "${CHROOT_DIR}/etc/calamares/modules" "${CHROOT_DIR}/etc/calamares/branding/karmaos"

# Minimal Calamares settings to avoid 'refusing to continue startup without settings'
sudo tee "${CHROOT_DIR}/etc/calamares/settings.conf" > /dev/null <<'EOF'
modules-search: [ local ]

sequence:
  - show:
      - welcome
      - locale
      - keyboard
      - partition
      - users
      - summary
  - exec:
      - partition
      - mount
      - unpackfs
      - users
      - keyboard
      - locale
      - localecfg
      - grubcfg
      - bootloader
      - umount
  - show:
      - finished

branding: "karmaos"
prompt-install: false
dont-chroot: false
EOF

# Unpack filesystem from the live media (casper squashfs)
sudo tee "${CHROOT_DIR}/etc/calamares/modules/unpackfs.conf" > /dev/null <<'EOF'
---
unpack:
  - source: "/cdrom/casper/filesystem.squashfs"
    sourcefs: "squashfs"
    destination: ""
EOF

# Users module - create user account
sudo tee "${CHROOT_DIR}/etc/calamares/modules/users.conf" > /dev/null <<'EOF'
---
defaultGroups:
  - sudo
  - adm
  - cdrom
  - audio
  - video
  - plugdev
  - users
autologinGroup: autologin
sudoersGroup: sudo
setRootPassword: false
doAutologin: false
EOF

# Partition module
sudo tee "${CHROOT_DIR}/etc/calamares/modules/partition.conf" > /dev/null <<'EOF'
---
efiSystemPartition: "/boot/efi"
userSwapChoices:
  - none
  - small
  - suspend
  - file
initialPartitioningChoice: none
drawNestedPartitions: false
alwaysShowPartitionLabels: true
enableLuksAutomatedPartitioning: true
allowManualPartitioning: true
EOF

# Mount module
sudo tee "${CHROOT_DIR}/etc/calamares/modules/mount.conf" > /dev/null <<'EOF'
---
extraMounts:
  - device: proc
    fs: proc
    mountPoint: /proc
  - device: sys
    fs: sysfs
    mountPoint: /sys
  - device: /dev
    mountPoint: /dev
    options: bind
  - device: tmpfs
    fs: tmpfs
    mountPoint: /run
  - device: /run/udev
    mountPoint: /run/udev
    options: bind
EOF

# Bootloader module
sudo tee "${CHROOT_DIR}/etc/calamares/modules/bootloader.conf" > /dev/null <<'EOF'
---
efiBootLoader: "grub"
kernel: "/vmlinuz"
img: "/initrd.img"
timeout: "10"
grubInstall: "grub-install"
grubMkconfig: "grub-mkconfig"
grubCfg: "/boot/grub/grub.cfg"
efiBootloaderId: "KarmaOS"
EOF

# Locale module
sudo tee "${CHROOT_DIR}/etc/calamares/modules/locale.conf" > /dev/null <<'EOF'
---
region: "America"
zone: "Montreal"
localeGenPath: "/etc/locale.gen"
EOF

# Keyboard module
sudo tee "${CHROOT_DIR}/etc/calamares/modules/keyboard.conf" > /dev/null <<'EOF'
---
xOrgConfFileName: "/etc/X11/xorg.conf.d/00-keyboard.conf"
convertedKeymapPath: "/lib/kbd/keymaps/xkb"
EOF

# Welcome module
sudo tee "${CHROOT_DIR}/etc/calamares/modules/welcome.conf" > /dev/null <<'EOF'
---
showSupportUrl: true
showKnownIssuesUrl: false
showReleaseNotesUrl: false
requirements:
  requiredStorage: 10.0
  requiredRam: 1.0
  internetCheckUrl: http://google.com
  check:
    - storage
    - ram
    - power
    - internet
    - root
  required:
    - storage
    - ram
    - root
EOF

# Summary module
sudo tee "${CHROOT_DIR}/etc/calamares/modules/summary.conf" > /dev/null <<'EOF'
---
EOF

# Hide reboot checkbox/button on the finish page (avoid "Finish & Reboot")
sudo tee "${CHROOT_DIR}/etc/calamares/modules/finished.conf" > /dev/null <<'EOF'
---
restartNowEnabled: false
restartNowChecked: false
restartNowCommand: "systemctl reboot"
EOF

# Complete Calamares branding
sudo tee "${CHROOT_DIR}/etc/calamares/branding/karmaos/branding.desc" > /dev/null <<EOF
---
componentName: karmaos

strings:
  productName: "KarmaOS ${VERSION}"
  shortProductName: "KarmaOS"
  version: "${VERSION}"
  shortVersion: "${VERSION}"
  versionedName: "KarmaOS ${VERSION}"
  shortVersionedName: "KarmaOS ${VERSION}"
  bootloaderEntryName: "KarmaOS"
  productUrl: "https://github.com/aporler/KarmaOS"
  supportUrl: "https://github.com/aporler/KarmaOS/issues"
  knownIssuesUrl: "https://github.com/aporler/KarmaOS/issues"
  releaseNotesUrl: "https://github.com/aporler/KarmaOS/releases"

images:
  productLogo: "/usr/share/karmaos/KarmaOSLogoPixel.png"
  productIcon: "/usr/share/karmaos/KarmaOSLogoPixel.png"
  productWelcome: "/usr/share/karmaos/KarmaOSBack.png"

slideshow: ""

style:
  sidebarBackground: "#2c3e50"
  sidebarText: "#ffffff"
  sidebarTextSelect: "#4d4d4d"
EOF

# Clean up apt cache and tmp outside chroot
sudo chroot "${CHROOT_DIR}" apt-get clean
sudo rm -rf "${CHROOT_DIR}/var/lib/apt/lists/"*
sudo rm -rf "${CHROOT_DIR}/tmp"/*

# Unmount chroot filesystems
sudo umount "${CHROOT_DIR}/sys" || true
sudo umount "${CHROOT_DIR}/proc" || true
sudo umount "${CHROOT_DIR}/dev/pts" || true
sudo umount "${CHROOT_DIR}/dev" || true
sudo umount "${CHROOT_DIR}/run" || true

# ============================================
# STEP 4: Create ISO structure
# ============================================
echo "==> Creating ISO directory structure..."

mkdir -p "${ISO_DIR}"/{casper,isolinux,boot/grub}

# Generate manifest files expected by casper
sudo chroot "${CHROOT_DIR}" dpkg-query -W --showformat='${Package} ${Version}\n' \
    | sudo tee "${ISO_DIR}/casper/filesystem.manifest" > /dev/null
sudo cp "${ISO_DIR}/casper/filesystem.manifest" "${ISO_DIR}/casper/filesystem.manifest-desktop"

# Create squashfs filesystem
echo "==> Creating squashfs (this takes 5-10 minutes)..."
sudo mksquashfs "${CHROOT_DIR}" "${ISO_DIR}/casper/filesystem.squashfs" \
    -comp xz -Xbcj x86 -b 1M -no-duplicates

# Calculate filesystem size
printf $(sudo du -sx --block-size=1 "${CHROOT_DIR}" | cut -f1) | sudo tee "${ISO_DIR}/casper/filesystem.size" > /dev/null

KERNEL=$(find "${CHROOT_DIR}/boot" -maxdepth 1 -type f -name "vmlinuz-*" | sort | tail -n1)
INITRD=$(find "${CHROOT_DIR}/boot" -maxdepth 1 -type f -name "initrd.img-*" | sort | tail -n1)

if [[ -z "${KERNEL}" || -z "${INITRD}" ]]; then
    echo "ERROR: Kernel or initrd not found in chroot /boot"
    sudo ls -lah "${CHROOT_DIR}/boot" || true
    exit 1
fi

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
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std

LABEL live
    MENU LABEL Start KarmaOS ${VERSION} (Live)
    KERNEL /casper/vmlinuz
    APPEND initrd=/casper/initrd boot=casper quiet splash ---

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
mkdir -p "${ISO_DIR}/EFI/BOOT" "${ISO_DIR}/EFI/ubuntu"

# Create FAT image for EFI
dd if=/dev/zero of="${ISO_DIR}/boot/grub/efi.img" bs=1M count=10
mkfs.vfat "${ISO_DIR}/boot/grub/efi.img"

# Mount and setup EFI image
MOUNT_EFI=$(mktemp -d)
sudo mount "${ISO_DIR}/boot/grub/efi.img" "${MOUNT_EFI}"
sudo mkdir -p "${MOUNT_EFI}/EFI/BOOT" "${MOUNT_EFI}/EFI/ubuntu"

# Copy EFI bootloader
if [ -f /usr/lib/shim/shimx64.efi.signed ]; then
    sudo cp /usr/lib/shim/shimx64.efi.signed "${MOUNT_EFI}/EFI/BOOT/BOOTX64.EFI"
    sudo cp /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed "${MOUNT_EFI}/EFI/BOOT/GRUBX64.EFI"
else
    # Fallback: create GRUB EFI directly
    sudo grub-mkimage -o "${MOUNT_EFI}/EFI/BOOT/BOOTX64.EFI" \
        -p /EFI/BOOT -O x86_64-efi \
        fat iso9660 part_gpt part_msdos normal boot linux loopback chain \
        efifwsetup efi_gop efi_uga ls search search_label search_fs_uuid \
        search_fs_file gfxterm gfxterm_background gfxterm_menu test all_video \
        loadenv exfat ext2 ntfs btrfs hfsplus udf
fi

# Copy GRUB config to EFI
sudo mkdir -p "${MOUNT_EFI}/boot/grub"
sudo cp "${ISO_DIR}/boot/grub/grub.cfg" "${MOUNT_EFI}/boot/grub/"

# Also place grub.cfg at common UEFI locations
sudo cp "${ISO_DIR}/boot/grub/grub.cfg" "${MOUNT_EFI}/EFI/BOOT/grub.cfg"
sudo cp "${ISO_DIR}/boot/grub/grub.cfg" "${MOUNT_EFI}/EFI/ubuntu/grub.cfg"

sudo umount "${MOUNT_EFI}"
rmdir "${MOUNT_EFI}"

# Also copy to EFI/boot for direct boot
sudo cp /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed "${ISO_DIR}/EFI/BOOT/GRUBX64.EFI" 2>/dev/null || true
if [ -f /usr/lib/shim/shimx64.efi.signed ]; then
    sudo cp /usr/lib/shim/shimx64.efi.signed "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI"
fi

# Also provide grub.cfg at EFI/boot for some UEFI implementations
sudo mkdir -p "${ISO_DIR}/EFI/BOOT" "${ISO_DIR}/EFI/ubuntu"
sudo cp "${ISO_DIR}/boot/grub/grub.cfg" "${ISO_DIR}/EFI/BOOT/grub.cfg" || true
sudo cp "${ISO_DIR}/boot/grub/grub.cfg" "${ISO_DIR}/EFI/ubuntu/grub.cfg" || true

# ============================================
# STEP 7: Create bootable ISO
# ============================================
echo "==> Creating bootable hybrid ISO..."

FINAL_ISO="${OUTPUT_DIR}/karmaos-${VERSION}-${ARCH}.iso"

echo "==> Fixing ISO tree permissions for xorriso..."
sudo chown -R "$(id -u):$(id -g)" "${ISO_DIR}"
sudo chmod -R a+rX "${ISO_DIR}"

VOLID="KARMAOS_${VERSION//./_}"

xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "${VOLID}" \
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
