#!/usr/bin/env bash
# KarmaOS First Boot Setup
# Run this script after first login to install recommended apps

set -euo pipefail

echo "==> KarmaOS 26.01 - First Boot Setup"
echo ""
echo "This script will install the KDE Plasma desktop and essential applications:"
echo "  - Plasma Desktop (KDE desktop environment)"
echo "  - Plasma providers (gnome, mesa, gtk)"
echo "  - Brave Browser (recommended)"
echo "  - Snap Store (app installer GUI)"
echo "  - Firefox (alternative browser)"
echo ""
echo "NOTE: This will download ~2GB of packages."
echo ""
read -p "Continue? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "==> Installing Plasma Desktop..."
snap install plasma-desktop-session --channel=latest/edge || echo "Warning: plasma-desktop-session installation failed"

echo ""
echo "==> Installing GNOME 42 provider..."
snap install gnome-42-2204 || echo "Warning: gnome-42-2204 installation failed"

echo ""
echo "==> Installing Mesa GPU provider..."
snap install mesa-2404 || echo "Warning: mesa-2404 installation failed"

echo ""
echo "==> Installing GTK themes..."
snap install gtk-common-themes || echo "Warning: gtk-common-themes installation failed"

echo ""
echo "==> Installing Brave Browser..."
snap install brave || echo "Warning: brave installation failed"

echo ""
echo "==> Installing Snap Store..."
snap install snap-store || echo "Warning: snap-store installation failed"

echo ""
echo "==> Installing GNOME 46 provider..."
snap install gnome-46-2404 || echo "Warning: gnome-46-2404 installation failed"

echo ""
echo "==> Installing Firefox..."
snap install firefox || echo "Warning: firefox installation failed"

echo ""
echo "==> Setup complete!"
echo ""
echo "Optional apps you can install:"
echo "  snap install libreoffice"
echo "  snap install thunderbird"
echo "  snap install vlc"
echo "  snap install gimp"
echo "  snap install code  # VS Code"
echo ""
echo "Restart your desktop session for all changes to take effect."
