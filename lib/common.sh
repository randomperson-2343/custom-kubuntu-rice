# shellcheck shell=bash disable=SC2034
# Shared functions for install.sh, uninstall.sh and matrix-rice.
# Sourced, not executed. Expects MR_SRC to point at the folder that holds
# lib/, palettes/, templates/, rain/, plasma/ and sddm/.

MR_VARIANTS=(green cyan amber)
MR_PLUGIN_ID="com.github.matrixrice.coderain"
MR_SDDM_THEME="matrix-rice"
MR_SDDM_DROPIN="${MR_SDDM_DROPIN:-/etc/sddm.conf.d/zz-matrix-rice.conf}"
MR_FONT_UI="JetBrains Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
MR_FONT_SMALL="JetBrains Mono,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
MR_UNSET="__matrix_rice_unset__"
MR_BLOCK_START="# >>> matrix-rice >>>"
MR_BLOCK_END="# <<< matrix-rice <<<"

# Where things live on the user's machine. Overridable for tests.
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
MR_DATA="$XDG_DATA_HOME/matrix-rice"        # installed copy of this repo + backups
MR_CONF="$XDG_CONFIG_HOME/matrix-rice"      # state + generated shell hook
MR_BACKUP="$MR_DATA/backups"
MR_ORIGINALS="$MR_BACKUP/originals.tsv"     # KDE keys as they were before install
MR_STATE="$MR_CONF/state"
MR_BIN="$HOME/.local/bin"

# ---------- output ----------

if [ -t 1 ]; then
  _c_ok=$'\e[1;32m' _c_warn=$'\e[1;33m' _c_err=$'\e[1;31m' _c_dim=$'\e[2m' _c_off=$'\e[0m'
else
  _c_ok="" _c_warn="" _c_err="" _c_dim="" _c_off=""
