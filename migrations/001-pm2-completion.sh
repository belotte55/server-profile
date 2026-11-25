#!/bin/sh
# Migration 001 — autocomplétion pm2 sur un serveur déjà équipé.
#
#   curl -fsSL https://raw.githubusercontent.com/belotte55/server-profile/main/migrations/001-pm2-completion.sh | sh
#
# 1. Met ~/.frank_profile à jour s'il ne contient pas encore l'autocomplétion
#    (même chose que fp_update ; ~/.frank_profile.local n'est pas touché).
# 2. Retire de ~/.bashrc / ~/.zshrc les anciens blocs ajoutés à la main avec
#    `pm2 completion >> ~/.bashrc`, qui feraient doublon (sauvegarde .bak.<date>).
#
# Peut être relancée sans risque. Variables : FP_REF, FP_REPO_RAW, FP_GITHUB_TOKEN
# (mêmes rôles que pour install.sh).
set -eu

FP_REF=${FP_REF:-main}
FP_REPO_RAW=${FP_REPO_RAW:-https://raw.githubusercontent.com/belotte55/server-profile/$FP_REF}
PROFILE="$HOME/.frank_profile"

say() { printf '\033[36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31mErreur :\033[0m %s\n' "$*" >&2; exit 1; }

[ -f "$PROFILE" ] || die "$PROFILE absent : installer d'abord le profil avec install.sh"

#--- 1. Profil ---------------------------------------------------------------
if grep -q '_fp_pm2_complete' "$PROFILE"; then
  say "Le profil contient déjà l'autocomplétion pm2"
else
  say "Mise à jour du profil"
  if [ -n "${FP_GITHUB_TOKEN:-}" ]; then
    curl -fsSL -H "Authorization: token $FP_GITHUB_TOKEN" "$FP_REPO_RAW/install.sh"
  else
    curl -fsSL "$FP_REPO_RAW/install.sh"
  fi | FP_REPO_RAW=$FP_REPO_RAW sh
  grep -q '_fp_pm2_complete' "$PROFILE" || die "le profil installé ne contient pas l'autocomplétion"
fi

#--- 2. Anciens blocs `pm2 completion` --------------------------------------
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] && grep -q '###-begin-pm2-completion-###' "$rc" || continue
  backup="$rc.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$rc" "$backup"
  # Réécrit le fichier en place (garde droits et liens symboliques).
  sed '/###-begin-pm2-completion-###/,/###-end-pm2-completion-###/d' "$backup" >"$rc"
  say "Ancien bloc pm2 completion retiré de $(basename "$rc") (sauvegarde : $backup)"
done

say "Terminé. Recharger : . ~/.frank_profile   (ou ouvrir une nouvelle session)"
