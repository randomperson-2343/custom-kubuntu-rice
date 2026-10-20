# Matrix 95 taskbar: Plasma style + panel layout

Two pieces: a Plasma 6 desktop theme ("Plasma style", SVG) and a Plasma shell
script that builds the Windows 95 style bottom panel. Verified against KDE
sources at tag `v6.6.7` of `KDE/libplasma`, `KDE/plasma-desktop`,
`KDE/plasma-workspace` (branch `Plasma/6.6`) and `KDE/ksvg` (master).

## Files and destinations

Render every file under `templates/plasma-theme/Matrix95/` with `render`
(placeholders `{{ID}} {{NAME}}` plus the palette colors) and install the tree to
one folder per variant:

    ~/.local/share/plasma/desktoptheme/Matrix95-{{NAME}}/      e.g. Matrix95-Green

| Template (under Matrix95/)         | Installed as (under the folder above) | Used for |
|---|---|---|
| `metadata.json`                    | `metadata.json` (Id = folder name = `Matrix95-{{NAME}}`) | theme list, `plasma-apply-desktoptheme` |
| `plasmarc`                         | `plasmarc`                            | contrast/blur and adaptive transparency off |
| `widgets/panel-background.svg`     | same                                  | the panel (2px raised top edge) |
| `solid/widgets/panel-background.svg` | same                                | the panel in "opaque" / "adaptive and touching a window" mode |
| `widgets/tasks.svg`                | same                                  | task buttons: normal, minimized, focus (sunken, dithered), hover, focus-hover, attention, attention-hover, launcher-hover, progress, group-expander |
| `dialogs/background.svg`, `solid/dialogs/background.svg` | same     | every popup (Kickoff, tray, calendar, notifications) |
| `widgets/tooltip.svg`, `solid/widgets/tooltip.svg` | same           | tooltips |
| `widgets/button.svg`               | same                                  | Plasma-styled push buttons and flat tool buttons |
| `widgets/frame.svg`                | same                                  | group boxes / frames (plain = etched, sunken, raised) |
| `widgets/viewitem.svg`             | same                                  | hover / selected rows in popup lists |
| `widgets/lineedit.svg`             | same                                  | text fields (Kickoff search) |
| `widgets/tabbar.svg`               | same                                  | `active-tab` = sunken marker behind the tray icon whose popup is open |

The generator lives in `tools/plasma-theme/gen-svgs.py` (not installed); run
`python3 tools/plasma-theme/gen-svgs.py` after design changes and
commit the regenerated `Matrix95/` files).

Installer sketch:

    dest="$XDG_DATA_HOME/plasma/desktoptheme/Matrix95-$MR_NAME"
    rm -rf "$dest"
    src="$MR_SRC/templates/plasma-theme/Matrix95"
    ( cd "$src" && find . -type f ) | while read -r f; do render "$src/$f" "$dest/$f"; done

`matrix-rice <color>`: render the new variant into its own folder, then run
`plasma-apply-desktoptheme Matrix95-<NewName>`. No logout needed ([Likely]:
plasmashell watches `plasmarc`; the theme name is the only thing that changes).

Shipped as a `colors` file? **No, deliberately.** A `colors` file in the theme
folder overrides the system color scheme inside Plasma. Without it the theme
"follows the color scheme" (confirmed in `ksvg` `imageset_p.cpp` and the
System Settings model), so the Matrix color scheme chosen by the other layer
keeps driving all text and icon colors in the panel and popups.

## Activation

    plasma-apply-desktoptheme Matrix95-Green      # or -Cyan / -Amber
    plasma-apply-desktoptheme --list-themes       # check it is listed

This writes `~/.config/plasmarc` group `[Theme]` key `name`. For the
installer's backup: `remember_key "$XDG_CONFIG_HOME/plasmarc" Theme name`
then `set_key ... Theme name Matrix95-Green`; revert with `restore_originals`
(an unset key means "default", i.e. Breeze).

Revert by hand: `plasma-apply-desktoptheme default` (or `breeze-dark`) and
delete `~/.local/share/plasma/desktoptheme/Matrix95-*`.

