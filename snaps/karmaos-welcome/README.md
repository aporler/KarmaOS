# KarmaOS Welcome Snap

Premier snap de configuration graphique pour KarmaOS 26.01.

## Fonctionnalités

- ✨ Interface graphique élégante avec logo KarmaOS
- 🌐 Configuration réseau assistée
- 👤 Création de compte utilisateur locale
- 📦 Sélection et installation d'applications
- 🎨 Configuration du wallpaper automatique
- 🔄 Auto-suppression après setup

## Build

```bash
cd snaps/karmaos-welcome
snapcraft
```

## Utilisation

Le snap démarre automatiquement au premier boot via un daemon.

Ou manuellement :
```bash
snap install --dangerous karmaos-welcome_*.snap
karmaos-welcome.setup
```

## TODO

- [ ] Améliorer la gestion réseau WiFi
- [ ] Ajouter animations de transition
- [ ] Support multilingue
- [ ] Thème sombre
- [ ] Détection automatique du fuseau horaire
