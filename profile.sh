# shellcheck shell=bash
# ~/.frank_profile — profil shell pour les serveurs (bash et zsh).
#
# Installé par install.sh, sourcé depuis ~/.bashrc et/ou ~/.zshrc.
# NE PAS modifier ce fichier sur le serveur : il est écrasé à chaque mise à jour.
# La config propre à un serveur (nom, environnement, identifiants, hôtes SSH)
# va dans ~/.frank_profile.local, qui n'est jamais écrasé.

# Shell non interactif (scp, rsync, cron…) : on ne touche à rien.
case $- in *i*) ;; *) return 0 2>/dev/null || exit 0 ;; esac

FP_REPO_RAW=${FP_REPO_RAW:-https://raw.githubusercontent.com/belotte55/server-profile/main}
FP_LOCAL_FILE=${FP_LOCAL_FILE:-$HOME/.frank_profile.local}

if [ -n "${ZSH_VERSION:-}" ]; then _fp_shell=zsh; else _fp_shell=bash; fi

# Config locale du serveur (lue avant tout, elle peut tout surcharger).
# shellcheck source=/dev/null
[ -r "$FP_LOCAL_FILE" ] && . "$FP_LOCAL_FILE"

###############################################################################
# Opta — disponible pour tous les utilisateurs du compte
###############################################################################
OPTA_SEASON=${OPTA_SEASON:-2025}
OPTA_DIR=${OPTA_DIR:-/home/ftp/opta}
OPTA_BASE_URL=${OPTA_BASE_URL:-http://omo.akamai.opta.net}

_fp_opta_fetch() { # <url_path> <dest> [param=valeur…]
  local url_path=$1 dest=$2   # pas « path » : en zsh c'est le tableau lié à PATH
  shift 2
  if [ -z "${OPTA_USER:-}" ] || [ -z "${OPTA_PASSWORD:-}" ]; then
    echo "OPTA_USER / OPTA_PASSWORD absents de $FP_LOCAL_FILE" >&2
    return 1
  fi
  local args=() p
  for p in "user=$OPTA_USER" "psw=$OPTA_PASSWORD" "$@"; do
    args+=(--data-urlencode "$p")
  done
  curl -fsSL -G "${OPTA_BASE_URL}${url_path}" "${args[@]}" -o "$dest"
}

_fp_opta_save() { # <tmp> <destination finale>
  mkdir -p "$OPTA_DIR" && mv -f -- "$1" "$OPTA_DIR/$2" && echo "→ $OPTA_DIR/$2"
}

# Usage : dlOptaCalendar <competition_id> [saison]
dlOptaCalendar() {
  local competition=${1:-} season=${2:-$OPTA_SEASON} tmp id
  if [ -z "$competition" ]; then
    echo "Usage : dlOptaCalendar <competition_id> [saison=$OPTA_SEASON]" >&2
    return 1
  fi
  tmp=$(mktemp) || return 1
  if ! _fp_opta_fetch /competition.php "$tmp" \
      "competition=$competition" "season_id=$season" feed_type=F1; then
    echo "Échec du téléchargement" >&2; command rm -f -- "$tmp"; return 1
  fi
  id=$(command grep -o 'competition_id="[^"]*"' "$tmp" | head -n1 | cut -d'"' -f2)
  _fp_opta_save "$tmp" "srml-${id:-$competition}-${season}-results.xml"
}

# Usage : dlOptaMatch <short_match_id>
dlOptaMatch() {
  local match=${1:-} tmp competition season
  if [ -z "$match" ]; then
    echo "Usage : dlOptaMatch <short_match_id>" >&2
    return 1
  fi
  tmp=$(mktemp) || return 1
  if ! _fp_opta_fetch / "$tmp" "game_id=$match" feed_type=F9; then
    echo "Échec du téléchargement" >&2; command rm -f -- "$tmp"; return 1
  fi
  competition=$(command grep -o 'Competition uID="c[0-9]*"' "$tmp" | head -n1 | tr -dc '0-9')
  season=$(command grep -o 'season_id">[^<]*' "$tmp" | head -n1 | cut -d'>' -f2)
  if [ -z "$competition" ] || [ -z "$season" ]; then
    echo "Réponse inattendue (compétition/saison introuvables), fichier gardé : $tmp" >&2
    return 1
  fi
  _fp_opta_save "$tmp" "srml-${competition}-${season}-${match}-matchresults.xml"
}

###############################################################################
# Tout ce qui suit ne s'applique qu'à moi
###############################################################################
if [ "${LOGGED_USER:-}" != "${FP_USER:-frank}" ] && [ "${FP_ALWAYS:-0}" != 1 ]; then
  return 0
fi

#--- Historique -------------------------------------------------------------
HISTFILE=${FP_HISTFILE:-$HOME/.bash_history}
HISTSIZE=10000
if [ "$_fp_shell" = zsh ]; then
  SAVEHIST=20000                       # sans ça zsh n'écrit rien dans HISTFILE
  setopt APPEND_HISTORY HIST_IGNORE_DUPS
  [ "${FP_SHARE_HISTORY:-0}" = 1 ] && setopt SHARE_HISTORY
else
  HISTFILESIZE=20000
  HISTCONTROL=ignoreboth
  shopt -s histappend checkwinsize
fi

#--- Environnement ----------------------------------------------------------
# shellcheck source=/dev/null
[ -r "$HOME/.colors" ] && . "$HOME/.colors"

export PSEUDO=${PSEUDO:-$(hostname -s 2>/dev/null || hostname)}
export ENVIRONMENT=${ENVIRONMENT:-production}
export GENERATOR_USER=${LOGGED_USER:-$USER}
export MPG_ADMIN_ID=${MPG_ADMIN_ID:-user_348}
if command -v nvim >/dev/null 2>&1; then export EDITOR=nvim; else export EDITOR=vim; fi

# Chemins des projets
FTP_PATH=${FTP_PATH:-/home/ftp}
MPG_BO_PATH=${MPG_BO_PATH:-$HOME/mpg_back_bo}
MPM_BO_PATH=${MPM_BO_PATH:-$HOME/mpm_api_bo}
MPP_BO_PATH=${MPP_BO_PATH:-$HOME/mpp_back_bo}
WATCHER_PATH=${WATCHER_PATH:-$HOME/watcher}
MPG_TOOLS_PATH=${MPG_TOOLS_PATH:-$HOME/mpg_tools}
NODE_BIN=${NODE_BIN:-/usr/bin/node}

# Noms PM2
export MPM='api-bo-mpm'
export MPP='api-mpp-bo'
export MPG_LISTENERS='mpg-calendars-listener mpg-matches-events-listener mpg-matches-previews-listener mpg-matches-results-listener mpg-players-rankings-listener mpg-standings-listener'
export MPM_LISTENERS='mpm-calendars-listener mpm-matches-events-listener mpm-matches-previews-listener mpm-matches-results-listener mpm-players-rankings-listener mpm-squads-listener mpm-standings-listener'
export POST_GWS='mpg-post-game-week-scheduler'
export PRE_GWS='mpg-pre-game-week-scheduler'
export BO='new-api-back'
export WATCHER='watcher'

#--- Prompt -----------------------------------------------------------------
# Couleur du nom selon l'environnement : rouge en prod, jaune en staging, vert sinon.
case $ENVIRONMENT in
  prod|production)        _fp_env_color=red;    _fp_env_code=31 ;;
  staging|preprod|recette) _fp_env_color=yellow; _fp_env_code=33 ;;
  *)                      _fp_env_color=green;  _fp_env_code=32 ;;
