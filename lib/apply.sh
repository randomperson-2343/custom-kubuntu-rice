# shellcheck shell=bash
# Install and apply steps shared by install.sh, uninstall.sh and matrix-rice.
# Requires lib/common.sh to be sourced first.

MR_SPLASH_ID="com.github.matrixrice.splash"
MR_WALLPAPER_DIR="$XDG_DATA_HOME/plasma/wallpapers/$MR_PLUGIN_ID"
MR_SPLASH_DIR="$XDG_DATA_HOME/plasma/look-and-feel/$MR_SPLASH_ID"
MR_ICONS="$MR_DATA/icons"
MR_SDDM_DIR="${MR_SDDM_DIR:-/usr/share/sddm/themes/$MR_SDDM_THEME}"
MR_PANEL_FILES=(plasma-org.kde.plasma.desktop-appletsrc plasmashellrc)

# Text files get {{placeholders}} filled; anything else is copied as is.
_is_template() {
  case "$1" in
    *.svg|*.qml|*.rc|*.desktop|*.json|*.kvconfig|*.conf|*.colors|*.colorscheme|*.txt|*.js|*.toml|*.jsonc) return 0 ;;
    *) return 1 ;;
  esac
}

# render_tree <src-dir> <dst-dir> - render/copy a whole folder (skips NOTES.md).
render_tree() {
  local src=$1 dst=$2 f rel
  [ -d "$src" ] || return 1
  while IFS= read -r -d '' f; do
    rel=${f#"$src"/}
    [ "$(basename "$rel")" = NOTES.md ] && continue
    mkdir -p "$dst/$(dirname "$rel")"
    if _is_template "$f"; then
      render "$f" "$dst/$rel"
    else
      cp "$f" "$dst/$rel"
    fi
  done < <(find "$src" -type f -print0)
}

plasma_running() {
  plasma_eval 'print("up")' 2>/dev/null | grep -q up
}

restart_plasmashell() {
  if systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null; then
    systemctl --user restart plasma-plasmashell.service
  elif have kquitapp6; then
    kquitapp6 plasmashell >/dev/null 2>&1 || true
    sleep 1
    (setsid plasmashell >/dev/null 2>&1 &)
  fi
  local _
  for _ in $(seq 1 20); do plasma_running && return 0; sleep 0.5; done
  warn "Plasma shell did not come back by itself. Run: systemctl --user start plasma-plasmashell"
}

kwin_reconfigure() {
  if have qdbus6; then
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  else
    dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true
  fi
}

# Plasma 6.6 serves SVG window decorations from the ".v2" Aurorae plugin;
# older builds only have the plain one.
aurorae_library() {
  if [ -n "$(find /usr/lib -path '*plugins/org.kde.kdecoration*/org.kde.kwin.aurorae.v2.so' -print -quit 2>/dev/null)" ]; then
    echo org.kde.kwin.aurorae.v2
  else
    echo org.kde.kwin.aurorae
  fi
}

have_kvantum() {
  [ -n "$(find /usr/lib -path '*qt6/plugins/styles/*kvantum*' -print -quit 2>/dev/null)" ]
}

# ---------------------------------------------------------------- files

# Copies the app (scripts, templates, rain engine...) to ~/.local/share/matrix-rice/app
# and links the matrix-rice command into ~/.local/bin.
install_app() {
  local app="$MR_DATA/app" d
  rm -rf "$app.new"
  mkdir -p "$app.new"
  for d in bin lib palettes templates rain plasma sddm; do
    [ -d "$MR_SRC/$d" ] && cp -r "$MR_SRC/$d" "$app.new/"
  done
  cp "$MR_SRC/install.sh" "$MR_SRC/uninstall.sh" "$app.new/" 2>/dev/null || true
  rm -rf "$app"
  mv "$app.new" "$app"
  chmod +x "$app/bin/matrix-rice" "$app/install.sh" "$app/uninstall.sh" 2>/dev/null || true
  mkdir -p "$MR_BIN"
  ln -sf "$app/bin/matrix-rice" "$MR_BIN/matrix-rice"
  ok "matrix-rice command -> $MR_BIN/matrix-rice"
}

# Files that exist once per variant, so switching is instant.
install_variant_files() {
  local v
  for v in "${MR_VARIANTS[@]}"; do
    load_palette "$v"
    render "$MR_SRC/templates/kde/Matrix.colors" "$XDG_DATA_HOME/color-schemes/Matrix$MR_NAME.colors"
    render "$MR_SRC/templates/konsole/Matrix.colorscheme" "$XDG_DATA_HOME/konsole/Matrix$MR_NAME.colorscheme"
    if [ -d "$MR_SRC/templates/aurorae" ]; then
      local adir="$XDG_DATA_HOME/aurorae/themes/Matrix95-$MR_NAME"
      rm -rf "$adir"
      render_tree "$MR_SRC/templates/aurorae" "$adir"
      [ -f "$adir/theme.rc" ] && mv "$adir/theme.rc" "$adir/Matrix95-${MR_NAME}rc"
    fi
    if [ -d "$MR_SRC/templates/kvantum" ]; then
      local kdir="$XDG_CONFIG_HOME/Kvantum/Matrix95-$MR_NAME"
      rm -rf "$kdir"
      mkdir -p "$kdir"
      render "$MR_SRC/templates/kvantum/Matrix95.kvconfig" "$kdir/Matrix95-$MR_NAME.kvconfig"
      render "$MR_SRC/templates/kvantum/Matrix95.svg" "$kdir/Matrix95-$MR_NAME.svg"
    fi
    if [ -d "$MR_SRC/templates/plasma-theme/Matrix95" ]; then
      local pdir="$XDG_DATA_HOME/plasma/desktoptheme/Matrix95-$MR_NAME"
      rm -rf "$pdir"
      render_tree "$MR_SRC/templates/plasma-theme/Matrix95" "$pdir"
    fi
    # One Start button file per color: Plasma caches images by file name.
    if [ -f "$MR_SRC/templates/icons/matrix95-start-button.svg" ]; then
      render "$MR_SRC/templates/icons/matrix95-start-button.svg" "$MR_ICONS/matrix95-start-button-$MR_ID.svg"
    fi
  done
  ok "color schemes, terminal colors and Matrix 95 theme files for: ${MR_VARIANTS[*]}"
}

install_wallpaper_plugin() {
  rm -rf "$MR_WALLPAPER_DIR"
  mkdir -p "$(dirname "$MR_WALLPAPER_DIR")"
  cp -r "$MR_SRC/plasma/wallpaper/$MR_PLUGIN_ID" "$MR_WALLPAPER_DIR"
  cp "$MR_SRC"/rain/*.qml "$MR_WALLPAPER_DIR/contents/ui/"
  ok "code rain wallpaper plugin"
}

install_splash_package() {
  local src="$MR_SRC/plasma/look-and-feel/$MR_SPLASH_ID"
  [ -d "$src" ] || { skip "startup splash (not built)"; return 0; }
  rm -rf "$MR_SPLASH_DIR"
  mkdir -p "$MR_SPLASH_DIR"
  (cd "$src" && find . -type f ! -name NOTES.md -exec cp --parents {} "$MR_SPLASH_DIR/" \;)
  mkdir -p "$MR_SPLASH_DIR/contents/splash"
  cp "$MR_SRC"/rain/*.qml "$MR_SPLASH_DIR/contents/splash/"
  ok "startup splash package"
}

# System font: JetBrains Mono everywhere (owner approved in the spec).
apply_fonts() {
  set_key kdeglobals General font "$MR_FONT_UI"
  set_key kdeglobals General fixed "$MR_FONT_UI"
  set_key kdeglobals General menuFont "$MR_FONT_UI"
  set_key kdeglobals General toolBarFont "$MR_FONT_UI"
  set_key kdeglobals General smallestReadableFont "$MR_FONT_SMALL"
  set_key kdeglobals WM activeFont "JetBrains Mono,10,-1,5,700,0,0,0,0,0,0,0,0,0,0,1"
  ok "JetBrains Mono as system font"
}

# ---------------------------------------------------------------- apply

# shellcheck disable=SC2153 # MR_CONF comes from lib/common.sh
apply_user_configs() {
  render "$MR_SRC/templates/konsole/Matrix.profile" "$XDG_DATA_HOME/konsole/Matrix.profile"
  set_key konsolerc "Desktop Entry" DefaultProfile Matrix.profile
  render "$MR_SRC/templates/shell/matrix-rice.sh" "$MR_CONF/shell.sh"
  render "$MR_SRC/templates/starship.toml" "$XDG_CONFIG_HOME/starship.toml"
  render "$MR_SRC/templates/fastfetch/config.jsonc" "$XDG_CONFIG_HOME/fastfetch/config.jsonc"
  render "$MR_SRC/templates/fastfetch/matrix-logo.txt" "$XDG_CONFIG_HOME/fastfetch/matrix-logo.txt"
  if [ -f "$MR_SRC/templates/splash/Splash.qml" ] && [ -d "$MR_SPLASH_DIR" ]; then
    render "$MR_SRC/templates/splash/Splash.qml" "$MR_SPLASH_DIR/contents/splash/Splash.qml"
  fi
  ok "terminal profile, prompt, fastfetch banner"
}

apply_colorscheme() {
  remember_key kdeglobals General ColorScheme
  remember_key kdeglobals General AccentColor
  plasma-apply-colorscheme "Matrix$MR_NAME" >/dev/null 2>&1 || true
  plasma-apply-colorscheme --accent-color "$MR_FG" >/dev/null 2>&1 ||
    warn "could not set the accent color (plasma-apply-colorscheme --accent-color)"
  ok "KDE colors: Matrix $MR_NAME"
}

# Matrix 95 look (Windows 95 frames, widgets, taskbar style) or plain Breeze.
apply_style() {
  local style=${1:-$(state_get STYLE)}
  style=${style:-95}
  remember_key plasmarc Theme name
  remember_key kwinrc org.kde.kdecoration2 library
  remember_key kwinrc org.kde.kdecoration2 theme
  remember_key kwinrc org.kde.kdecoration2 ButtonsOnLeft
  remember_key kwinrc org.kde.kdecoration2 ButtonsOnRight
  remember_key kdeglobals KDE widgetStyle

  if [ "$style" = 95 ]; then
    if [ -d "$XDG_DATA_HOME/plasma/desktoptheme/Matrix95-$MR_NAME" ]; then
      plasma-apply-desktoptheme "Matrix95-$MR_NAME" >/dev/null 2>&1 || warn "could not apply Plasma style Matrix95-$MR_NAME"
    fi
    if [ -d "$XDG_DATA_HOME/aurorae/themes/Matrix95-$MR_NAME" ]; then
      set_key kwinrc org.kde.kdecoration2 library "$(aurorae_library)"
      set_key kwinrc org.kde.kdecoration2 theme "__aurorae__svg__Matrix95-$MR_NAME"
      set_key kwinrc org.kde.kdecoration2 ButtonsOnLeft M
      set_key kwinrc org.kde.kdecoration2 ButtonsOnRight IA_X
      kwin_reconfigure
    fi
    if have_kvantum && [ -d "$XDG_CONFIG_HOME/Kvantum/Matrix95-$MR_NAME" ]; then
      set_key "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig" General theme "Matrix95-$MR_NAME"
      set_key kdeglobals KDE widgetStyle kvantum
    else
      skip "Windows 95 widgets (Kvantum not installed)"
    fi
    ok "Matrix 95 style (window frames, widgets, Plasma style)"
  else
    plasma-apply-desktoptheme default >/dev/null 2>&1 || true
    set_key kwinrc org.kde.kdecoration2 library org.kde.breeze
    set_key kwinrc org.kde.kdecoration2 theme Breeze
    restore_key kwinrc org.kde.kdecoration2 ButtonsOnLeft
    restore_key kwinrc org.kde.kdecoration2 ButtonsOnRight
    set_key kdeglobals KDE widgetStyle Breeze
    kwin_reconfigure
    ok "plain style (Breeze shapes, Matrix colors)"
  fi
  state_set STYLE "$style"
}

# restore_key <file> <group> <key> - put one key back to its pre-install value.
restore_key() {
  local val
  val=$(original_value "$1" "$2" "$3")
  local -a gargs
  mapfile -t gargs < <(_group_args "$2")
  if [ -z "$val" ] || [ "$val" = "$MR_UNSET" ]; then
    kwrite --file "$1" "${gargs[@]}" --key "$3" --delete
  else
    kwrite --file "$1" "${gargs[@]}" --key "$3" -- "$val"
  fi
}

_animated() { [ "$(state_get RAIN)" = off ] && echo false || echo true; }

apply_lockscreen() {
  local g="Greeter/Wallpaper/$MR_PLUGIN_ID/General"
  set_key kscreenlockerrc Greeter WallpaperPlugin "$MR_PLUGIN_ID"
  set_key kscreenlockerrc "$g" Background "$MR_BG"
  set_key kscreenlockerrc "$g" Ink "$MR_FG"
  set_key kscreenlockerrc "$g" Head "$MR_HEAD"
  set_key kscreenlockerrc "$g" Dim "$MR_DIM"
  set_key kscreenlockerrc "$g" Animated "$(_animated)"
  ok "lock screen rain"
}

apply_wallpaper() {
  if ! plasma_running; then
    warn "Plasma desktop not reachable; wallpaper will be set next time you run: matrix-rice $MR_ID"
    return 0
  fi
  plasma_eval "
var id = '$MR_PLUGIN_ID';
var cfg = { Background: '$MR_BG', Ink: '$MR_FG', Head: '$MR_HEAD', Dim: '$MR_DIM', Animated: $(_animated) };
desktops().forEach(function (d) {
  d.wallpaperPlugin = id;
  d.currentConfigGroup = ['Wallpaper', id, 'General'];
  for (var k in cfg) d.writeConfig(k, cfg[k]);
});" >/dev/null
  ok "desktop wallpaper: live code rain"
}

apply_splash() {
  [ -d "$MR_SPLASH_DIR" ] || return 0
  set_key ksplashrc KSplash Engine KSplashQML
  set_key ksplashrc KSplash Theme "$MR_SPLASH_ID"
  ok "startup splash"
}

# Records each desktop's wallpaper before the first install.
remember_wallpapers() {
  local f="$MR_BACKUP/wallpapers.tsv"
  [ -f "$f" ] && return 0
  plasma_running || return 0
  mkdir -p "$MR_BACKUP"
  plasma_eval "
var out = [];
desktops().forEach(function (d) {
  d.currentConfigGroup = ['Wallpaper', d.wallpaperPlugin, 'General'];
  out.push(d.wallpaperPlugin + '\t' + d.readConfig('Image', ''));
});
print(out.join('\n'));" > "$f" || rm -f "$f"
}

restore_wallpapers() {
  local f="$MR_BACKUP/wallpapers.tsv" plugins="" images="" p img
  plasma_running || { warn "Plasma desktop not reachable; set your wallpaper again by hand"; return 0; }
  if [ -s "$f" ]; then
    while IFS=$'\t' read -r p img; do
      [ -n "$p" ] || continue
      [ "$p" = "$MR_PLUGIN_ID" ] && p=org.kde.image
      plugins+="'${p//\'/}',"
      images+="'${img//\'/}',"
    done < "$f"
  fi
  plasma_eval "
var plugins = [${plugins}], images = [${images}];
desktops().forEach(function (d, i) {
  var p = plugins[i] || 'org.kde.image';
  d.wallpaperPlugin = p;
  if (p === 'org.kde.image' && images[i]) {
    d.currentConfigGroup = ['Wallpaper', p, 'General'];
    d.writeConfig('Image', images[i]);
  }
});" >/dev/null
  ok "previous wallpaper restored"
}

set_rain() {
  local on=$1
  state_set RAIN "$on"
  local v
  v=$(state_get COLOR)
  load_palette "${v:-green}"
  apply_lockscreen >/dev/null
  apply_wallpaper >/dev/null
  ok "live rain: $on"
}

# ---------------------------------------------------------------- taskbar

# Windows 95 taskbar: replaces bottom panels with Start + named tasks + tray.
taskbar_on() {
  local js="$MR_SRC/plasma/layout/win95-taskbar.js" orig="$MR_BACKUP/panels-original" f id
  [ -f "$js" ] || { skip "taskbar (layout not built)"; return 0; }
  plasma_running || { warn "Plasma desktop not reachable; run 'matrix-rice taskbar on' from inside your desktop"; return 0; }
  if [ ! -d "$orig" ]; then
    mkdir -p "$orig"
    for f in "${MR_PANEL_FILES[@]}"; do
      [ -f "$XDG_CONFIG_HOME/$f" ] && cp "$XDG_CONFIG_HOME/$f" "$orig/"
    done
  fi
  local v icon
  v=$(state_get COLOR)
  icon="$MR_ICONS/matrix95-start-button-${v:-green}.svg"
  plasma_eval "panels().forEach(function (p) { if (p.location === 'bottom') p.remove(); });" >/dev/null
  id=$(plasma_eval "$(sed "s|__START_ICON__|$icon|g" "$js")" | tr -dc '0-9\n' | tail -n 1)
  state_set TASKBAR on
  state_set TASKBAR_PANEL "$id"
  ok "Windows 95 taskbar (old panel layout saved)"
}

# Points the Start button at the current color's image.
recolor_start_button() {
  [ "$(state_get TASKBAR)" = on ] || return 0
  plasma_running || return 0
  plasma_eval "
panels().forEach(function (p) {
  p.widgets('org.kde.plasma.kickoff').forEach(function (w) {
    w.currentConfigGroup = ['General'];
    if (String(w.readConfig('icon', '')).indexOf('matrix95-start-button') >= 0) {
      w.writeConfig('icon', '$MR_ICONS/matrix95-start-button-$MR_ID.svg');
      w.reloadConfig();
    }
  });
});" >/dev/null
}

# Puts the panel layout from before `taskbar on` back.
taskbar_off() {
  local orig="$MR_BACKUP/panels-original" f
  [ -d "$orig" ] || { skip "taskbar was never switched on"; return 0; }
  if systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null; then
    systemctl --user stop plasma-plasmashell.service
  else
    kquitapp6 plasmashell >/dev/null 2>&1 || true
    sleep 1
  fi
  for f in "${MR_PANEL_FILES[@]}"; do
    if [ -f "$orig/$f" ]; then cp "$orig/$f" "$XDG_CONFIG_HOME/$f"; else rm -f "$XDG_CONFIG_HOME/$f"; fi
  done
  restart_plasmashell
  state_set TASKBAR off
  ok "original panel layout restored"
}

# ---------------------------------------------------------------- login screen

sddm_render_conf() {
  local tmp
  tmp=$(mktemp)
  render "$MR_SRC/templates/sddm/theme.conf" "$tmp"
  printf '%s' "$tmp"
}

login_install() {
  local lm
  lm=$(detect_login_manager)
  if [ "$lm" != sddm ]; then
    skip "login screen: this machine uses '$lm', not SDDM. Leaving it alone."
    return 0
  fi
  say "Installing the login screen theme (needs your password once)"
  sudo -v || { warn "no sudo, skipping login screen"; return 0; }
  local conf
  conf=$(sddm_render_conf)
  sudo rm -rf "$MR_SDDM_DIR"
  sudo install -d -m 755 "$MR_SDDM_DIR"
  sudo find "$MR_SRC/sddm/$MR_SDDM_THEME" -maxdepth 1 -type f ! -name NOTES.md ! -name theme.conf \
    -exec install -m 644 {} "$MR_SDDM_DIR/" \;
  sudo install -m 644 "$MR_SRC"/rain/*.qml "$MR_SDDM_DIR/"
  sudo install -m 644 "$conf" "$MR_SDDM_DIR/theme.conf"
  rm -f "$conf"
  sudo install -d -m 755 "$(dirname "$MR_SDDM_DROPIN")"
  printf '# Added by matrix-rice. Remove this file to restore the previous login theme.\n[Theme]\nCurrent=%s\n' \
    "$MR_SDDM_THEME" | sudo tee "$MR_SDDM_DROPIN" >/dev/null
  if grep -qs '^Current=' /etc/sddm.conf; then
    warn "/etc/sddm.conf sets its own theme and wins over matrix-rice. Remove its [Theme] Current= line to use the Matrix login."
  fi
  state_set LOGIN on
  ok "login screen theme (preview it with: sddm-greeter-qt6 --test-mode --theme $MR_SDDM_DIR)"
}

login_recolor() {
  [ "$(state_get LOGIN)" = on ] || return 0
  [ -d "$MR_SDDM_DIR" ] || return 0
  say "Recoloring the login screen (needs your password)"
  local conf
  conf=$(sddm_render_conf)
  if sudo install -m 644 "$conf" "$MR_SDDM_DIR/theme.conf"; then
    ok "login screen: Matrix $MR_NAME"
  else
    warn "login screen color not changed"
  fi
  rm -f "$conf"
}

login_remove() {
  [ -d "$MR_SDDM_DIR" ] || [ -f "$MR_SDDM_DROPIN" ] || return 0
  say "Removing the login screen theme (needs your password)"
  sudo rm -rf "$MR_SDDM_DIR" "$MR_SDDM_DROPIN" && ok "login screen back to your previous theme"
  state_set LOGIN off
}

# ---------------------------------------------------------------- everything

# apply_variant <color> [--no-login]
apply_variant() {
  local v=$1 login=${2:-}
  load_palette "$v"
  say "Applying Matrix $MR_NAME"
  apply_user_configs
  apply_colorscheme
  apply_style "$(state_get STYLE)"
  apply_lockscreen
  apply_wallpaper
  apply_splash
  state_set COLOR "$v"
  recolor_start_button
  notify_kde
  [ "$login" = --no-login ] || login_recolor
}
