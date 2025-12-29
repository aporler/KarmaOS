#!/usr/bin/env bash
set -euo pipefail

MARKETING_VERSION="26.01"
ARCH="amd64"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODEL_JSON="$ROOT_DIR/models/karmaos-core24-amd64.json"
MODEL_ASSERTION="$ROOT_DIR/models/karmaos-core24-amd64.model"

OUT_DIR="$ROOT_DIR/out"
DIST_DIR="$ROOT_DIR/dist"
FINAL_IMG="$DIST_DIR/karmaos-${MARKETING_VERSION}-${ARCH}.img"

mkdir -p "$DIST_DIR" "$OUT_DIR"

require_cmd() {
  local c="$1"
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "ERROR: Missing command: $c" >&2
    exit 10
  fi
}

require_cmd sha256sum
require_cmd find

# Vérif modèle signé (doit passer AVANT de checker ubuntu-image)
if [[ ! -f "$MODEL_ASSERTION" ]]; then
  cat <<EOF2 >&2
ERROR: Missing signed model assertion:
  $MODEL_ASSERTION

TODO : signer le modèle dans une VM Ubuntu puis committer le fichier .model

Ce build nécessite un fichier de model assertion signé (.model).
Le CI GitHub Actions ne signe pas le modèle pour cette alpha.

Template non signé présent ici:
  $MODEL_JSON

Exemple (dans une VM Ubuntu):
  snap create-key karmaos
  snap sign -k karmaos models/karmaos-core24-amd64.json > models/karmaos-core24-amd64.model
EOF2
  exit 2
fi

require_cmd ubuntu-image

SUDO=""
if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

# Nettoyage artefacts
rm -f "$FINAL_IMG" "$DIST_DIR/SHA256SUMS" || true
rm -f "$OUT_DIR"/*.img || true

echo "==> Build KarmaOS ${MARKETING_VERSION} (Ubuntu Core ${ARCH}) image"
echo "    Model: $MODEL_ASSERTION"

$SUDO ubuntu-image snap "$MODEL_ASSERTION" --output-dir "$OUT_DIR"

IMG_PATH="$(find "$OUT_DIR" -maxdepth 3 -type f -name '*.img' | head -n 1 || true)"
if [[ -z "$IMG_PATH" ]]; then
  echo "ERROR: ubuntu-image did not produce any .img file under: $OUT_DIR" >&2
  echo "Contents of $OUT_DIR:" >&2
  (ls -la "$OUT_DIR" || true) >&2
  exit 3
fi

cp -f "$IMG_PATH" "$FINAL_IMG"

(
  cd "$DIST_DIR"
  sha256sum "$(basename "$FINAL_IMG")" > SHA256SUMS
)

echo "==> Done"
echo "    Image: $FINAL_IMG"
echo "    Checksums: $DIST_DIR/SHA256SUMS"
