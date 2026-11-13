#!/bin/sh
# Installe / met à jour ~/.frank_profile.
#
#   curl -fsSL https://raw.githubusercontent.com/belotte55/server-profile/main/install.sh | sh
#
# Variables optionnelles (à mettre devant `sh`) :
#   FP_PSEUDO='MPG - PROD #3'   nom affiché dans le prompt (1re install seulement)
#   FP_ENVIRONMENT=production   production | staging | dev (1re install seulement)
#   FP_REF=main                 branche / tag à installer
#   FP_GITHUB_TOKEN=…           si le dépôt est privé
set -eu

FP_REF=${FP_REF:-main}
FP_REPO_RAW=${FP_REPO_RAW:-https://raw.githubusercontent.com/belotte55/server-profile/$FP_REF}
PROFILE="$HOME/.frank_profile"
LOCAL="$HOME/.frank_profile.local"

say() { printf '\033[36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31mErreur :\033[0m %s\n' "$*" >&2; exit 1; }

fetch() { # <url> <dest>
  if command -v curl >/dev/null 2>&1; then
    if [ -n "${FP_GITHUB_TOKEN:-}" ]; then
      curl -fsSL -H "Authorization: token $FP_GITHUB_TOKEN" "$1" -o "$2"
    else
      curl -fsSL "$1" -o "$2"
    fi
  elif command -v wget >/dev/null 2>&1; then
    if [ -n "${FP_GITHUB_TOKEN:-}" ]; then
      wget -q --header="Authorization: token $FP_GITHUB_TOKEN" -O "$2" "$1"
    else
      wget -q -O "$2" "$1"
    fi
  else
    die "ni curl ni wget"
  fi
}

# Met une valeur entre quotes simples pour un fichier shell.
shquote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

say "Téléchargement depuis $FP_REPO_RAW"
fetch "$FP_REPO_RAW/profile.sh" "$tmp/profile.sh" || die "téléchargement de profile.sh impossible"
fetch "$FP_REPO_RAW/local.example.sh" "$tmp/local.example.sh" || die "téléchargement de local.example.sh impossible"
grep -q 'frank_profile' "$tmp/profile.sh" || die "le fichier téléchargé ne ressemble pas au profil"
if command -v bash >/dev/null 2>&1; then
  bash -n "$tmp/profile.sh" || die "profile.sh invalide (erreur de syntaxe), rien n'a été modifié"
fi

#--- Config locale (créée une seule fois, jamais écrasée) --------------------
if [ ! -f "$LOCAL" ]; then
  say "Création de $LOCAL"
  cp "$tmp/local.example.sh" "$tmp/local.sh"

  # Reprise des valeurs de l'ancien ~/.frank_profile s'il existe.
  old_pseudo='' old_env='' old_opta_user='' old_opta_pw='' old_hosts=''
  if [ -f "$PROFILE" ] && ! grep -q 'FP_REPO_RAW' "$PROFILE"; then
    say "Ancien profil détecté : reprise de PSEUDO, ENVIRONMENT, identifiants Opta et alias SSH"
    old_pseudo=$(sed -n "s/^[[:space:]]*export PSEUDO=[\"']\(.*\)[\"'][[:space:]]*$/\1/p" "$PROFILE" | head -n1)
    old_env=$(sed -n "s/^[[:space:]]*export ENVIRONMENT=[\"']\{0,1\}\([A-Za-z0-9_-]*\).*/\1/p" "$PROFILE" | head -n1)
    old_opta_user=$(sed -n 's/.*opta\.net[^"]*[?&]user=\([^&"]*\).*/\1/p' "$PROFILE" | head -n1)
    old_opta_pw=$(sed -n 's/.*opta\.net[^"]*[?&]psw=\([^&"]*\).*/\1/p' "$PROFILE" | head -n1)
    old_hosts=$(grep -E "^[[:space:]]*alias [A-Za-z0-9_]+='ssh " "$PROFILE" | sed 's/^[[:space:]]*//' || true)
  fi

  pseudo=${FP_PSEUDO:-$old_pseudo}
  env=${FP_ENVIRONMENT:-$old_env}
  {
    echo ""
    echo "# --- Valeurs renseignées à l'installation ($(date +%Y-%m-%d)) ---"
    [ -n "$pseudo" ] && echo "PSEUDO=$(shquote "$pseudo")"
    [ -n "$env" ] && echo "ENVIRONMENT=$(shquote "$env")"
    [ -n "$old_opta_user" ] && echo "OPTA_USER=$(shquote "$old_opta_user")"
    [ -n "$old_opta_pw" ] && echo "OPTA_PASSWORD=$(shquote "$old_opta_pw")"
    [ -n "$old_hosts" ] && printf '%s\n' "$old_hosts"
    true
  } >>"$tmp/local.sh"
  (umask 077 && cp "$tmp/local.sh" "$LOCAL")
  chmod 600 "$LOCAL"
else
  say "$LOCAL existe déjà, conservé tel quel"
fi

#--- Profil ------------------------------------------------------------------
if [ -f "$PROFILE" ]; then
  if cmp -s "$PROFILE" "$tmp/profile.sh"; then
    say "Profil déjà à jour"
  else
    backup="$PROFILE.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$PROFILE" "$backup"
    say "Ancien profil sauvegardé dans $backup"
  fi
fi
cp "$tmp/profile.sh" "$PROFILE"
chmod 644 "$PROFILE"

#--- Branchement dans les rc -------------------------------------------------
hook='[ -f "$HOME/.frank_profile" ] && . "$HOME/.frank_profile"'
added=0
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue
  if grep -q 'frank_profile' "$rc"; then
    say "$(basename "$rc") charge déjà le profil"
  else
    printf '\n# Profil perso (github.com/belotte55/server-profile)\n%s\n' "$hook" >>"$rc"
    say "Ajouté à $(basename "$rc")"
  fi
  added=1
done
if [ "$added" = 0 ]; then
  printf '# Profil perso (github.com/belotte55/server-profile)\n%s\n' "$hook" >>"$HOME/.bashrc"
  say "Créé ~/.bashrc"
fi

say "Terminé. Recharger : . ~/.frank_profile   (ou ouvrir une nouvelle session)"
say "Config du serveur : $LOCAL"
