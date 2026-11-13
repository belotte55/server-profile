# server-profile

Mon profil shell pour les serveurs (bash et zsh) : prompt, alias, raccourcis PM2, `rm` vers une corbeille, téléchargements Opta…

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/belotte55/server-profile/main/install.sh | sh
```

Avec le nom et l'environnement du serveur dès la première installation :

```bash
curl -fsSL https://raw.githubusercontent.com/belotte55/server-profile/main/install.sh | FP_PSEUDO='MPG - PROD #3' FP_ENVIRONMENT=production sh
```

L'installeur :

- télécharge `profile.sh` dans `~/.frank_profile` (l'ancienne version est sauvegardée en `~/.frank_profile.bak.<date>`) ;
- crée `~/.frank_profile.local` (droits 600) s'il n'existe pas. Si un ancien `~/.frank_profile` est présent, il en reprend `PSEUDO`, `ENVIRONMENT`, les identifiants Opta et les alias `ssh` ;
- ajoute une ligne `. ~/.frank_profile` à `~/.bashrc` et `~/.zshrc` si elle n'y est pas déjà.

Il peut être relancé autant de fois que nécessaire. Depuis un serveur déjà équipé, `fp_update` fait la mise à jour.

## Config par serveur

Tout ce qui est propre à un serveur ou secret va dans `~/.frank_profile.local`, jamais dans ce dépôt. Voir [local.example.sh](local.example.sh).

## Activation

Le profil ne s'applique que si `LOGGED_USER=frank` (compte `ubuntu` partagé). Seules `dlOptaCalendar` et `dlOptaMatch` sont disponibles pour tout le monde. Sur un serveur perso, mettre `FP_ALWAYS=1` dans le fichier local.

## Commandes

| Commande | Rôle |
|---|---|
| `bo`, `mpm`, `mpp`, `watcher`, `ftp` | aller dans le dossier du projet |
| `listMpg`, `listMpp`, `reloadMpg`, `reloadMpp` | apps PM2 `mpg-*` / `mpp-*` |
| `getAgeOf <PID\|motif> [--kill]` | âge des processus node |
| `findPidWith <motif>`, `killPidWith <motif>` | chercher / tuer (confirmation s'il y en a plusieurs) |
| `rm …` | déplace dans `/tmp/trash.XXXXXX` (vrai rm : `rrm`) |
| `rand [long] [caractères] [nombre]` | chaînes aléatoires |
| `f fichier.json` | JSON lisible |
| `gd …` | `mpg_tools/lib/getDocument.js` avec le node nvm le plus récent |
| `dlOptaCalendar <compet> [saison]`, `dlOptaMatch <match>` | flux Opta F1 / F9 |
| `gs`, `gc`, `gb`, `gr`, `glog` | git |
| `src`, `fp_update` | recharger / mettre à jour le profil |
