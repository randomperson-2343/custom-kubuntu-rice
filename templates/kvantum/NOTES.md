# Matrix95 Kvantum theme (Windows 95 widgets in Matrix colors)

## Files

| File | What | Install destination |
|---|---|---|
| `Matrix95.kvconfig` | Kvantum config template | `~/.config/Kvantum/Matrix95-{{NAME}}/Matrix95-{{NAME}}.kvconfig` |
| `Matrix95.svg` | Kvantum element sheet template (generated, do not hand-edit) | `~/.config/Kvantum/Matrix95-{{NAME}}/Matrix95-{{NAME}}.svg` |
| `tools/kvantum/gen-matrix95-svg.py` | Source of truth for `Matrix95.svg` (`python3 gen-matrix95-svg.py > Matrix95.svg`). Not installed. | n/a |
| `tools/kvantum/preview-gallery.py` | PyQt5 widget gallery used for the screenshots. Not installed. | n/a |

Render both templates with `render` per variant (this is exactly what
`lib/apply.sh` `install_variant_files` already does). Folder name, kvconfig
name and svg name must all be identical (`Matrix95-Green` etc.), otherwise
Kvantum does not find the theme.

Placeholders used: `{{NAME}}`, `{{BG}} {{SURFACE}} {{FG}} {{HEAD}} {{DIM}}
{{FAINT}} {{FACE}} {{HILITE}} {{LIGHT}} {{SHADOW}} {{DKSHADOW}} {{TITLE}}
{{TITLE_INACTIVE}} {{TITLE_INACTIVE_TEXT}}`. No other colors anywhere.
The rendered files contain no leftover `{{`.

## Activation

Package: `qt6-style-kvantum` (Kubuntu 26.04: 1.1.5). `kvantum` (the Manager
GUI) is optional and not needed.

1. `~/.config/Kvantum/kvantum.kvconfig`:
   ```
   [General]
   theme=Matrix95-Green
   ```
   (`kwriteconfig6 --file ~/.config/Kvantum/kvantum.kvconfig --group General --key theme Matrix95-Green`
   works; Kvantum reads plain INI.)
2. `kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum`
   (style key is `kvantum`; `kvantum-dark` is the same plugin asking for
   "<theme>Dark" first, not needed).
3. Keep the `Matrix{{NAME}}` KDE color scheme applied too: Kvantum paints
   Qt apps from its own `[GeneralColors]` (identical palette), but KDE apps
   that read `kdeglobals` colors directly (KColorScheme, Kirigami) need the
   scheme.
4. Running apps: Kvantum has no file watcher. The theme is read when the
   style object is created. Send the existing `notify_kde` (StyleChanged = 2)
   so plasma-integration re-creates the style [Likely]; otherwise apps pick
   up a variant switch on next start. Non-KDE Qt apps:
   `QT_STYLE_OVERRIDE=kvantum`.
5. Variant switch = rewrite `theme=` in `kvantum.kvconfig` (step 1) + notify.

## Revert

- `kdeglobals [KDE] widgetStyle` back to its saved value (`Breeze` default;
  the existing `restore_key` / `set_key kdeglobals KDE widgetStyle Breeze`).
- Remove `theme=` from `~/.config/Kvantum/kvantum.kvconfig` (or delete the
  file if we created it), and delete `~/.config/Kvantum/Matrix95-*`.
  If `kvantum.kvconfig` did not exist before install, remove it; Kvantum then
  falls back to its built-in default theme.

## Design summary (for whoever edits it)

- 1 SVG unit = 1 logical px. Every element is a group of integer-aligned
  rects (pixel art). Kvantum stretches edge elements along one axis only, so
  bevel lines stay exactly 1 px per layer at 1x and exactly 2 px at 2x
  (verified at devicePixelRatio 2).
