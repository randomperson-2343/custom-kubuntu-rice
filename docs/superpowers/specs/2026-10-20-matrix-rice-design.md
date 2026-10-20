# Matrix Rice for Kubuntu 26.04: Design

Date: 2026-10-20
Target: Kubuntu 26.04.1, KDE Plasma 6 (Wayland session), Lenovo LOQ (hybrid Intel/AMD + Nvidia graphics)
Owner use cases: gaming and coding / AI / terminal work

## 1. Goal

A self-contained "Matrix" look for KDE that installs with one command, switches
between three color variants with one command, and can be fully undone.

Success looks like:

- `./install.sh green` on a fresh Kubuntu 26.04 gives a working Matrix desktop,
  lock screen, login screen and terminal, with no manual steps afterwards
  except logging out and back in once.
- `matrix-rice cyan` changes every themed piece to the new color in under
  ten seconds, without logging out.
- `./uninstall.sh` puts the previous KDE look back.
- Nothing is downloaded from the KDE Store or random websites. Only Ubuntu's
  own package repositories are used.

## 2. Decisions made with the owner

| Topic | Decision |
|---|---|
| Approach | Build everything in this repo (no third-party themes) |
| Color variants | Green (classic), Cyan / ice blue, Amber (retro terminal) |
| Motion | Live code rain wallpaper, **always running, including during games**, with an on/off toggle |
| Themed areas | KDE desktop basics, terminal + shell prompt, lock screen, login screen |
| Not included | VS Code theme, boot splash (Plymouth), rain-everywhere extras |

## 3. Palettes

Each variant is one small file in `palettes/` and is the single source of
truth for every generated config. All variants share the same near-black
background so only the "ink" color changes.

| Role | Green | Cyan | Amber |
|---|---|---|---|
| `bg` (background) | `#030A04` | `#02080B` | `#0A0602` |
| `surface` (panels, inputs) | `#08140A` | `#061218` | `#140C04` |
| `fg` (normal text) | `#00FF41` | `#00E5FF` | `#FFB000` |
| `head` (brightest glyph) | `#D8FFE0` | `#E0FBFF` | `#FFF1CC` |
| `dim` (secondary text) | `#008F11` | `#00808F` | `#996A00` |
| `faint` (borders, trails) | `#003B00` | `#00363D` | `#3D2A00` |
| `alert` (errors) | `#FF3B3B` | `#FF3B6B` | `#FF4A1C` |

Final hex values may be nudged during the build for readability, but the
roles stay fixed.

## 4. Components

### 4.1 Code rain engine (shared)

One pure Qt Quick component, `MatrixRain.qml`, with no Plasma imports, so the
exact same file powers the desktop wallpaper, the lock screen and the login
screen.

- Columns of falling glyphs: half-width katakana, digits and a few symbols,
  some mirrored, like the film.
- Each column has a bright `head` glyph, an `fg` body and a fading trail.
  Columns fall at slightly different speeds; glyphs flicker and change.
- Settings: color set, glyph size, speed, density, frame rate cap
  (default 30 fps), and enabled/disabled. When disabled it shows a still
  frame of rain instead of a blank screen.
