# KarmaOS 26.01 (alpha)

Alpha “KarmaOS 26.01” basée sur **Ubuntu Core 24** (`core24`), cible **PC amd64**, avec un desktop **KDE Plasma** et des apps préinstallées **via snaps uniquement** (pas d’APT).

- Modèle: `karmaos-pc-amd64` (le format avec des points, ex `com.karmaos.pc.amd64`, est rejeté par `snap sign`)
- Base: `core24`
- Desktop KDE: `plasma-desktop-session` (channel `latest/edge`)
- Apps: `brave`, `libreoffice`, `thunderbird`, `vlc`, `snap-store`

## Build

Sur macOS, on ne build pas l’image localement (outil + environnement Ubuntu requis). Le flux attendu est:

1. Vous modifiez le repo.
2. Vous poussez sur `main`.
3. GitHub Actions génère l’image et publie un artifact téléchargeable.

Le workflow utilise `ubuntu-image` (snap) et lance [scripts/build.sh](scripts/build.sh).

## Récupérer l’artifact

1. Allez dans l’onglet **Actions** du dépôt GitHub.
2. Ouvrez l’exécution du workflow **Build KarmaOS 26.01 alpha**.
3. Téléchargez l’artifact **karmaos-26.01-amd64**.
4. Vous y trouverez `dist/karmaos-26.01-amd64.img` et `dist/SHA256SUMS`.

## Regénérer le modèle signé (optionnel)

Le build nécessite un **model assertion signé**: `models/karmaos-core24-amd64.model`.

Le template non signé est ici: `models/karmaos-core24-amd64.json`.

Exemple (dans une VM Ubuntu):

- `snap create-key karmaos`
- Mettre à jour `authority-id`, `brand-id` et `timestamp` dans le JSON
- `snap sign -k karmaos models/karmaos-core24-amd64.json > models/karmaos-core24-amd64.model`

## Dépannage

- **Workflow rouge / échec sur “Build image”**: lire les logs de `scripts/build.sh`.
- **Artifact absent**: si le build échoue avant la génération de l’image, aucun artifact n’est upload.
- **Erreur ubuntu-image / aucune image produite**: vérifier le `.model` et les snaps/channels.