- Raised bevel, outermost first: top/left `HILITE`, `LIGHT`; bottom/right
  `DKSHADOW`, `SHADOW`; face `FACE`. Sunken = `SHADOW`, `DKSHADOW` top/left,
  `HILITE`, `LIGHT` bottom/right. Corner rule: the top-right and bottom-left
  pixels belong to the bottom/right layers (as in Win95 DrawEdge).
- Elements (Kvantum naming `<name>-<state>[-<position>]`): `button`, `tool`
  (toggled interior is a 2x2 dither tiled via `interior.x/y.patternsize`),
  `spin`, `field`, `combo`, `combo-arrow`, `checkbox`, `radio`, `tab`,
  `tabframe` (+ `-leftjunct/-rightjunct`), `group` (etched: SHADOW + HILITE),
  `slider`, `slidercursor`, `progress` (3 px frame: 2 bevel + 1 BG pad),
  `progress-pattern` (8 px block + 2 px gap, tiled), `sbarrow` (full 16x16
  bevelled scrollbar arrow button, glyph baked in), `sbgroove` (2x2 FACE/BG
  checkerboard, tiled), `scrollbarslider`, `menu`, `menuitem`, `menubar`,
  `menubaritem`, `toolbar`, `tooltip`, `itemview`, `titlebar` + `mdi`,
  `arrow` (generic 7x4 glyphs), `tree`, `focus` (dotted), `sizegrip`.
  Fixed-name elements Kvantum always looks up (`button-default-indicator`,
  `header-separator`, `dial*`, grips) are defined (invisible or neutral) so
  no element of Kvantum's built-in blue default theme can leak in.
- Selected rows/menu items: solid `TITLE` fill with `HEAD` text (reads more
  Win95 than FG-on-BG and stays readable on all three palettes).
- Tabs: top 4 px frame; inactive tabs keep their upper 2 px transparent so
  the selected tab is 2 px taller; `attach_active_tab=true` + junction
  elements merge the active tab into the pane; `left_tabs=true`.
- Spin box: Kvantum draws the up/down buttons side by side as one joined
  button pair (the `arrow-separator-*` elements give it its left bevel edge).
- `composite=false`: no translucency, no menu/tooltip shadow (Win95 had none
  and it avoids double shadows from KWin).

## Evidence

`docs/screenshots/widgets-{green,cyan,amber}.png`, rendered offscreen with
Kvantum 1.0.10 (Qt5 build) from the rendered templates. Also inspected at
5x zoom and at devicePixelRatio 2 (crisp, no blur).

## Untested / known limits

- Only the Qt5 build of Kvantum 1.0.10 (Ubuntu 24.04) could be run here; the
  Qt6 1.1.5 build on Kubuntu 26.04 uses the same theme format and these
  keys, but was not run. [Likely fine]
- Not tried inside a real Plasma session: Dolphin, Kate, System Settings
  (Kirigami pages mostly draw their own controls and will only partly pick
  this up).
- Fractional scale factors (125%, 150%): Kvantum switches to smooth pixmap
  scaling for non-integer device pixel ratios, so the 1 px lines will look
  soft there. 100% and 200% are crisp.
- Kvantum hard-codes a 0 px label shift on press, so pressed buttons do not
  nudge their text by 1 px like real Win95.
- A progress bar that is not on a block boundary ends with a partial block
  (Kvantum tiles the pattern; there is no "whole blocks only" option).
- `QToolBox` tabs and `QDial` use Kvantum's built-in shapes/palette colors
  (circle for the dial is not pixel-stepped).
- Palette feedback for the lead (not changed by me): `LIGHT` is very close
  to `FACE` (green `#0F4A1A` vs `#0C1F10`), which makes the inner highlight
  line weak. A brighter `LIGHT` (roughly halfway to `HILITE`, e.g. green
  `#0A8A28`) makes every bevel read noticeably more 3D. `SHADOW` and
  `DKSHADOW` are nearly the same black, so sunken top/left edges are almost
  invisible against `FACE`; only the bright bottom/right edge carries the
  "sunken" cue.