- It never pauses for games or fullscreen windows (owner's choice).
- Rendering uses the classic "fade the whole frame slightly, draw new
  heads" technique on a Qt Quick Canvas, which keeps work per frame small
  (about one glyph per column per frame plus one translucent fill).

### 4.2 Desktop wallpaper plugin

`com.github.matrixrice.coderain`, a Plasma 6 wallpaper plugin installed to
`~/.local/share/plasma/wallpapers/`. It wraps `MatrixRain.qml` and exposes
its settings in the normal "Configure Desktop and Wallpaper" dialog. Applied
to every monitor by a Plasma shell script over D-Bus.

### 4.3 KDE desktop look

Per variant (`Matrix Green`, `Matrix Cyan`, `Matrix Amber`):

- KDE color scheme in `~/.local/share/color-schemes/`, with the accent color
  set to `fg`.
- A Global Theme (look-and-feel) package in
  `~/.local/share/plasma/look-and-feel/` so each variant is also selectable
  from System Settings > Global Theme. It sets color scheme, wallpaper
  plugin and Breeze Dark as the base Plasma style.
- Fonts: JetBrains Mono (Ubuntu package `fonts-jetbrains-mono`) for the
  fixed-width font and as the general UI font.
- Window borders: Breeze decoration with the active title bar colored from
  the palette.

### 4.4 Lock screen

The stock Plasma lock screen (Breeze), configured to use the code rain
wallpaper plugin in the active color. The clock and password box pick up the
monospace system font. No custom lock screen code, which keeps it safe:
a broken lock screen is a security problem, so we do not replace it.

### 4.5 Login screen

- The installer detects which login manager is running (SDDM expected on
  Kubuntu 26.04; Plasma Login Manager also possible).
- For SDDM: a Qt 6 SDDM theme `matrix-rice` in `/usr/share/sddm/themes/`
  with the code rain behind a centered monospace login box (user, password,
  session picker, power buttons). Activated by a drop-in file
  `/etc/sddm.conf.d/matrix-rice.conf`, so the main config is never edited.
- For Plasma Login Manager or anything else: skip with a clear message
  instead of guessing.
- Needs `sudo`. Can be skipped with `--no-login`.
- `matrix-rice <color>` updates the login screen color too (asks for sudo);
  with `--no-login` it leaves the login screen alone.

### 4.6 Terminal

- Konsole color scheme per variant plus one `Matrix` profile (JetBrains
  Mono, slight background transparency, block cursor in `fg`), set as the
  default profile.
- Starship prompt (`starship` package) with a "system console" style:
  `user@loq`, current folder, git branch, and the last command's run time,
  using plain Unicode symbols (no Nerd Font needed).
- fastfetch banner in the palette colors, shown when a new Konsole window
  opens.
- `cmatrix` installed, plus an alias `rain` that runs it in the active color.
- Shell hooks go into `~/.bashrc` (and `~/.zshrc` if it exists) between
  clearly marked `# >>> matrix-rice >>>` / `# <<< matrix-rice <<<` lines.

## 5. Commands

| Command | What it does |
|---|---|
| `./install.sh [green\|cyan\|amber] [--no-login]` | Back up current settings, install packages, install all components, apply the chosen color (default green) |
| `matrix-rice green\|cyan\|amber` | Switch every themed piece to that color |
| `matrix-rice rain on\|off` | Turn the live rain on or off (desktop and lock screen) |
| `matrix-rice status` | Show current color, rain state, login screen state |
| `./uninstall.sh` | Restore the backup, remove installed files, remove shell hooks and the SDDM drop-in |

`matrix-rice` is installed to `~/.local/bin/`.

## 6. Repo layout

```
install.sh, uninstall.sh
bin/matrix-rice                 switcher command
lib/                            shared shell functions (render, apply, backup)
palettes/{green,cyan,amber}.sh  color values (section 3)
templates/                      config files with {{placeholders}} filled from a palette
rain/MatrixRain.qml             shared rain engine
plasma/wallpaper/               wallpaper plugin package
plasma/look-and-feel/           Global Theme template
sddm/matrix-rice/               login screen theme
tests/                          automated checks
docs/                           this spec, plan, screenshots
```

## 7. Data flow

1. A palette file is loaded.
2. `lib/render` fills each template's `{{placeholders}}` from the palette and
   writes the result to its install location.
3. Apply steps tell KDE about the change: `plasma-apply-colorscheme`,
   `kwriteconfig6` for kdeglobals / kscreenlockerrc / konsolerc, and a
   Plasma D-Bus script for the wallpaper plugin settings.
4. The current color is saved to `~/.config/matrix-rice/state` so
   `matrix-rice status` and later switches know where they stand.

## 8. Safety and error handling

- Backup first: before touching anything, copy the affected configs
  (`kdeglobals`, `kscreenlockerrc`, `konsolerc`, `kwinrc`,
  `plasma-org.kde.plasma.desktop-appletsrc`, `starship.toml`,
  `fastfetch/`, `.bashrc`, `.zshrc`) to
  `~/.local/share/matrix-rice/backups/<timestamp>/`.
- Refuse to run as root (the user part must run as the user). Only the
  login screen step uses `sudo`, and only for that step.
- Check the OS and required commands up front and stop with a plain-English
  message if something is missing.
- Each step reports OK / skipped / failed. A failed optional step (login
  screen, fastfetch) does not stop the rest.
- Running the installer twice is safe: it replaces its own files and never
  duplicates the shell hooks.

## 9. Testing

Automated (runs in this repo, no KDE needed):

- `shellcheck` on every script.
- Render all three palettes and check that no `{{placeholder}}` is left and
  every generated file parses (INI-style KDE files, TOML, JSON).
- `qmllint` on the QML files where available.
- Run install and uninstall against a throwaway fake home folder with the
  KDE tools replaced by stubs, and check the right files appear, hooks are
  added once, and uninstall restores the backup.
- Render preview images of the rain in all three colors with Qt's offscreen
  mode, if Qt 6 can be installed in the build environment.

Manual (owner, on the LOQ):

- Install, log out and in, check desktop, lock screen (Meta+L), login screen,
  Konsole.
- Switch through all three colors.
- Play a game for a few minutes with rain running and note anything odd.
- Uninstall and confirm the old look returns.

## 10. Known limits

- The build environment has no KDE desktop, so real visual testing happens
  on the owner's laptop. Plan on one round of fixes after the first try.
- Rain on a Canvas is CPU-drawn. Expected cost is small at 1080p/30 fps, but
  on a 1440p or higher external monitor it may use more CPU; the frame rate
  and density settings are there for that.
- Battery life drops while unplugged because the rain never pauses.
