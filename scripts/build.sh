#!/usr/bin/env bash
set -euo pipefail

MARKETING_VERSION="26.01"
ARCH="amd64"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODEL_JSON="$ROOT_DIR/models/karmaos-core24-amd64.json"
MODEL_ASSERTION="$ROOT_DIR/models/karmaos-core24-amd64.model"

# Optional CI signing:
# - Provide an exported snap signing key via KARMAOS_SNAP_EXPORT_KEY_B64 (base64 of `snap export-key <name>` output)
# - Optionally provide KARMAOS_SNAP_KEY_NAME (default: karmaos)
# If present, we generate a fresh signed model assertion with a current timestamp.
MODEL_TO_USE="$MODEL_ASSERTION"

OUT_DIR="$ROOT_DIR/out"
DIST_DIR="$ROOT_DIR/dist"
FINAL_IMG="$DIST_DIR/karmaos-${MARKETING_VERSION}-${ARCH}.img"

mkdir -p "$DIST_DIR" "$OUT_DIR"

CI_MODEL_ASSERTION="$OUT_DIR/karmaos-core24-amd64.ci.model"
export TMP_JSON="$OUT_DIR/karmaos-core24-amd64.ci.json"

require_cmd() {
  local c="$1"
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "ERROR: Missing command: $c" >&2
    exit 10
  fi
}

require_cmd sha256sum
require_cmd find

maybe_generate_signed_model() {
  if [[ -z "${KARMAOS_SNAP_EXPORT_KEY_B64:-}" ]]; then
    return 0
  fi

  require_cmd snap
  require_cmd base64
  require_cmd python3

  local key_name="${KARMAOS_SNAP_KEY_NAME:-karmaos}"
  local key_file="$OUT_DIR/${key_name}.snapkey"
  local tmp_json="$OUT_DIR/karmaos-core24-amd64.ci.json"

  echo "==> CI: importing snap signing key (${key_name}) and signing model"

  # Decode exported key material (from `snap export-key <name>`)
  printf '%s' "$KARMAOS_SNAP_EXPORT_KEY_B64" | base64 --decode > "$key_file"

  # Import key into snap's key store
  snap import-key "$key_file"

  # Stamp the model JSON with the current UTC time so it's always within key validity.
  python3 - <<'PY'
import datetime
import json
import os

src = os.environ["MODEL_JSON"]
dst = os.environ["TMP_JSON"]

with open(src, "r", encoding="utf-8") as f:
    data = json.load(f)

data["timestamp"] = datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"

with open(dst, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

  # Sign the assertion from JSON -> .model
  snap sign -k "$key_name" "$tmp_json" > "$CI_MODEL_ASSERTION"
  MODEL_TO_USE="$CI_MODEL_ASSERTION"
}

export MODEL_JSON

# Vérif modèle signé (doit passer AVANT de checker ubuntu-image)
maybe_generate_signed_model

if [[ ! -f "$MODEL_TO_USE" ]]; then
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
  # Important: le timestamp doit tre APRES la date de validit "since" de la cl.
  # (Sinon: "timestamp outside of signing key validity")
  # Astuce: mettez un timestamp rcent (UTC), puis signez.
  snap sign -k karmaos models/karmaos-core24-amd64.json > models/karmaos-core24-amd64.model

Option CI (recommand):
  - Ajouter un secret GitHub: KARMAOS_SNAP_EXPORT_KEY_B64 = base64(`snap export-key karmaos`)
  - Le script gnre alors un .model sign  la vole avec un timestamp courant.
EOF2
  exit 2
fi

require_cmd ubuntu-image

# Build custom gadget
GADGET_DIR="$ROOT_DIR/gadget"
GADGET_SNAP="$OUT_DIR/karmaos-pc_26.01_amd64.snap"

if [[ -d "$GADGET_DIR" ]]; then
  echo "==> Building custom KarmaOS gadget"
  (cd "$GADGET_DIR" && snapcraft pack --destructive-mode --output "$GADGET_SNAP")
fi

SUDO=""
if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

# Nettoyage artefacts
rm -f "$FINAL_IMG" "$DIST_DIR/SHA256SUMS" || true
rm -f "$OUT_DIR"/*.img || true

echo "==> Build KarmaOS ${MARKETING_VERSION} (Ubuntu Core ${ARCH}) image"
echo "    Model: $MODEL_TO_USE"

# Options pour ubuntu-image
UBUNTU_IMAGE_OPTS=("--output-dir" "$OUT_DIR")

# Ajouter le gadget local s'il existe
if [[ -f "$GADGET_SNAP" ]]; then
  echo "    Using custom gadget: $GADGET_SNAP"
  UBUNTU_IMAGE_OPTS+=("--snap" "$GADGET_SNAP")
fi

$SUDO ubuntu-image snap "$MODEL_TO_USE" "${UBUNTU_IMAGE_OPTS[@]}"

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
