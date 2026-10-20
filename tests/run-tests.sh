#!/usr/bin/env bash
# Automated checks that run without a KDE desktop:
#   1. shellcheck on every script
#   2. every template renders for every color, with valid TOML/JSON/XML/INI
#   3. palette text contrast
#   4. QML renders offscreen (rain, login screen)
#   5. full install -> switch -> taskbar -> uninstall in a throwaway HOME,
#      with KDE tools replaced by logging stand-ins (stubs)
# shellcheck disable=SC2016,SC2015 # stubs are single-quoted on purpose
set -uo pipefail

ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
WORK=$(mktemp -d)
trap '[ -n "${KEEP:-}" ] && echo "kept $WORK" || rm -rf "$WORK"' EXIT
fails=0
pass() { printf '  \e[32mPASS\e[0m %s\n' "$*"; }
fail() { printf '  \e[31mFAIL\e[0m %s\n' "$*"; fails=$((fails + 1)); }
check() { local msg=$1; shift; if "$@"; then pass "$msg"; else fail "$msg"; fi; }

echo "== 1. shellcheck"
check "all scripts lint clean" shellcheck -x -P SCRIPTDIR/.. \
  "$ROOT"/install.sh "$ROOT"/uninstall.sh "$ROOT"/bin/matrix-rice "$ROOT"/lib/*.sh \
  "$ROOT"/palettes/*.sh "$ROOT"/templates/shell/matrix-rice.sh "$ROOT"/tests/run-tests.sh

echo "== 2. templates"
(
  MR_SRC=$ROOT
  # shellcheck source=lib/common.sh
  . "$ROOT/lib/common.sh"
  for v in "${MR_VARIANTS[@]}"; do
    load_palette "$v"
    while IFS= read -r -d '' f; do
      rel=${f#"$ROOT"/templates/}
      case "$f" in *NOTES.md|*.png) continue ;; esac
      render "$f" "$WORK/render/$v/$rel" || exit 1
    done < <(find "$ROOT/templates" -type f -print0)
  done
) && pass "all templates render for green, cyan, amber (no leftover placeholders)" || fail "template rendering"

python3 -I - "$WORK/render" <<'PY' && pass "rendered TOML / JSON / SVG / INI files parse" || fail "rendered files parse"
import sys, pathlib, json, tomllib, configparser, xml.etree.ElementTree as ET
bad = 0
for p in pathlib.Path(sys.argv[1]).rglob("*"):
    if not p.is_file():
        continue
    try:
        if p.suffix == ".toml":
            tomllib.loads(p.read_text())
        elif p.suffix in (".json", ".jsonc"):
            json.loads(p.read_text())
        elif p.suffix == ".svg":
            ET.parse(p)
        elif p.suffix in (".colors", ".colorscheme", ".kvconfig", ".conf", ".rc", ".desktop", ".profile"):
            c = configparser.RawConfigParser(strict=False, interpolation=None, comment_prefixes=("#", ";"))
            c.optionxform = str
            c.read_string(p.read_text())
    except Exception as e:  # noqa: BLE001
        print(f"    {p}: {e}")
        bad += 1
sys.exit(1 if bad else 0)
PY

echo "== 3. contrast"
python3 -I - "$ROOT/palettes" <<'PY' && pass "text contrast >= 4.5:1 on backgrounds (WCAG AA)" || fail "palette contrast"
import re, sys, pathlib
def lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def cr(a, b):
    hi, lo = sorted([lum(a), lum(b)], reverse=True)
    return (hi + 0.05) / (lo + 0.05)
bad = 0
for f in sorted(pathlib.Path(sys.argv[1]).glob("*.sh")):
    v = dict(re.findall(r'MR_(\w+)="(#[0-9A-Fa-f]{6})"', f.read_text()))
    pairs = [("FG", "BG"), ("HEAD", "BG"), ("FG", "SURFACE"), ("FG", "FACE"), ("HEAD", "TITLE"),
             ("DIM", "BG"), ("BG", "FG"), ("TITLE_INACTIVE_TEXT", "TITLE_INACTIVE")]
    for a, b in pairs:
        r = cr(v[a], v[b])
        if r < 4.5:
            print(f"    {f.stem}: {a} on {b} = {r:.1f}")
            bad += 1
sys.exit(1 if bad else 0)
PY

echo "== 4. QML offscreen renders"
QML=/usr/lib/qt6/bin/qml
if [ -x "$QML" ]; then
  export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$WORK/run"
  mkdir -p "$WORK/run" && chmod 700 "$WORK/run"
  (cd "$ROOT" && timeout 30 "$QML" tests/preview.qml -- "$WORK/rain.png" "#030A04" "#00FF41" "#D8FFE0" "#009A14" >/dev/null 2>&1)
  check "code rain renders" test -s "$WORK/rain.png"
  mkdir -p "$WORK/sddm"
  cp "$ROOT"/sddm/matrix-rice/* "$ROOT"/rain/*.qml "$WORK/sddm/"
  (cd "$ROOT" && timeout 30 "$QML" tests/sddm-preview.qml -- "$WORK/login.png" "$WORK/sddm" \
     "#030A04" "#08140A" "#00FF41" "#D8FFE0" "#009A14" "#003B00" "#FF3B3B" >/dev/null 2>&1)
  check "login screen renders" test -s "$WORK/login.png"
else
  echo "  (skipped: Qt 6 qml runner not installed)"
fi

echo "== 5. install / switch / uninstall in a fake home"
H="$WORK/home"
STUB="$WORK/stubs"
LOG="$WORK/calls.log"
mkdir -p "$H/.config" "$STUB" "$WORK/sys/etc"
printf '# my bashrc\nalias ll="ls -l"\n' > "$H/.bashrc"
cp "$H/.bashrc" "$WORK/bashrc.orig"
printf '[General]\nfont=Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\nColorScheme=BreezeDark\n' > "$H/.config/kdeglobals"
printf 'my own prompt\n' > "$H/.config/starship.toml"
printf '[Containments][1]\nplugin=org.kde.panel\n' > "$H/.config/plasma-org.kde.plasma.desktop-appletsrc"
cp "$H/.config/plasma-org.kde.plasma.desktop-appletsrc" "$WORK/appletsrc.orig"

stub() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$STUB/$1"; chmod +x "$STUB/$1"; }
stub kwriteconfig6 'exec kwriteconfig5 "$@"'
stub kreadconfig6 'exec kreadconfig5 "$@"'
stub plasma-apply-colorscheme 'echo "colorscheme $*" >> "$LOG"'
stub plasma-apply-desktoptheme 'echo "desktoptheme $*" >> "$LOG"'
stub qdbus6 'echo "qdbus $1 $2 $3" >> "$LOG"; s="${4:-}"
case "$s" in
  *"print(\"up\")"*) echo up ;;
  *"out.join"*) printf "org.kde.image\tfile:///usr/share/wallpapers/Next/\n" ;;
  *"new Panel"*) echo "panel script" >> "$LOG"; echo 42 ;;
  *wallpaperPlugin*) echo "wallpaper script: $(echo "$s" | grep -o "Ink: .#[0-9A-F]*.")" >> "$LOG" ;;
esac'
stub sudo '[ "${1:-}" = -v ] && exit 0; exec "$@"'
stub systemctl 'echo "systemctl $*" >> "$LOG"; exit 1'
stub kquitapp6 'echo "kquitapp6 $*" >> "$LOG"'
stub plasmashell 'exit 0'
stub dbus-send 'exit 0'
stub id 'if [ "${1:-}" = -u ]; then echo 1000; else /usr/bin/id "$@"; fi'
stub sleep 'exit 0'

run() {
  env -i HOME="$H" PATH="$STUB:/usr/bin:/bin" LOG="$LOG" XDG_CURRENT_DESKTOP=KDE TERM=dumb \
    MR_SDDM_DIR="$WORK/sys/sddm-theme" MR_SDDM_DROPIN="$WORK/sys/etc/sddm.conf.d/zz-matrix-rice.conf" \
    MR_LOGIN_MANAGER=sddm "$@"
}
kr() { kreadconfig5 --file "$H/.config/$1" --group "$2" --key "$3"; }

if run "$ROOT/install.sh" cyan --no-packages --yes > "$WORK/install.log" 2>&1; then
  pass "install.sh cyan finishes"
else
  fail "install.sh cyan (log below)"; sed 's/^/    /' "$WORK/install.log"
fi
D="$H/.local/share"
check "color schemes installed for all 3 colors" test -f "$D/color-schemes/MatrixGreen.colors" -a -f "$D/color-schemes/MatrixCyan.colors" -a -f "$D/color-schemes/MatrixAmber.colors"
check "wallpaper plugin has the rain engine" test -f "$D/plasma/wallpapers/com.github.matrixrice.coderain/contents/ui/MatrixRain.qml"
check "matrix-rice command linked" test -x "$H/.local/bin/matrix-rice"
check "Cyan color scheme applied" grep -q "colorscheme MatrixCyan" "$LOG"
check "wallpaper set to Cyan ink" grep -q "Ink: '#00E5FF'" "$LOG"
check "lock screen uses rain plugin" test "$(kr kscreenlockerrc Greeter WallpaperPlugin)" = com.github.matrixrice.coderain
check "Konsole default profile set" test "$(kr konsolerc 'Desktop Entry' DefaultProfile)" = Matrix.profile
check "system font is JetBrains Mono" grep -q "^font=JetBrains Mono" "$H/.config/kdeglobals"
check "starship prompt is the Matrix one" grep -q "Matrix Cyan" "$H/.config/starship.toml"
check "shell hook added to .bashrc" test "$(grep -c '>>> matrix-rice >>>' "$H/.bashrc")" = 1
check "login theme installed with Cyan colors" grep -q "ink=#00E5FF" "$WORK/sys/sddm-theme/theme.conf"
check "SDDM drop-in selects the theme" grep -q "Current=matrix-rice" "$WORK/sys/etc/sddm.conf.d/zz-matrix-rice.conf"

run "$ROOT/install.sh" cyan --no-packages --yes > "$WORK/install2.log" 2>&1
check "second install keeps exactly one shell hook" test "$(grep -c '>>> matrix-rice >>>' "$H/.bashrc")" = 1
check "second install keeps the original font remembered" grep -q "Noto Sans" "$D/matrix-rice/backups/originals.tsv"

run "$H/.local/bin/matrix-rice" amber > "$WORK/switch.log" 2>&1
check "switch to amber: colors" grep -q "colorscheme MatrixAmber" "$LOG"
check "switch to amber: prompt" grep -q "Matrix Amber" "$H/.config/starship.toml"
check "switch to amber: login screen" grep -q "ink=#FFB000" "$WORK/sys/sddm-theme/theme.conf"
check "state remembers amber" grep -q "COLOR=amber" "$H/.config/matrix-rice/state"

run "$H/.local/bin/matrix-rice" rain off > /dev/null 2>&1
check "rain off reaches lock screen" test "$(kreadconfig5 --file "$H/.config/kscreenlockerrc" --group Greeter --group Wallpaper --group com.github.matrixrice.coderain --group General --key Animated)" = false

if [ -f "$ROOT/plasma/layout/win95-taskbar.js" ]; then
  run "$H/.local/bin/matrix-rice" taskbar on > /dev/null 2>&1
  check "taskbar on stores the panel id" grep -q "TASKBAR_PANEL=42" "$H/.config/matrix-rice/state"
  printf 'changed by taskbar\n' >> "$H/.config/plasma-org.kde.plasma.desktop-appletsrc"
fi

if run "$H/.local/share/matrix-rice/app/uninstall.sh" > "$WORK/uninstall.log" 2>&1; then
  pass "uninstall.sh finishes"
else
  fail "uninstall.sh (log below)"; sed 's/^/    /' "$WORK/uninstall.log"
fi
check "uninstall: .bashrc back to the original" cmp -s "$H/.bashrc" "$WORK/bashrc.orig"
check "uninstall: original font back" grep -q "^font=Noto Sans" "$H/.config/kdeglobals"
check "uninstall: original color scheme re-applied" grep -q "colorscheme BreezeDark" "$LOG"
check "uninstall: own starship.toml restored" grep -q "my own prompt" "$H/.config/starship.toml"
check "uninstall: panel layout restored" cmp -s "$H/.config/plasma-org.kde.plasma.desktop-appletsrc" "$WORK/appletsrc.orig"
check "uninstall: lock screen plugin key removed" test -z "$(kr kscreenlockerrc Greeter WallpaperPlugin)"
check "uninstall: theme files removed" test ! -e "$D/color-schemes/MatrixCyan.colors" -a ! -e "$D/plasma/wallpapers/com.github.matrixrice.coderain"
check "uninstall: login theme removed" test ! -e "$WORK/sys/sddm-theme" -a ! -e "$WORK/sys/etc/sddm.conf.d/zz-matrix-rice.conf"
check "uninstall: command removed, backups kept" test ! -e "$H/.local/bin/matrix-rice" -a -d "$D/matrix-rice/backups"

echo
if [ "$fails" -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "$fails TEST(S) FAILED"; exit 1; fi
