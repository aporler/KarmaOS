# KarmaOS 26.01 (alpha)

Alpha “KarmaOS 26.01” basée sur **Ubuntu Core 24** (`core24`), cible **PC amd64**, avec un desktop **KDE Plasma** et des apps préinstallées **via snaps uniquement** (pas d’APT).

- Modèle: `com.karmaos.pc.amd64`
- Base: `core24`
- Desktop KDE: `plasma-core24-desktop` + `plasma-desktop-session`
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

## Signer le modèle (à faire une fois dans Ubuntu)

Le build nécessite un **model assertion signé**: `models/karmaos-core24-amd64.model`.

Ce dépôt fournit seulement le template JSON non signé: `models/karmaos-core24-amd64.json`.

### Procédure (dans une VM Ubuntu)

1. Préparez une VM Ubuntu (22.04+ / idéalement 24.04).
2. Clonez le repo.
3. Créez/choisissez une clé snap:

   - `snap create-key karmaos`

4. Générez le fichier `.model` signé à partir du JSON:

   - `snap sign -k karmaos models/karmaos-core24-amd64.json > models/karmaos-core24-amd64.model`

5. **Committez** puis poussez `models/karmaos-core24-amd64.model`.

Notes:
- Vous devrez remplacer `brand-id` et `authority-id` dans le JSON par des valeurs cohérentes avec votre compte/autorité de signature.
- Tant que `models/karmaos-core24-amd64.model` n’est pas présent dans le repo, le workflow échouera volontairement avec un message explicite.

## Dépannage

- **Workflow rouge / échec sur “Build image”**:
  - Vérifiez d’abord les logs de `scripts/build.sh`.
  - Cause la plus fréquente: fichier `.model` manquant (voir section “Signer le modèle”).

- **Artifact absent**:
  - L’étape `Upload image artifact` n’upload que `dist/karmaos-26.01-amd64.img`.
  - Si le build échoue avant la génération de l’image, aucun artifact ne sera présent.

- **Erreur ubuntu-image / aucune image produite**:
  - Vérifiez que votre `.model` est bien signé et valide.
  - Vérifiez aussi les snaps listés (noms/channels) dans `models/karmaos-core24-amd64.json`.

