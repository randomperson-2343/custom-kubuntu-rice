# Matrix 95 window decoration (Aurorae)

Windows 95 window frames in Matrix colors: 4px raised bevel frame, solid title
bar, bevelled minimize / maximize (restore) / close buttons. Pure SVG, no code.
Previews: `docs/screenshots/decoration-{green,cyan,amber}.png`.

## Format facts (verified against KDE sources, Plasma/6.6 tag 6.6.7)

- Aurorae is NOT in the kwin repo any more. It is `KDE/aurorae`
  (`v2/` = the SVG engine, `v1/` = the QML engine). The kwin repo only holds the
  bridge (`src/decorations/decorationbridge.cpp`).
- SVG themes are served by the **v2** plugin `org.kde.kwin.aurorae.v2`
  (file `org.kde.kwin.aurorae.v2.so` in `.../plugins/org.kde.kdecoration3/`).
  `decorationbridge.cpp` migrates `library=org.kde.kwin.aurorae` +
  `theme=__aurorae__svg__*` to `.v2` only once at KWin start-up, so write `.v2`
  directly.
- Theme folder: `~/.local/share/aurorae/themes/<Name>/` (also found under any
  `$XDG_DATA_DIRS`). Files read by `v2/decorationtheme.cpp`:
  `decoration.svg` (required), `minimize.svg`, `maximize.svg`, `restore.svg`,
  `close.svg`, `help.svg`, `alldesktops.svg`, `keepabove.svg`, `keepbelow.svg`,
  `shade.svg`, `menu.svg`, `appmenu.svg` (all optional; `.svgz` also accepted),
  `<Name>rc` (KConfig file) and `metadata.desktop`.
- Metadata is `metadata.desktop` (`[Desktop Entry]` `Name=`). A folder without it
  is skipped with a warning (`v2/decorationthemeprovider.cpp`). There is no
  `metadata.json` for SVG themes.
- `decoration.svg` is read as KSvg FrameSvg sets with element prefixes
  `decoration`, `decoration-inactive`, `decoration-maximized`,
  `decoration-maximized-inactive` (the last three fall back if absent).
  Element ids are `<prefix>-center|top|bottom|left|right|topleft|topright|bottomleft|bottomright`.
  Optional: `innerborder[-inactive]-*`, `mask-*` (blur region), `hint-*`.
  Margins come from the element sizes: top element height = window top border
  (26px), left/right/bottom widths = 4px. Straight pieces are tiled at native
  size (no `hint-stretch-borders`), maximized windows only draw `*-center`.
- Button SVGs use prefixes `active`, `hover`, `pressed`, `deactivated`,
  `inactive`, `hover-inactive`, `pressed-inactive`, `deactivated-inactive`
  (element `<prefix>-center`; only `active-center` is required, the rest fall
  back in that order, see `SvgFrameSet::select` in `v2/decorationbutton.cpp`).
  Each center is stretched to ButtonWidth x ButtonHeight (20x18 here = 1:1).
- If there is no `menu.svg` the window's own icon is painted into the menu
  button (what we want for the Win95 system-menu icon).
- `<Name>rc` keys: `[General]` TitleAlignment, TitleVerticalAlignment,
  ActiveTextColor, InactiveTextColor (`r,g,b` or `#rrggbb`), Animation,
  ButtonGroupHover. `[Layout]` Border{Left,Right,Bottom,Top},
  TitleEdge{Top,Bottom,Left,Right}[Maximized], TitleBorder{Left,Right},
  TitleHeight, ButtonWidth[Minimize|MaximizeRestore|Close|Menu|AppMenu|...],
  ButtonHeight, ButtonSpacing, ButtonMarginTop[Maximized], ExplicitButtonSpacer,
  Padding{Left,Right,Top,Bottom}. v2 multiplies Layout values by
  `logicalDotsPerInchX/96`.
- Border sizes are clamped by KWin's border size setting (Normal 4..6, Tiny
  1..4), so 4px is valid for Tiny and Normal. Padding is 0, so there is no
  decoration shadow (Win95 had none).
- Title text is painted by KWin with the system title font (kdeglobals `[WM]
  activeFont`, already bold in lib/apply.sh). Aurorae cannot set the weight.

## Files and install destinations

Render each template with `render` (palette loaded), into
`$XDG_DATA_HOME/aurorae/themes/Matrix95-<Name>/` (e.g. `Matrix95-Green`):

