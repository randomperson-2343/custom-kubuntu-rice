# Matrix 95 startup splash + login screen: install and test notes

Verified against KDE/plasma-workspace branch `Plasma/6.6` (ksplash/ksplashqml/*,
libklookandfeel/klookandfeelmanager.cpp, shell/packageplugins/lookandfeel/lookandfeel.cpp,
lookandfeel/org.kde.breeze/) and sddm/sddm master (GreeterApp.cpp).

## A. Startup splash (KSplash)

Package: `plasma/look-and-feel/com.github.matrixrice.splash/`
- `metadata.json`: `KPackageStructure: "Plasma/LookAndFeel"`, `KPlugin.Id: "com.github.matrixrice.splash"`,
  `X-Plasma-APIVersion: "2"` (same shape as Breeze's metadata.json).
- Entry script the package structure expects: `contents/splash/Splash.qml`
  (`splashmainscript`). Nothing else is required; no defaults file, so it is
  never offered as a full global theme that changes other settings.

Install destination (per user, no root):
`~/.local/share/plasma/look-and-feel/com.github.matrixrice.splash/`
- copy `metadata.json` as is
- `contents/splash/Splash.qml` = `templates/splash/Splash.qml` rendered with the palette
  (placeholders used: BG SURFACE FG HEAD DIM FAINT HILITE)
- `contents/splash/MatrixRain.qml` + `MatrixGlow.qml` copied from `rain/` (the
  splash uses `MatrixRain` with `glow: false`, so MatrixGlow.qml is only carried along)
  This is exactly what `lib/apply.sh` (`install_splash_package`, `apply_user_configs`) already does.

Activate (ksplashrc, group `[KSplash]`, keys `Engine` and `Theme`; this is what
KLookAndFeelManager::setSplashScreen writes, and what ksplashqml/startplasma read):

    kwriteconfig6 --file ksplashrc --group KSplash --key Engine KSplashQML
    kwriteconfig6 --file ksplashrc --group KSplash --key Theme com.github.matrixrice.splash

Revert: put back the values that were there before (lib/common.sh `set_key` remembers
them). By hand, Breeze is `Theme=org.kde.breeze.desktop`, `Engine=KSplashQML`.
Do not just delete `Theme` on a machine whose default comes from a look-and-feel
`defaults` file: ksplashqml then falls back to the literal name "Breeze" [Guessing
that it resolves; use the explicit value instead]. Then delete the package folder.

Recolor: re-render `Splash.qml` into the installed folder (colors are baked in at
render time). No restart needed; it is read on the next login.

Test on the real machine (no logout needed):

    ksplashqml --test --window com.github.matrixrice.splash
    # or straight from a folder (the theme argument may be an id or a path):
    ksplashqml --test --window ~/.local/share/plasma/look-and-feel/com.github.matrixrice.splash

`--test` steps the stage every 2 s (3, 4, 5; at 6 the app exits), a click or Esc
closes it; `--window` keeps it a normal window instead of a fullscreen overlay.
Debug output: `QT_LOGGING_RULES="org.kde.plasma.ksplashqml.debug=true"`.
(Plasma 6.6 source: options `--test`, `--window`, `--nofork`, `--pid`, positional `theme`.)

Stage contract [Certain, from splashapp.cpp/splashwindow.cpp]: the root item gets an
int property `stage`. Order: 1 initial, 2 startplasma/wm, 3, 4, 5, then 6 =
desktop ready, which calls `QGuiApplication::exit()` (window disappears at once).
On Wayland `initial` and `wm` both fire inside the app, so the first stage QML
sees is 2. The property can be 0 until the first stage arrives. Splash.qml
therefore starts its fade-in on load (not on a stage) and starts a 350 ms fade-out
at `stage >= 5`. If stage 6 follows within 350 ms the fade is cut; that is
unavoidable because the window is destroyed. The window has an alpha buffer, so
the fade reveals whatever is behind it (the starting desktop).

Not tested here (no KDE in the container): the real `ksplashqml`, layer-shell,
and the 30 s auto-close timer. Qt 6.4 (`qml`) and PySide6/Qt 6.12 both load the
rendered file. Fonts: wordmark asks for `Arial` (fontconfig maps it to Liberation
Sans or the default sans), status text uses `JetBrains Mono`. Cost: one 24 fps
MatrixRain canvas without glow, ~80 small rectangles for the flag, ~190 static
rectangles in the bar sliding by one NumberAnimation.

Preview and screenshots (any machine with Qt 6 `qml`):

    # render the template + rain files into a folder, then:
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
      qml tests/splash-preview.qml -- <dir with Splash.qml> <out.png> still 1280x720
    ... gif <out-dir> 1280x720   # frames + real timestamps, then ffmpeg palettegen
    ... fade <out.png>           # grab during the stage-5 fade-out

## B. Login screen (SDDM)

Files: `sddm/matrix-rice/Main.qml` (single file, only plain QtQuick + SDDM context
objects), `templates/sddm/theme.conf` (new keys `face hilite light shadow dkshadow
title titleinactive titleinactivetext`, filled from palette placeholders). If a
theme.conf without the new keys is installed, Main.qml falls back to the old keys.
Install as before: `Main.qml`, `metadata.desktop`, `MatrixRain.qml`,
`MatrixGlow.qml` and the rendered `theme.conf` into `/usr/share/sddm/themes/matrix-rice/`.

Test the installed theme (SDDM greeter test mode, a window on the current session):

    sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/matrix-rice

(Options `--test-mode`, `--theme <path>` confirmed in SDDM's GreeterApp.cpp.) In
test mode the mock `sddm.login` always fails, so you also see the error state.

Offscreen preview with mock SDDM objects (the rendered theme.conf is read via XHR):

    QML_XHR_ALLOW_FILE_READ=1 QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
      qml tests/sddm-preview.qml -- <out.png> <theme-dir> <theme-dir>/theme.conf [fail|shutdown|early] [WxH]

Behavior: Win95 "Welcome to Matrix 95" dialog; Tab order user name, password,
session list (only when more than one session), OK, Shut Down; Enter in the user
field moves to the password, Enter in the password field or on OK logs in; failed
login shakes the dialog and shows the message in ALERT; the title-bar x only clears
the password. "Shut Down" opens a modal "Shut Down Matrix 95" (Shut down / Restart /
Suspend, only the ones SDDM reports as available, Yes/No, Esc cancels), so nothing
powers off without a second explicit Yes. Keyboard flow was exercised with
synthetic key events under PySide6 (Qt 6.12), not on a real greeter.
Integer UI scale is `round(min(w,h)/540)`: 1x at 720p, 2x at 1080p, 3x at 1440p.
The caret uses a custom I-beam delegate and blinks at the system cursor flash time.