## Layout script: plasma/layout/win95-taskbar.js

Creates ONE panel: bottom edge, height 32, not floating, always visible, full
width, opaque. Applets in order: Kickoff (`org.kde.plasma.kickoff`, label
"Start" + icon), task manager with text (`org.kde.plasma.taskmanager`, no pinned
launchers, no grouping, wide buttons), system tray (`org.kde.plasma.systemtray`),
digital clock (`org.kde.plasma.digitalclock`, time only). No spacer is needed:
the task manager fills the free width. It prints the new panel id (digits only,
for example `47`) and nothing else on success. It never deletes anything.

Usage (placeholder `__START_ICON__` -> absolute path of the rendered start icon,
no `|` or `&` in the path):

    js=$(sed "s|__START_ICON__|$HOME/.local/share/matrix-rice/icons/matrix95-start.svg|" \
         "$MR_SRC/plasma/layout/win95-taskbar.js")
    panel_id=$(plasma_eval "$js")          # lib/common.sh helper, uses qdbus6

The old panels: the lead's installer should back up
`~/.config/plasma-org.kde.plasma.desktop-appletsrc` (and `plasmashellrc`)
before running this, and remove old panels afterwards (or before) with a
separate script such as `panelById(<id>).remove()` or by restoring the backup.
Because the new panel is explicitly on the bottom edge, an existing bottom
panel will sit next to it until it is removed.

Revert: `plasma_eval "panelById($panel_id).remove()"` or restore the backed-up
appletsrc and restart plasmashell (`kquitapp6 plasmashell && kstart plasmashell`).

Verified keys (Plasma/6.6 sources): Kickoff `main.xml` group `General`: `icon`
(String, an absolute path works: `main.qml` has a `startsWith("/")` image
branch) and `menuLabel` (String). Task manager `main.xml` group `General`:
`launchers`, `groupingStrategy` (0 = do not group), `maxStripes`,
`taskMaxWidth` (0/1/2 = narrow/medium/wide), `showToolTips`,
`highlightWindows`. Digital clock `main.xml` group `Appearance`: `showDate`.
`org.kde.plasma.icontasks` is the icons-only variant of the same code
(`iconsOnly: Plasmoid.pluginName === "org.kde.plasma.icontasks"`), so
`taskmanager` is the one that shows text. Panel properties used (all in
`shell/scripting/panel.cpp`): `location`, `height`, `floating`, `hiding`,
`lengthMode`, `alignment`, `opacity`. The scripting default for `floating` is
true, so the script sets it to false. `evaluateScript` returns whatever
`print()` wrote.

## How the theme was designed (research summary)

- Theme folder = `metadata.json` (KPlugin.Id must equal the folder name; Breeze
  uses `"X-Plasma-API": "5.0"`) + SVGs under `widgets/`, `dialogs/`.
  Breeze's `colors` and `plasmarc` are optional.
- Missing files fall back to the default theme (Breeze), per FILE
  (`ImageSet::imagePath`, then `fallbackImageSets = {default}`), never per
  element. Every SVG we do ship must therefore contain all elements/prefixes the
  QML asks for. Missing `translucent/` or `opaque/` selector folders are fine:
  the lookup falls back to the plain path in the same theme. `solid/...` is an
  explicit path (`Panel.qml`, `plasmaquick/dialog.cpp`, PC3 `ToolTip.qml`), so
  `solid/widgets/panel-background`, `solid/dialogs/background` and
  `solid/widgets/tooltip` MUST be shipped or Breeze's versions appear.
- Frames are 9-slices `<prefix>-{topleft,top,topright,left,center,right,
  bottomleft,bottom,bottomright}` plus `<prefix>-hint-{top,bottom,left,right}-margin`
  rects (their height/width is the content margin; the panel margins directly
  set the vertical room for the applets). A prefix is only used if
  `<prefix>-center` exists; otherwise the next one in the QML list is tried.
