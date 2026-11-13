# shellcheck shell=bash
# ~/.frank_profile.local — config propre à CE serveur.
# Jamais écrasé par les mises à jour, jamais commité (contient des identifiants).
# Décommenter / compléter ce qui est utile.

# Nom affiché dans le prompt (par défaut : hostname)
#PSEUDO='MPG - PROD #1'

# production | staging | dev — change la couleur du prompt (rouge / jaune / vert)
#ENVIRONMENT=production

# Le profil ne s'applique que si LOGGED_USER vaut FP_USER (frank par défaut).
# Sur un serveur perso sans LOGGED_USER : FP_ALWAYS=1
#FP_USER=frank
#FP_ALWAYS=1

#MPG_ADMIN_ID=user_348
#FP_START_DIR=$HOME/mpg_back_bo   # dossier où on arrive à la connexion
#FP_PROMPT_BAR=0                  # 0 = pas de ligne de tirets avant le prompt
#FP_SHARE_HISTORY=1               # zsh : historique partagé entre sessions

# Opta
#OPTA_USER=
#OPTA_PASSWORD=
#OPTA_SEASON=2025
#OPTA_DIR=/home/ftp/opta

# Raccourcis SSH
#alias api_01='ssh ubuntu@1.2.3.4'
