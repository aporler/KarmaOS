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
## Premier démarrage

Après avoir booté KarmaOS, exécutez le script de configuration pour installer les apps recommandées :

```bash
# Depuis un terminal dans KarmaOS
curl -fsSL https://raw.githubusercontent.com/aporler/KarmaOS/main/scripts/first-boot-setup.sh | bash
```

Ou manuellement :
```bash
snap install snap-store
snap install firefox
snap install gnome-46-2404
```

Apps optionnelles disponibles : `libreoffice`, `thunderbird`, `vlc`, `gimp`, `code`
## Regénérer le modèle signé (optionnel)

Le build nécessite un **model assertion signé**: `models/karmaos-core24-amd64.model`.

Le template non signé est ici: `models/karmaos-core24-amd64.json`.

Exemple (dans une VM Ubuntu):

- `snap create-key karmaos`
- Mettre à jour `authority-id`, `brand-id` et `timestamp` dans le JSON (idéalement un timestamp UTC récent)
- `snap sign -k karmaos models/karmaos-core24-amd64.json > models/karmaos-core24-amd64.model`

### Signer en CI (recommandé)

Si vous ne voulez pas committer le `.model` signé, vous pouvez le signer pendant GitHub Actions.

1. Sur une machine Ubuntu qui a la clé:
	- `snap export-key karmaos > karmaos.key`
	- `base64 -w0 karmaos.key` (copiez la sortie)
2. Dans GitHub  **Settings  Secrets and variables  Actions**:
	- Ajouter un secret `KARMAOS_SNAP_EXPORT_KEY_B64` avec la valeur base64.
3. Le script [scripts/build.sh](scripts/build.sh) importera la clé et signera un `.model` temporaire avec un timestamp courant.

## Dépannage

- **Workflow rouge / échec sur “Build image”**: lire les logs de `scripts/build.sh`.
- **Artifact absent**: si le build échoue avant la génération de l’image, aucun artifact n’est upload.
- **Erreur ubuntu-image / aucune image produite**: vérifier le `.model` et les snaps/channels.
- **"timestamp outside of signing key validity"**: le `timestamp` du `.model` est antérieur à la date de validité `since` de la clé enregistrée dans le store.
	- Fix: régénérer et re-signer le `.model` avec un timestamp plus récent, ou utiliser la signature en CI ci-dessus.
