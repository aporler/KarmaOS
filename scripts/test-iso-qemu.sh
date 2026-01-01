#!/usr/bin/env bash
# KarmaOS ISO QEMU Test Script
# Tests the ISO in QEMU on macOS (Apple Silicon)

set -euo pipefail

ISO_PATH="${1:-dist/karmaos-26.01-amd64.iso}"
MEMORY="${2:-4G}"
CPUS="${3:-4}"

if [ ! -f "$ISO_PATH" ]; then
    echo "ERROR: ISO not found: $ISO_PATH"
    echo "Usage: $0 [iso-path] [memory] [cpus]"
    echo "Example: $0 dist/karmaos-26.01-amd64.iso 4G 4"
    exit 1
fi

echo "==> Testing KarmaOS ISO in QEMU"
echo "    ISO: $ISO_PATH"
echo "    Memory: $MEMORY"
echo "    CPUs: $CPUS"

# Check if QEMU is installed
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "ERROR: QEMU not found"
    echo "Install with: brew install qemu"
    exit 1
fi

# Create virtual disk (optional - for testing installation)
DISK_IMG="karmaos-test.qcow2"
if [ ! -f "$DISK_IMG" ]; then
    echo "==> Creating 20GB virtual disk: $DISK_IMG"
    qemu-img create -f qcow2 "$DISK_IMG" 20G
fi

echo "==> Booting KarmaOS ISO..."
echo "    Press Ctrl+Alt+G to release mouse"
echo "    Press Ctrl+Alt+F to toggle fullscreen"
echo ""

# Check if HVF is available
ACCEL_OPTS=""
if qemu-system-x86_64 -accel help 2>&1 | grep -q hvf; then
    echo "    Using HVF acceleration"
    ACCEL_OPTS="-accel hvf"
else
    echo "    WARNING: HVF not available, using slower TCG emulation"
fi

# Boot with UEFI (GRUB-EFI bootloader)
qemu-system-x86_64 \
    -M q35 \
    $ACCEL_OPTS \
    -cpu qemu64 \
    -smp cpus=$CPUS \
    -m $MEMORY \
    -drive if=pflash,format=raw,readonly=on,file=/opt/homebrew/share/qemu/edk2-x86_64-code.fd \
    -device VGA \
    -display cocoa \
    -device qemu-xhci \
    -device usb-kbd \
    -device usb-mouse \
    -netdev user,id=net0 \
    -device e1000,netdev=net0 \
    -drive file="$ISO_PATH",media=cdrom,format=raw \
    -drive file="$DISK_IMG",if=virtio,format=qcow2 \
    -boot d