esac

if [ "$_fp_shell" = zsh ]; then
  autoload -Uz add-zsh-hook
  _fp_precmd() {
    if [ "${FP_PROMPT_BAR:-1}" = 1 ]; then
      print -rP -- "%F{8}${(l:COLUMNS::-:)}%f"
    else
      print
    fi
  }
  add-zsh-hook precmd _fp_precmd
  PS1="%F{${_fp_env_color}}${PSEUDO//\%/%%}%f %F{green}[%*]%f %F{blue}%~%f %F{8}⨕%f"$'\n'
else
  _fp_prompt_bar() {
    if [ "${FP_PROMPT_BAR:-1}" = 1 ]; then
      _fp_bar=$(printf '%*s' "${COLUMNS:-80}" '')
      _fp_bar=${_fp_bar// /-}$'\n'
    else
      _fp_bar=
    fi
  }
  case ${PROMPT_COMMAND:-} in
    *_fp_prompt_bar*) ;;
    *) PROMPT_COMMAND="_fp_prompt_bar${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
  esac
  PS1='\n\[\e[90m\]${_fp_bar}\[\e[0m\]'
  PS1+='\[\e['"$_fp_env_code"'m\]${PSEUDO}\[\e[0m\] \[\e[32m\][\t]\[\e[0m\] \[\e[34m\]\w\[\e[0m\] \[\e[90m\]⨕\[\e[0m\]\n'
