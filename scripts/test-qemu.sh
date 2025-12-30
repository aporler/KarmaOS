#!/usr/bin/env bash
# Script pour tester KarmaOS dans QEMU sur macOS

set -euo pipefail

IMG_FILE="${1:-dist/karmaos-26.01-amd64.img}"

if [[ ! -f "$IMG_FILE" ]]; then
  echo "Erreur: Image non trouvée: $IMG_FILE"
  echo "Usage: $0 [path/to/karmaos.img]"
  exit 1
fi

echo "==> Démarrage de KarmaOS dans QEMU..."
echo "    Image: $IMG_FILE"
echo ""
echo "Conseils:"
echo "  - Connexion réseau: dhcp automatique"
echo "  - Console: login après boot avec le compte créé"
echo "  - Sortir: Ctrl+Alt+G pour libérer la souris, Ctrl+C dans terminal pour quitter"
echo ""
echo "NOTE: Sur Apple Silicon, l'émulation x86_64 sera lente (pas d'accélération)."
echo ""

# Détecte l'architecture pour ajuster l'accélération
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  # Apple Silicon - pas d'accélération HVF pour x86_64
  ACCEL_OPT="-accel tcg"
else
  # Intel Mac - utilise HVF
  ACCEL_OPT="-machine type=q35,accel=hvf"
fi

qemu-system-x86_64 \
  $ACCEL_OPT \
  -cpu qemu64 \
  -smp 2 \
  -m 4G \
  -drive file="$IMG_FILE",format=raw,if=virtio \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -vga virtio \
  -display cocoa \
  -boot c
