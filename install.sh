#!/usr/bin/env bash
# install.sh - install the Matrix rice for Kubuntu 26.04 / KDE Plasma 6.
#
#   ./install.sh [green|cyan|amber] [options]
#
#   --no-login      leave the login screen alone (no sudo for it)
#   --no-taskbar    keep your current panels (no Windows 95 taskbar)
#   --no-tiling     don't turn on auto-tiling (Matrix Tile)
#   --plain         Matrix colors only, without the Windows 95 shapes
#   --no-packages   don't install packages with apt
#   --yes           don't ask questions, use the defaults
set -euo pipefail

MR_SRC=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
# shellcheck source=lib/common.sh
. "$MR_SRC/lib/common.sh"
# shellcheck source=lib/apply.sh
. "$MR_SRC/lib/apply.sh"

PACKAGES=(fonts-jetbrains-mono fonts-noto-cjk cmatrix fastfetch starship qdbus-qt6
          qml6-module-qtquick-effects qt6-style-kvantum qt5-style-kvantum)

color=green login=yes taskbar=ask tiling=ask style=95 packages=yes assume_yes=no
for arg in "$@"; do
  case "$arg" in
    green|cyan|amber) color=$arg ;;
    --no-login) login=no ;;
    --no-taskbar) taskbar=no ;;
    --no-tiling) tiling=no ;;
    --plain) style=plain ;;
    --no-packages) packages=no ;;
    --yes|-y) assume_yes=yes ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option '$arg'. Try: ./install.sh --help" ;;
  esac
done

ask() { # ask "question" default(y/n)
  local reply
  [ "$assume_yes" = yes ] && { [ "$2" = y ]; return; }
  read -r -p "$1 [$( [ "$2" = y ] && echo Y/n || echo y/N )] " reply || reply=""
  reply=${reply:-$2}
  [[ "$reply" =~ ^[Yy] ]]
}

# ---------- checks ----------
[ "$(id -u)" -ne 0 ] || die "Run ./install.sh as yourself, not with sudo. It asks for your password only when needed."
if ! grep -qi ubuntu /etc/os-release 2>/dev/null; then
  warn "This was built for Kubuntu 26.04. Continuing anyway."
elif ! grep -q 'VERSION_ID="26.04"' /etc/os-release; then
  warn "This was built for Kubuntu 26.04; you have $(. /etc/os-release && echo "$VERSION"). Continuing anyway."
fi
case "${XDG_CURRENT_DESKTOP:-}" in
  *KDE*) ;;
  *) warn "You don't seem to be inside a KDE Plasma session. Run this from a terminal on your Plasma desktop." ;;
esac

first_install=yes
[ -f "$MR_ORIGINALS" ] && first_install=no
upgrade=no
[ -d "$MR_WALLPAPER_DIR" ] && upgrade=yes

say "Matrix rice installer: color $color, style $style"

# ---------- packages ----------
if [ "$packages" = yes ]; then
  missing=()
  for p in "${PACKAGES[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    say "Installing packages from Ubuntu's repositories: ${missing[*]}"
    sudo apt-get update -qq || warn "apt update failed; trying the install anyway"
    if ! sudo apt-get install -y "${missing[@]}"; then
      warn "Batch install failed, trying one at a time"
      for p in "${missing[@]}"; do
        sudo apt-get install -y "$p" || warn "could not install $p (that part will be skipped)"
      done
    fi
  else
    ok "all packages already installed"
  fi
fi
for c in kwriteconfig6 kreadconfig6 plasma-apply-colorscheme plasma-apply-desktoptheme; do
  have "$c" || die "Missing '$c'. Is KDE Plasma 6 installed?"
done

# ---------- backups ----------
say "Backing up your current settings"
stamp=$(date +%Y%m%d-%H%M%S)
snap="$MR_BACKUP/$stamp"
mkdir -p "$snap"
for f in kdeglobals kscreenlockerrc konsolerc kwinrc plasmarc ksplashrc starship.toml \
         plasma-org.kde.plasma.desktop-appletsrc plasmashellrc Kvantum/kvantum.kvconfig; do
  [ -f "$XDG_CONFIG_HOME/$f" ] && cp "$XDG_CONFIG_HOME/$f" "$snap/$(basename "$f")"
done
[ -d "$XDG_CONFIG_HOME/fastfetch" ] && cp -r "$XDG_CONFIG_HOME/fastfetch" "$snap/fastfetch"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do [ -f "$rc" ] && cp "$rc" "$snap/"; done
if [ "$first_install" = yes ]; then
  # Your own prompt/banner configs, put back on uninstall.
  mkdir -p "$MR_BACKUP/original-files"
  [ -f "$XDG_CONFIG_HOME/starship.toml" ] && cp "$XDG_CONFIG_HOME/starship.toml" "$MR_BACKUP/original-files/"
  [ -d "$XDG_CONFIG_HOME/fastfetch" ] && cp -r "$XDG_CONFIG_HOME/fastfetch" "$MR_BACKUP/original-files/"
  remember_wallpapers
  touch "$MR_ORIGINALS"
fi
ok "saved to $snap"

# ---------- files ----------
say "Installing theme files"
install_app
install_variant_files
install_wallpaper_plugin
install_splash_package
install_tiler
apply_fonts
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] && add_rc_block "$rc" && ok "shell hook in $rc"
done

# Plasma keeps old QML in memory, so an update needs a shell restart.
if [ "$upgrade" = yes ] && plasma_running; then
  say "Restarting the Plasma shell to load the updated wallpaper"
  restart_plasmashell
fi

# ---------- apply ----------
state_set STYLE "$style"
[ -n "$(state_get RAIN)" ] || state_set RAIN on
apply_variant "$color" --no-login

if [ "$style" = 95 ] && [ "$taskbar" != no ] && [ "$(state_get TASKBAR)" != on ]; then
  if ask "Replace your bottom panel with a Windows 95 taskbar? (your current layout is saved; undo with: matrix-rice taskbar off)" y; then
    taskbar_on
  else
    skip "taskbar (turn on later with: matrix-rice taskbar on)"
  fi
fi

if [ "$tiling" != no ] && [ "$(state_get TILING)" != on ]; then
  if ask "Turn on auto-tiling? Windows arrange themselves; games are left alone; Meta+Shift+T switches it off" y; then
    tiling_set on
  else
    skip "auto-tiling (turn on later with: matrix-rice tiling on)"
  fi
elif [ "$(state_get TILING)" = on ]; then
  kwin_scripts_reload   # pick up an updated tiler
fi

if [ "$login" = yes ]; then
  if ask "Install the Matrix login screen? (needs your password)" y; then
    load_palette "$color"
    login_install
  else
    skip "login screen (install later with: matrix-rice login install)"
  fi
fi

echo
say "Done. Log out and back in once so every app picks up the new fonts and style."
cat <<NEXT
   Switch colors:    matrix-rice green | cyan | amber
   Rain on/off:      matrix-rice rain on | off
   Plain shapes:     matrix-rice style plain   (back: matrix-rice style 95)
   Auto-tiling:      matrix-rice tiling on | off   (Meta+Shift+T for gaming)
   Status:           matrix-rice status
   Uninstall:        ~/.local/share/matrix-rice/app/uninstall.sh
   (If 'matrix-rice' is not found yet, log out and in, or use ~/.local/bin/matrix-rice)
NEXT