fi

#--- Alias ------------------------------------------------------------------
alias ftp='cd "$FTP_PATH"'
alias bo='cd "$MPG_BO_PATH"'
alias mpm='cd "$MPM_BO_PATH"'
alias mpp='cd "$MPP_BO_PATH"'
alias watcher='cd "$WATCHER_PATH"'

if command -v nvim >/dev/null 2>&1; then alias vim='nvim'; fi
alias vi='vim'
alias src="source ~/.${_fp_shell}rc"
alias monitor='nload'
alias grep='grep --color=auto'
alias tsc='./node_modules/.bin/tsc'
alias onode='node -r "$HOME/.npm/modules/node_overloader"'
alias forgeToken='"$NODE_BIN" "$MPG_BO_PATH/tools/forgeUserToken.js"'

alias gs='clear && git status'
alias gc='clear && git checkout'
alias gb='clear && git branch'
alias gr='clear && git restore --staged'
alias glog="git log --graph --pretty=format:'%Cred%h%Creset - %Cgreen%cr%C(yellow) %D%Creset%Creset%n          %s %C(dim white)@%al' --abbrev-commit"

alias rrm='command rm'
alias nrm='command rm'

#--- Fonctions --------------------------------------------------------------
# Les anciennes versions définissaient certains noms en alias : on les retire
# pour que la définition des fonctions ne casse pas après un `src`.
unalias rm gd f rand listMpg listMpp reloadMpg reloadMpp findPidWith killPidWith getAgeOf 2>/dev/null

# Dernière version de node installée via nvm (sinon le node du PATH).
_fp_nvm_node() {
  local n
  n=$(ls -d "$HOME"/.nvm/versions/node/v*/bin/node 2>/dev/null | sort -V | tail -n1)
  if [ -n "$n" ]; then echo "$n"; else command -v node; fi
}

# Usage : gd <args de getDocument.js>
gd() { "${GD_NODE:-$(_fp_nvm_node)}" "$MPG_TOOLS_PATH/lib/getDocument.js" "$@"; }

# PM2
_fp_pm2_names() { pm2 jlist -s | jq -r --arg p "$1" '.[] | select(.name | startswith($p)) | .name'; }
_fp_pm2_reload() {
  local app
  _fp_pm2_names "$1" | while read -r app; do pm2 reload "$app"; done
}
listMpg()   { _fp_pm2_names mpg-; }
listMpp()   { _fp_pm2_names mpp-; }
reloadMpg() { _fp_pm2_reload mpg-; }
reloadMpp() { _fp_pm2_reload mpp-; }

# Chaînes aléatoires.
# Usage : rand [longueur=32] [caractères=a-zA-Z0-9] [nombre=1]
#         rand [longueur=32] [nombre]
rand() {
  local length=${1:-32} charset='a-zA-Z0-9' count=1
  case ${2:-} in
    '') ;;
    *[!0-9]*) charset=$2; count=${3:-1} ;;
    *) count=$2 ;;
  esac
  LC_ALL=C tr -dc -- "$charset" </dev/urandom | fold -w "$length" | head -n "$count"
}

# JSON lisible : f fichier.json
f() {
  if command -v jq >/dev/null 2>&1; then jq . "$@"; else json_pp <"$1"; fi
}

# Processus dont la ligne de commande contient le motif.
findPidWith() {
  [ -z "${1:-}" ] && { echo "Usage : findPidWith <motif>" >&2; return 1; }
  pgrep -af -- "$1"
}

# Tue (kill -9) les processus dont la ligne de commande contient le motif.
# Demande confirmation s'il y en a plusieurs.
killPidWith() {
  [ -z "${1:-}" ] && { echo "Usage : killPidWith <motif>" >&2; return 1; }
  local list n answer
  list=$(pgrep -af -- "$1")
  [ -z "$list" ] && { echo "Aucun processus ne correspond à « $1 »."; return 1; }
  n=$(printf '%s\n' "$list" | wc -l | tr -d ' ')
  if [ "$n" -gt 1 ]; then
    printf '%s\n' "$list"
    printf 'Tuer ces %s processus ? [o/N] ' "$n"
    read -r answer
    case $answer in o|O|y|Y) ;; *) echo "Annulé."; return 1 ;; esac
  fi
  # Tableau rempli par substitution non quotée : découpée en mots en bash comme en zsh.
  local pids
  # shellcheck disable=SC2207
  pids=($(printf '%s\n' "$list" | awk '{print $1}'))
  kill -9 "${pids[@]}" && echo "Killed ${pids[*]}"
}

