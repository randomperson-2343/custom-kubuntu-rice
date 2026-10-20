#!/usr/bin/env bash
# uninstall.sh - remove the Matrix rice and put your previous look back.
#   --keep-login   leave the login screen theme installed
set -euo pipefail

MR_SRC=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
# shellcheck source=lib/common.sh
. "$MR_SRC/lib/common.sh"
# shellcheck source=lib/apply.sh
. "$MR_SRC/lib/apply.sh"

keep_login=no
[ "${1:-}" = --keep-login ] && keep_login=yes
[ "$(id -u)" -ne 0 ] || die "Run ./uninstall.sh as yourself, not with sudo."
[ -d "$MR_DATA" ] || die "matrix-rice does not seem to be installed (no $MR_DATA)."

say "Uninstalling the Matrix rice"

# Panels first: restoring them also brings back the old wallpaper settings.
if [ "$(state_get TASKBAR)" = on ]; then
  taskbar_off
fi
restore_wallpapers

# Accent first, then the color scheme, so the old scheme is applied cleanly.
restore_key kdeglobals General AccentColor
scheme=$(original_value kdeglobals General ColorScheme)
if [ -z "$scheme" ] || [ "$scheme" = "$MR_UNSET" ]; then scheme=BreezeLight; fi
plasma-apply-colorscheme "$scheme" >/dev/null 2>&1 || warn "could not re-apply color scheme $scheme"
restore_originals
ptheme=$(original_value plasmarc Theme name)
if [ -z "$ptheme" ] || [ "$ptheme" = "$MR_UNSET" ]; then ptheme=default; fi
plasma-apply-desktoptheme "$ptheme" >/dev/null 2>&1 || true
kwin_reconfigure
ok "KDE settings restored (colors, fonts, window frames, widgets, lock screen, splash)"

# Remove installed files.
for v in "${MR_VARIANTS[@]}"; do
  load_palette "$v"
  rm -f "$XDG_DATA_HOME/color-schemes/Matrix$MR_NAME.colors" "$XDG_DATA_HOME/konsole/Matrix$MR_NAME.colorscheme"
  rm -rf "$XDG_DATA_HOME/aurorae/themes/Matrix95-$MR_NAME" \
         "$XDG_CONFIG_HOME/Kvantum/Matrix95-$MR_NAME" \
         "$XDG_DATA_HOME/plasma/desktoptheme/Matrix95-$MR_NAME"
done
rm -f "$XDG_DATA_HOME/konsole/Matrix.profile"
rm -rf "$MR_WALLPAPER_DIR" "$MR_SPLASH_DIR"

# Prompt and banner: give back the user's own files, or remove ours.
orig="$MR_BACKUP/original-files"
if [ -f "$orig/starship.toml" ]; then
  cp "$orig/starship.toml" "$XDG_CONFIG_HOME/starship.toml"
elif grep -qs matrix-rice "$XDG_CONFIG_HOME/starship.toml"; then
  rm -f "$XDG_CONFIG_HOME/starship.toml"
fi
if [ -d "$orig/fastfetch" ]; then
  rm -rf "$XDG_CONFIG_HOME/fastfetch"
  cp -r "$orig/fastfetch" "$XDG_CONFIG_HOME/fastfetch"
else
  rm -f "$XDG_CONFIG_HOME/fastfetch/config.jsonc" "$XDG_CONFIG_HOME/fastfetch/matrix-logo.txt"
  rmdir "$XDG_CONFIG_HOME/fastfetch" 2>/dev/null || true
fi
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do remove_rc_block "$rc"; done
ok "terminal prompt and banner restored"

[ "$keep_login" = yes ] || login_remove

notify_kde
# Keep backups, drop everything else.
mv "$MR_ORIGINALS" "$MR_BACKUP/originals-restored-$(date +%Y%m%d-%H%M%S).tsv" 2>/dev/null || true
rm -f "$MR_BACKUP/wallpapers.tsv"
rm -rf "$MR_BACKUP/panels-original" "$MR_BACKUP/original-files"
rm -f "$MR_BIN/matrix-rice"
rm -rf "$MR_DATA/app" "$MR_DATA/icons" "$MR_CONF"

say "Uninstalled. Backups are kept in $MR_BACKUP. Log out and back in to finish."
echo "   Packages (cmatrix, fastfetch, starship, fonts, Kvantum) were left installed."