| Template | Destination file |
|---|---|
| `templates/aurorae/decoration.svg` | `decoration.svg` |
| `templates/aurorae/minimize.svg` | `minimize.svg` |
| `templates/aurorae/maximize.svg` | `maximize.svg` |
| `templates/aurorae/restore.svg` | `restore.svg` |
| `templates/aurorae/close.svg` | `close.svg` |
| `templates/aurorae/help.svg` | `help.svg` |
| `templates/aurorae/theme.rc` | `Matrix95-<Name>rc` (name must equal folder name + `rc`) |
| `templates/aurorae/metadata.desktop` | `metadata.desktop` |

NOTES.md is not part of the theme; do not install it.

Start-button logo: `templates/icons/matrix95-start.svg` -> render, then install as
`$XDG_DATA_HOME/icons/hicolor/scalable/apps/matrix95-start.svg` (icon name
`matrix95-start`, use per palette, e.g. keep one active file and overwrite on
`matrix-rice <variant>`), or point the Kickoff/Application Launcher
"icon" setting at the rendered file path directly. Update the icon cache with
`gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor` if present
(optional, not needed for a direct path).

## Activate

```
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae.v2
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme   __aurorae__svg__Matrix95-Green
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft  M
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight IA_X
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSize Normal
qdbus6 org.kde.KWin /KWin reconfigure
```

- The group is still called `org.kde.kdecoration2` in Plasma 6.6.
- Button letters: M menu, I minimize, A maximize/restore, X close, `_` spacer
  (width `ExplicitButtonSpacer`=2px, gives the Win95 gap before the close
  button; with `IAX` the three buttons just touch), H help, S all desktops,
  F keep above, B keep below, L shade. Only M, I, A, X, H, `_` have art here;
  letters without an SVG are simply not drawn.
- Optional one-shot alternative that validates the theme name:
  `<libexec>/kwin-applywindowdecoration __aurorae__svg__Matrix95-Green`
  (also `--list-themes`).
- lib/apply.sh currently writes `library org.kde.kwin.aurorae` and `IAX`.
  Suggested change: library `org.kde.kwin.aurorae.v2` and `IA_X`. Safe fallback
  if the `.v2` plugin file is absent (older Plasma): keep `org.kde.kwin.aurorae`
  (the v1 plugin also loads `__aurorae__svg__` themes through QML).
- Switching variant: write the new `theme` value (`Matrix95-Cyan` etc.), then
  reconfigure. Do not rely on re-rendering files in place under the same theme
  name: the SVG cache may keep the old colors until KWin restarts [Guessing].

## Revert

```
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.breeze
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme Breeze
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft  --delete
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight --delete
qdbus6 org.kde.KWin /KWin reconfigure
rm -rf ~/.local/share/aurorae/themes/Matrix95-*
```

(`--delete` restores KWin's default button layout, which is what a stock
install has. Better: use the remembered originals from lib/common.sh.)

## Tested / not tested

Tested here (no KDE desktop in the container):
- All templates render through `render` for green, cyan, amber (no leftover
  placeholders).
- Real Qt SVG renderer (QtSvg, PyQt5) parses every file, finds every element id
  and reports exact bounding boxes (pieces 4x26, 16x26, 4x4, buttons 20x18...);
  its output is byte-identical to rsvg-convert, including tiled/stretched
  pieces, so the mock previews match what KSvg will paint at 100% scale.
- Previews are a Python mock of KSvg FrameSvg composition (not KWin itself).

Not tested (needs a real Plasma 6.6 session):
- [Likely] The v2 plugin loading this theme and button hit-testing. All
  config keys and ids were checked against the v2 source, so this should work.
- [Likely] Crisp pixels need 100% or 200% display scale. At fractional scales
  KSvg renders at scale*size and the 1px lines will be resampled (blurry).
- [Guessing] On a Wayland session where Qt reports `logicalDotsPerInchX != 96`
  Aurorae scales all Layout values; at 96 it is 1.0.
- Menu button: shows the app icon (18x18 cell). Apps without an icon get
  KWin's generic one.
- Not provided: `alldesktops`, `keepabove`, `keepbelow`, `shade`, `appmenu`
  art, `mask-*` (no blur behind decorations, opaque anyway), `innerborder-*`
  (the v2 code positions it using the top margin of the main frame, so a
  sunken client edge would be misplaced; skipped on purpose).