fi
say()  { printf '%s>>%s %s\n' "$_c_ok" "$_c_off" "$*"; }
ok()   { printf '   %s[ok]%s %s\n' "$_c_ok" "$_c_off" "$*"; }
skip() { printf '   %s[skipped]%s %s\n' "$_c_dim" "$_c_off" "$*"; }
warn() { printf '   %s[warn]%s %s\n' "$_c_warn" "$_c_off" "$*" >&2; }
die()  { printf '%s[error]%s %s\n' "$_c_err" "$_c_off" "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------- palettes and templates ----------

is_variant() {
  local v
  for v in "${MR_VARIANTS[@]}"; do [ "$v" = "$1" ] && return 0; done
  return 1
}

# load_palette <green|cyan|amber> - sets MR_ID, MR_NAME, MR_FG, ...
load_palette() {
  is_variant "$1" || die "Unknown color '$1'. Choose one of: ${MR_VARIANTS[*]}"
  # shellcheck source=/dev/null
  . "$MR_SRC/palettes/$1.sh"
}

# "#00FF41" -> "0,255,65"
hex_to_rgb() {
  local h=${1#\#}
  printf '%d,%d,%d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

# "#00FF41" -> "38;2;0;255;65" (ANSI truecolor, for fastfetch)
hex_to_sgr() {
  local rgb
  rgb=$(hex_to_rgb "$1")
  printf '38;2;%s' "${rgb//,/;}"
}

# Builds a sed script that replaces every {{KEY}} with the loaded palette.
_palette_sed() {
  local k v i
  printf 's|{{ID}}|%s|g\n' "$MR_ID"
  printf 's|{{NAME}}|%s|g\n' "$MR_NAME"
  printf 's|{{CMATRIX}}|%s|g\n' "$MR_CMATRIX"
  for k in BG SURFACE FG HEAD DIM FAINT ALERT FACE HILITE LIGHT SHADOW DKSHADOW TITLE TITLE_INACTIVE TITLE_INACTIVE_TEXT; do
    v="MR_$k"
    v=${!v}
    printf 's|{{%s}}|%s|g\n' "$k" "$v"
    printf 's|{{%s_RGB}}|%s|g\n' "$k" "$(hex_to_rgb "$v")"
    printf 's|{{%s_SGR}}|%s|g\n' "$k" "$(hex_to_sgr "$v")"
  done
  for i in "${!MR_ANSI[@]}"; do
    printf 's|{{C%d}}|%s|g\n' "$i" "${MR_ANSI[$i]}"
    printf 's|{{C%d_RGB}}|%s|g\n' "$i" "$(hex_to_rgb "${MR_ANSI[$i]}")"
  done
}

# render <template> <destination> - fill a template from the loaded palette.
# Fails if any {{placeholder}} is left over.
render() {
  local src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  sed -f <(_palette_sed) "$src" > "$dst.tmp" || return 1
  if grep -q '{{[A-Z0-9_]*}}' "$dst.tmp"; then
    rm -f "$dst.tmp"
    die "Template $src has unknown placeholders"
  fi
  mv "$dst.tmp" "$dst"
}

# ---------- KDE config helpers ----------

kwrite() { kwriteconfig6 "$@"; }
kread()  { kreadconfig6 "$@"; }

# _group_args "A/B/C" -> --group A --group B --group C
_group_args() {
  local IFS=/ g
  for g in $1; do printf -- '--group\n%s\n' "$g"; done
}

# remember_key <file> <group/path> <key>
# Records the key's current value once, before matrix-rice ever changes it,
# so uninstall can put it back exactly.
remember_key() {
  local file=$1 groups=$2 key=$3 val
  mkdir -p "$MR_BACKUP"
  touch "$MR_ORIGINALS"
  if awk -F'\t' -v f="$file" -v g="$groups" -v k="$key" \
      '$1==f && $2==g && $3==k {found=1} END {exit !found}' "$MR_ORIGINALS"; then
    return 0
  fi
  local -a gargs
  mapfile -t gargs < <(_group_args "$groups")
  val=$(kread --file "$file" "${gargs[@]}" --key "$key" --default "$MR_UNSET" 2>/dev/null) || val=$MR_UNSET
  printf '%s\t%s\t%s\t%s\n' "$file" "$groups" "$key" "$val" >> "$MR_ORIGINALS"
}

# set_key <file> <group/path> <key> <value> - remember, then write.
set_key() {
  local file=$1 groups=$2 key=$3 value=$4
  remember_key "$file" "$groups" "$key"
  local -a gargs
  mapfile -t gargs < <(_group_args "$groups")
  kwrite --file "$file" "${gargs[@]}" --key "$key" -- "$value"
}

# original_value <file> <group/path> <key> - prints the remembered value.
original_value() {
  [ -f "$MR_ORIGINALS" ] || { printf '%s' "$MR_UNSET"; return; }
  awk -F'\t' -v f="$1" -v g="$2" -v k="$3" \
    '$1==f && $2==g && $3==k {print $4; exit}' "$MR_ORIGINALS"
}

# restore_originals - writes every remembered key back (or deletes it).
restore_originals() {
  [ -f "$MR_ORIGINALS" ] || return 0
  local file groups key val
  local -a gargs
  while IFS=$'\t' read -r file groups key val; do
    [ -n "$file" ] || continue
    mapfile -t gargs < <(_group_args "$groups")
    if [ "$val" = "$MR_UNSET" ]; then
      kwrite --file "$file" "${gargs[@]}" --key "$key" --delete
    else
      kwrite --file "$file" "${gargs[@]}" --key "$key" -- "$val"
    fi
  done < "$MR_ORIGINALS"
}

# Tell running KDE apps that fonts/colors changed (KGlobalSettings).
notify_kde() {
  have dbus-send || return 0
  local t
  for t in 0 1 2; do  # PaletteChanged, FontChanged, StyleChanged
    dbus-send --session --type=signal /KGlobalSettings \
      org.kde.KGlobalSettings.notifyChange "int32:$t" int32:0 2>/dev/null || true
  done
}

# plasma_eval <javascript> - runs a Plasma shell script, prints its output.
plasma_eval() {
  if have qdbus6; then
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1"
  elif have qdbus; then
    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1"
  else
    dbus-send --session --print-reply --dest=org.kde.plasmashell /PlasmaShell \
      org.kde.PlasmaShell.evaluateScript "string:$1" |
      sed -n 's/^ *string "\(.*\)"$/\1/p'
  fi
}

# ---------- login manager ----------

# Prints sddm, plasmalogin, gdm3, ... or "unknown".
detect_login_manager() {
  if [ -n "${MR_LOGIN_MANAGER:-}" ]; then echo "$MR_LOGIN_MANAGER"; return; fi  # tests
  local unit
  unit=$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null) || unit=""
  case "$unit" in
    *sddm*) echo sddm ;;
    *plasmalogin*|*plasma-login*) echo plasmalogin ;;
    "") if [ -f /etc/X11/default-display-manager ]; then
          basename "$(cat /etc/X11/default-display-manager)"
        else
          echo unknown
        fi ;;
    *) basename "$unit" .service ;;
  esac
}

# ---------- state ----------

state_get() {
  [ -f "$MR_STATE" ] || return 0
  sed -n "s/^$1=//p" "$MR_STATE" | tail -n 1
}

state_set() {
  mkdir -p "$MR_CONF"
  touch "$MR_STATE"
  local tmp
  tmp=$(mktemp)
  grep -v "^$1=" "$MR_STATE" > "$tmp" || true
  printf '%s=%s\n' "$1" "$2" >> "$tmp"
  mv "$tmp" "$MR_STATE"
}

# ---------- shell rc blocks ----------

add_rc_block() {
  local rc=$1
  [ -f "$rc" ] || return 0
  remove_rc_block "$rc"
  {
    printf '\n%s\n' "$MR_BLOCK_START"
    printf '[ -f "%s/shell.sh" ] && . "%s/shell.sh"\n' "$MR_CONF" "$MR_CONF"
    printf '%s\n' "$MR_BLOCK_END"
  } >> "$rc"
}

remove_rc_block() {
  local rc=$1 tmp
  [ -f "$rc" ] || return 0
  grep -qF "$MR_BLOCK_START" "$rc" || return 0
  tmp=$(mktemp)
  # Delete the block and the one blank line add_rc_block put before it.
  awk -v s="$MR_BLOCK_START" -v e="$MR_BLOCK_END" '
    $0 == s { skip = 1; blank = 0; next }
    skip    { if ($0 == e) skip = 0; next }
    {
      if (blank) print ""
      blank = 0
      if ($0 == "") { blank = 1; next }
      print
    }
    END { if (blank) print "" }
  ' "$rc" > "$tmp"
  cat "$tmp" > "$rc"   # keep the file's owner and permissions
  rm -f "$tmp"
}