# Âge des processus node correspondant au motif (ou d'un PID), --kill pour les tuer.
FP_AGE_EXCLUDE=${FP_AGE_EXCLUDE:-'Scheduler\.js$|Listener\.js$|Runner\.js$|main\.js$|watcher\.js|updatePredictionsChallengeStandings\.js|updateStandings\.js$|pm2-logrotate/app\.js$'}
getAgeOf() {
  local target=${1:-} kill=false a pid etime rest
  if [ -z "$target" ]; then
    echo "Usage : getAgeOf <PID | motif> [--kill]" >&2
    return 1
  fi
  shift
  for a in "$@"; do [ "$a" = --kill ] && kill=true; done

  if [[ $target =~ ^[0-9]+$ ]]; then
    ps -o etime= -p "$target" || return 1
    if $kill; then kill -9 "$target" && echo "💀 Killed $target"; fi
    return
  fi

  # Motif et exclusions passés par l'environnement pour que awk ne se trouve pas lui-même.
  ps ax -o pid=,etime=,args= \
    | FP_PAT=$target FP_EXCL=$FP_AGE_EXCLUDE awk '
        { cmd = $0; sub(/^ *[0-9]+ +[^ ]+ +/, "", cmd) }
        cmd ~ /^(grep|awk) / { next }
        index(cmd, "node") && cmd ~ ENVIRON["FP_PAT"] && cmd !~ ENVIRON["FP_EXCL"]' \
    | while read -r pid etime rest; do
        echo "[ $etime ] $pid $rest"
        if $kill; then sudo kill -9 "$pid" && echo "💀 Killed $pid"; fi
      done
}

# rm « sécurisé » : déplace dans /tmp/trash.XXXXXX au lieu de supprimer.
# Les options (-r, -f…) sont ignorées. Vrai rm : rrm / nrm / command rm.
# Attention : /tmp est vidé au redémarrage.
rm() {
  local arg files=() opts_done=0 trash dest base n ret=0  # pas « status » : lecture seule en zsh
  for arg in "$@"; do
    if [ "$opts_done" = 0 ]; then
      case $arg in
        --) opts_done=1; continue ;;
        -?*) continue ;;
      esac
    fi
    files+=("$arg")
  done
  [ ${#files[@]} -eq 0 ] && { echo "Usage : rm fichier…" >&2; return 1; }

  trash=$(mktemp -d "${FP_TRASH_DIR:-/tmp}/trash.XXXXXX") || return 1
  for arg in "${files[@]}"; do
    if [ ! -e "$arg" ] && [ ! -L "$arg" ]; then
      echo "rm: $arg : fichier introuvable" >&2; ret=1; continue
    fi
    base=$(basename -- "$arg")
    dest=$trash; n=1
    while [ -e "$dest/$base" ]; do dest=$trash/$n; n=$((n + 1)); done
    mkdir -p "$dest" && mv -- "$arg" "$dest/" || ret=1
  done
  echo "Fichiers déplacés dans \"$trash\"."
  return $ret
}

loadAliases() {
  # shellcheck source=/dev/null
  . "$HOME/.rc/aliases_generator.sh"
}

# Met à jour le profil depuis GitHub puis le recharge.
fp_update() {
  curl -fsSL "$FP_REPO_RAW/install.sh" | FP_REPO_RAW=$FP_REPO_RAW sh && . "$HOME/.frank_profile"
}

#--- Spécifique zsh ---------------------------------------------------------
if [ "$_fp_shell" = zsh ]; then
  zstyle ':completion:*:*:node:*' ignored-patterns '*.d.ts|*.js.map'
  zstyle ':completion:*:*:edit:*' ignored-patterns '*.d.ts|*.js.map'
  zstyle ':completion:*:*:vi:*' ignored-patterns '*.d.ts|*.js.map'
  setopt complete_aliases
fi

#--- Outils externes --------------------------------------------------------
# shellcheck source=/dev/null
[ -r "$HOME/.tools/pdiff.sh" ] && . "$HOME/.tools/pdiff.sh"

#--- Démarrage (une seule fois par shell, pas à chaque `src`) ---------------
if [ -z "${_FP_STARTED:-}" ]; then
  _FP_STARTED=1
  _fp_start_dir=${FP_START_DIR:-$MPG_BO_PATH}
  [ -d "$_fp_start_dir" ] && cd "$_fp_start_dir"
fi
return 0