- Task buttons: the QML asks for `[south-<state>, <state>]` with state in
  `normal`, `minimized`, `focus` (= active window), `attention`; when hovered
  `<state>-hover`, `hover`, then the plain state. `""` (pinned launchers) only
  draws on hover via `launcher-hover`. We ship no `south-` variants, the plain
  ones are used for the bottom edge.
- Panel: prefix list `[south, ""]` plus `thick`; we ship the bottom design as
  the plain prefix and `north-`/`west-`/`east-` variants for other edges.
- `widgets/plasmoidheading` is intentionally not shipped: `PlasmoidHeading` hides
  itself when its SVG does not come from the same theme as `dialogs/background`.

## Pixel geometry

Everything is drawn from integer-coordinate `<rect>`s on a pixel grid,
`shape-rendering="crispEdges"`, no gradients, no blur, no rounded corners, no
drop shadows. Palette roles: raised = HILITE/LIGHT top-left, DKSHADOW/SHADOW
bottom-right; sunken = SHADOW/DKSHADOW top-left, HILITE/LIGHT bottom-right;
active task = sunken with a 50% FACE/LIGHT checkerboard (2x2 px tile, tiled
via `focus-hint-tile-center`); hover = HEAD outer edge; attention = ALERT outline;
tooltip = SURFACE with a 1px DKSHADOW outline and a 1px HILITE line inside it
(an addition so it is visible on a dark desktop); list rows: hover = LIGHT fill,
selected = LIGHT + 1px HILITE outline, selected+hover = LIGHT + 1px HEAD outline
(FG text on LIGHT is 5.9:1 or better in all three palettes; on TITLE amber would
be only 3.8:1, so TITLE is not used here).

Panel 32px: 2px raised top edge, applets start 4px below the top and end 2px above
the bottom (26px row). Task buttons have a 1px transparent gap on each side
(2px between buttons), 5px content margins, so the icon is 16px in a 26px
button.

## Known limits and untested aspects

1. **Start button frame and tray well cannot come from the theme.** Kickoff's
   compact representation (`main.qml`) is a bare MouseArea with icon + label and
   draws no frame; the panel containment draws no frame behind applets either, so
   the Win95 raised Start button and the sunken tray/clock well do not exist unless
   faked. The screenshots show both rows: A is what the theme really produces,
   B is the target look. Real, themed: raised/sunken task buttons, the sunken
   `widgets/tabbar` marker behind the tray icon whose popup is open, all popups.
   Possible Start fix (untested, [Likely] works): use a wide (non-square)
   start icon SVG with its own bevel baked in and `menuLabel` empty; Kickoff
   renders non-square absolute-path images with `Image.PreserveAspectFit`.
2. Never run inside a real Plasma session (no KDE desktop in the build
   container). Previews use Qt 5's `QSvgRenderer` plus a re-implementation of
   `KSvg::FrameSvg` slicing, so slice geometry/margins are verified, but how
   plasmashell lays out the real widgets (exact text positions, icon size) is
   [Likely], not seen.
3. Crispness needs an integer scale (100% / 200%). At fractional Wayland scales
   (125%, 150%) Qt rescales each slice and 1px edges will soften.
4. Kickoff's "Start" label size is chosen by Kickoff (VerticalFit, falls back
   to the default font when the panel is short); font weight/size are not themeable.
5. `launchers` is written as an empty list; if Plasma ignores an empty
   StringList write the default launchers (Settings, Discover, files, browser) appear
   as pinned buttons.
6. `hover`/`focus` overlays for `widgets/button` and `widgets/lineedit` are 1px
   rings drawn outside the control (that is how `ButtonHover`/`TextFieldFocus`
   place them); they may be clipped by tight parents.
7. Text color is never changed by the theme (it comes from the Matrix color
   scheme): active task text is not bold, selected rows keep the normal ink color.
8. Dialog content margins are 3px; Kickoff/tray content may need the lead's eye
   on a real machine. No shadows: Plasma shows popups without a drop shadow.
9. `License` in `metadata.json` is empty; set it if the repo gets a license.
