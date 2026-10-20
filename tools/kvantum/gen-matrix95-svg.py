#!/usr/bin/env python3
"""Generate templates/kvantum/Matrix95.svg (Windows 95 bevels, Matrix palette).

Every colour is a double-brace placeholder (e.g. FACE, HILITE) that
lib/common.sh `render` fills in.
Every element is built from integer-aligned 1px-grid rectangles, so the
result is crisp pixel art with no gradients, no rounding and no blur.

Usage: python3 gen-matrix95-svg.py > Matrix95.svg   (run inside templates/kvantum)
"""
import sys

els = []          # (id, w, h, [(x, y, w, h, colour|None)])


def E(eid, w, h, rects):
    els.append((eid, w, h, rects))


def runs(rows, cmap, ox=0, oy=0):
    """Pixel rows (list of str) + char->colour map -> merged rect list."""
    out = []
    for y, row in enumerate(rows):
        x = 0
        while x < len(row):
            ch = row[x]
            if ch not in cmap or cmap[ch] is None:
                x += 1
                continue
            x2 = x
            while x2 < len(row) and row[x2] == ch:
                x2 += 1
            out.append((ox + x, oy + y, x2 - x, 1, cmap[ch]))
            x = x2
    return out


def solid(eid, colour, w=2, h=2):
    E(eid, w, h, [(0, 0, w, h, colour)])


def bevel_box(w, h, tl, br, face):
    """Rects for an n-layer bevelled w x h box (same corner rules as
    frame_set: top-right and bottom-left pixels belong to the BR layers)."""
    n = len(tl)
    r = [(0, 0, w, h, face)]
    for i in range(n):
        r += [(i, i, w - 2 * i - 1, 1, tl[i]),                 # top
              (i, i, 1, h - 2 * i - 1, tl[i]),                 # left
              (w - 1 - i, i, 1, h - 2 * i, br[i]),             # right
              (i, h - 1 - i, w - 2 * i, 1, br[i])]             # bottom
    return r


# ---------------------------------------------------------------- bevels
def frame_set(name, state, tl, br, interior=None, n=None):
    """Emit name-state-{top,...} frame pieces (+ interior if given).

    tl / br: colours of the top-left / bottom-right layers, OUTERMOST FIRST.
    Layer count n = len(tl) = len(br).  None = transparent.
    """
    n = n or len(tl)
    p = f"{name}-{state}"

    def S(eid, w, h, cells):
        # cells: list of rows of colours -> rect list
        rects = []
        for y, row in enumerate(cells):
            x = 0
            while x < w:
                c = row[x]
                x2 = x
                while x2 < w and row[x2] == c:
                    x2 += 1
                if c is not None:
                    rects.append((x, y, x2 - x, 1, c))
                x = x2
        E(eid, w, h, rects)

    W = max(n, 2)
    # edges are W wide/tall in the stretched direction
    S(p + "-top", W, n, [[tl[y]] * W for y in range(n)])
    S(p + "-bottom", W, n, [[br[n - 1 - y]] * W for y in range(n)])
    S(p + "-left", n, W, [[tl[x] for x in range(n)] for _ in range(W)])
    S(p + "-right", n, W, [[br[n - 1 - x] for x in range(n)] for _ in range(W)])
    # corners
    tlc, trc, blc, brc = [], [], [], []
    for y in range(n):
        r1, r2, r3, r4 = [], [], [], []
        for x in range(n):
            r1.append(tl[min(x, y)])
            dr, dt = n - 1 - x, y
            r2.append(br[dr] if dr <= dt else tl[dt])
            dl, db = x, n - 1 - y
            r3.append(br[db] if db <= dl else tl[dl])
            r4.append(br[min(n - 1 - x, n - 1 - y)])
        tlc.append(r1); trc.append(r2); blc.append(r3); brc.append(r4)
    S(p + "-topleft", n, n, tlc)
    S(p + "-topright", n, n, trc)
    S(p + "-bottomleft", n, n, blc)
    S(p + "-bottomright", n, n, brc)
    if interior:
        solid(p, interior)


RAISED_TL = ["HILITE", "LIGHT"]
RAISED_BR = ["DKSHADOW", "SHADOW"]
SUNK_TL = ["SHADOW", "DKSHADOW"]
SUNK_BR = ["HILITE", "LIGHT"]


def raised(name, state, interior="FACE"):
    frame_set(name, state, RAISED_TL, RAISED_BR, interior)


def sunken(name, state, interior="FACE"):
    frame_set(name, state, SUNK_TL, SUNK_BR, interior)


# ------------------------------------------------------------- push buttons
for st in ("normal", "focused"):
    raised("button", st)
for st in ("pressed", "toggled"):
    sunken("button", st)
# default button: Win95 draws an extra outer black frame.  We use the
# bold text Kvantum applies to default buttons plus a hairline in FG.
E("button-default-indicator", 6, 6, [(0, 0, 6, 6, None)])

# ------------------------------------------------------------- tool buttons
raised("tool", "normal")
raised("tool", "focused")
sunken("tool", "pressed")
sunken("tool", "toggled")
# the toggled interior is the classic 50% dither (tiled 2x2 by the config)
E("tool-toggled", 2, 2, [(0, 0, 1, 1, "FACE"), (1, 1, 1, 1, "FACE"),
                         (1, 0, 1, 1, "LIGHT"), (0, 1, 1, 1, "LIGHT")])
E("tool-pressed", 2, 2, [(0, 0, 2, 2, "FACE")])

# ---------------------------------------------------------------- spin
for st in ("normal", "focused"):
    raised("spin", st)
sunken("spin", "pressed")
sunken("spin", "toggled")

# left edge of the joined spin button pair (Kvantum "separator" elements)
for st in ("normal", "focused", "pressed", "toggled"):
    pressed = st in ("pressed", "toggled")
    tl, br = (SUNK_TL, SUNK_BR) if pressed else (RAISED_TL, RAISED_BR)
    E(f"arrow-separator-{st}", 2, 4, [(0, 0, 1, 4, tl[0]), (1, 0, 1, 4, tl[1])])
    E(f"arrow-separator-top-{st}", 2, 2,
      [(0, 0, 2, 1, tl[0]), (0, 1, 1, 1, tl[0]), (1, 1, 1, 1, tl[1])])
    E(f"arrow-separator-bottom-{st}", 2, 2,
      [(0, 0, 1, 1, tl[0]), (1, 0, 1, 1, br[1]), (0, 1, 2, 1, br[0])])

# --------------------------------------------------------- text fields
for st in ("normal", "focused"):
    sunken("field", st, "BG")
# the combo box frame uses the same well
for st in ("normal", "focused", "pressed", "toggled"):
    sunken("combo", st, "BG")

# --------------------------------------------------------------- generic
# (view frames use the field element, no interior)

# ----------------------------------------------------------- tab frame
raised("tabframe", "normal")
# junctions where the active tab meets the pane (2px wide, 2px tall)
E("tabframe-normal-top-leftjunct", 2, 2,
  [(0, 0, 1, 2, "HILITE"), (1, 0, 1, 2, "LIGHT")])
E("tabframe-normal-top-rightjunct", 2, 2,
  [(0, 0, 1, 2, "SHADOW"), (1, 0, 1, 2, "DKSHADOW")])
E("tabframe-normal-bottom-leftjunct", 2, 2,
  [(0, 0, 1, 2, "HILITE"), (1, 0, 1, 2, "LIGHT")])
E("tabframe-normal-bottom-rightjunct", 2, 2,
  [(0, 0, 1, 2, "SHADOW"), (1, 0, 1, 2, "DKSHADOW")])

# ---------------------------------------------------------------- tabs
# Frame = 2 left/right, 4 top (inactive tabs keep their top 2px
# transparent, which makes the selected tab 2px taller), 0 bottom.
T = None


def tab(state, active):
    p = f"tab-{state}"
    if active:
        # raised, open at the bottom so it merges with the pane
        E(p + "-top", 2, 4, [(0, 0, 2, 1, "HILITE"), (0, 1, 2, 1, "LIGHT"),
                             (0, 2, 2, 2, "FACE")])
        E(p + "-left", 2, 2, [(0, 0, 1, 2, "HILITE"), (1, 0, 1, 2, "LIGHT")])
        E(p + "-right", 2, 2, [(0, 0, 1, 2, "SHADOW"), (1, 0, 1, 2, "DKSHADOW")])
        # chamfered top corners
        E(p + "-topleft", 2, 4, [(1, 0, 1, 1, "HILITE"), (0, 1, 1, 1, "HILITE"),
                                 (1, 1, 1, 1, "LIGHT"), (0, 2, 1, 2, "HILITE"),
                                 (1, 2, 1, 2, "LIGHT")])
        E(p + "-topright", 2, 4, [(0, 0, 1, 1, "HILITE"), (0, 1, 1, 1, "LIGHT"),
                                  (1, 1, 1, 1, "DKSHADOW"), (0, 2, 1, 2, "SHADOW"),
                                  (1, 2, 1, 2, "DKSHADOW")])
        # zero-height bottom: leave 1px invisible so the element exists
        E(p + "-bottom", 2, 1, [(0, 0, 2, 1, "FACE")])
        E(p + "-bottomleft", 2, 1, [(0, 0, 1, 1, "HILITE"), (1, 0, 1, 1, "LIGHT")])
        E(p + "-bottomright", 2, 1, [(0, 0, 1, 1, "SHADOW"), (1, 0, 1, 1, "DKSHADOW")])
        solid(p, "FACE")
    else:
        E(p + "-top", 2, 4, [(0, 0, 2, 2, T), (0, 2, 2, 1, "HILITE"),
                             (0, 3, 2, 1, "LIGHT")])
        E(p + "-left", 2, 2, [(0, 0, 1, 2, "HILITE"), (1, 0, 1, 2, "LIGHT")])
        E(p + "-right", 2, 2, [(0, 0, 1, 2, "SHADOW"), (1, 0, 1, 2, "DKSHADOW")])
        E(p + "-topleft", 2, 4, [(1, 2, 1, 1, "HILITE"), (0, 3, 1, 1, "HILITE"),
                                 (1, 3, 1, 1, "LIGHT")])
        E(p + "-topright", 2, 4, [(0, 2, 1, 1, "HILITE"), (0, 3, 1, 1, "LIGHT"),
                                  (1, 3, 1, 1, "DKSHADOW")])
        E(p + "-bottom", 2, 1, [(0, 0, 2, 1, T)])
        E(p + "-bottomleft", 2, 1, [(0, 0, 2, 1, T)])
        E(p + "-bottomright", 2, 1, [(0, 0, 2, 1, T)])
        solid(p, "FACE")


tab("normal", False)
tab("focused", False)
tab("toggled", True)

# close button on tabs (7x7 x)
X7 = ["X.....X",
      ".X...X.",
      "..X.X..",
      "...X...",
      "..X.X..",
      ".X...X.",
      "X.....X"]
for st, col in (("normal", "FG"), ("focused", "HEAD"), ("pressed", "HEAD"),
                ("disabled", "DIM")):
    E(f"tab-close-{st}", 9, 9, [(0, 0, 9, 9, None)] +
      runs(X7, {"X": col}, 1, 1))
E("tab-tear", 2, 8, [(0, 0, 1, 8, "SHADOW"), (1, 0, 1, 8, "HILITE")])

# ----------------------------------------------------------- group box
# etched: one SHADOW line, one HILITE line (offset by one pixel)
S_, H_ = "SHADOW", "HILITE"
st = "normal"
E("group-normal-top", 2, 2, [(0, 0, 2, 1, S_), (0, 1, 2, 1, H_)])
E("group-normal-bottom", 2, 2, [(0, 0, 2, 1, S_), (0, 1, 2, 1, H_)])
E("group-normal-left", 2, 2, [(0, 0, 1, 2, S_), (1, 0, 1, 2, H_)])
E("group-normal-right", 2, 2, [(0, 0, 1, 2, S_), (1, 0, 1, 2, H_)])
E("group-normal-topleft", 2, 2, [(0, 0, 2, 1, S_), (0, 1, 1, 1, S_), (1, 1, 1, 1, H_)])
E("group-normal-topright", 2, 2, [(0, 0, 1, 1, S_), (0, 1, 2, 1, H_)])
E("group-normal-bottomleft", 2, 2, [(0, 0, 1, 1, S_), (1, 0, 1, 2, H_)])
E("group-normal-bottomright", 2, 2, [(0, 0, 1, 1, S_), (1, 0, 1, 1, H_), (0, 1, 2, 1, H_)])
E("group-normal", 2, 2, [(0, 0, 2, 2, "FACE")])

# ------------------------------------------------------------ tooltips
frame_set("tooltip", "normal", ["FG"], ["FG"], "BG")

# ------------------------------------------------------------- menus
frame_set("menu", "normal", RAISED_TL, RAISED_BR, "FACE")
# selected row = solid TITLE
for st in ("focused", "pressed", "toggled"):
    solid(f"menuitem-{st}", "TITLE")
# separator: 6px tall, SHADOW + HILITE lines centred (etched)
E("menuitem-separator", 4, 6, [(0, 0, 4, 6, None),
                               (0, 2, 4, 1, "SHADOW"), (0, 3, 4, 1, "HILITE")])
# tear-off handle (dotted) - rarely used
E("menuitem-tearoff-normal", 2, 8, [(0, 0, 2, 8, None), (0, 3, 1, 1, "SHADOW"),
                                    (1, 4, 1, 1, "HILITE")])
E("menuitem-tearoff-focused", 2, 8, [(0, 0, 2, 8, None), (0, 3, 1, 1, "HEAD"),
                                     (1, 4, 1, 1, "HEAD")])

# menubar
solid("menubar-normal", "FACE")
for st in ("pressed", "toggled"):
    solid(f"menubaritem-{st}", "TITLE")
    # frame pieces (config gives the item no frame, but define them so no
    # default-theme element can leak in)
solid("menuitem-normal", "FACE")

# -------------------------------------------------------------- toolbar
frame_set("toolbar", "normal", ["HILITE"], ["SHADOW"], "FACE")
# handle (gripper): two raised vertical double lines, 8px wide
E("toolbar-handle", 8, 4, [(0, 0, 8, 4, None),
                           (1, 0, 1, 4, "HILITE"), (2, 0, 1, 4, "SHADOW"),
                           (4, 0, 1, 4, "HILITE"), (5, 0, 1, 4, "SHADOW")])
# separator: etched vertical line, 6px wide
E("toolbar-separator", 6, 4, [(0, 0, 6, 4, None),
                              (2, 0, 1, 4, "SHADOW"), (3, 0, 1, 4, "HILITE")])

# ---------------------------------------------------- check boxes / radios
CHECK = ["......X",
         ".....XX",
         "X...XXX",
         "XX.XXX.",
         "XXXXX..",
         ".XXX...",
         "..X...."]


def checkbox(state, checked=False, tri=False):
    name = "checkbox-" + ("checked-" if checked else "tristate-" if tri else "") + state
    r = bevel_box(13, 13, SUNK_TL, SUNK_BR, "BG")
    if tri:
        r += [(2, 2, 9, 9, "FAINT")]
    if checked or tri:
        r += runs(CHECK, {"X": "FG" if checked else "DIM"}, 3, 3)
    E(name, 13, 13, r)


for st in ("normal", "focused"):
    checkbox(st)
    checkbox(st, checked=True)
    checkbox(st, tri=True)

# radio: 13x13 pixel-stepped circle
MASK = ["....XXXXX....",
        "..XXXXXXXXX..",
        ".XXXXXXXXXXX.",
        ".XXXXXXXXXXX.",
        "XXXXXXXXXXXXX",
        "XXXXXXXXXXXXX",
        "XXXXXXXXXXXXX",
        "XXXXXXXXXXXXX",
        "XXXXXXXXXXXXX",
        ".XXXXXXXXXXX.",
        ".XXXXXXXXXXX.",
        "..XXXXXXXXX..",
        "....XXXXX...."]
DOT = [".XXX.",
       "XXXXX",
       "XXXXX",
       "XXXXX",
       ".XXX."]


def radio(state, checked=False):
    N = 13
    inside = lambda x, y: 0 <= x < N and 0 <= y < N and MASK[y][x] == "X"
    layer = {}
    for y in range(N):
        for x in range(N):
            if not inside(x, y):
                continue
            nb = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
            if any(not inside(a, b) for a, b in nb):
                layer[(x, y)] = 0
    for y in range(N):
        for x in range(N):
            if inside(x, y) and (x, y) not in layer:
                nb = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
                if any(layer.get(q) == 0 for q in nb):
                    layer[(x, y)] = 1
    cells = {}
    for (x, y), l in layer.items():
        tlhalf = (x + y) < (N - 1)
        if (x + y) == (N - 1):
            tlhalf = x < y        # diagonal: split the tie
        if tlhalf:
            cells[(x, y)] = ("SHADOW", "DKSHADOW")[l]
        else:
            cells[(x, y)] = ("HILITE", "LIGHT")[l]
    for y in range(N):
        for x in range(N):
            if inside(x, y) and (x, y) not in layer:
                cells[(x, y)] = "BG"
    if checked:
        for y, row in enumerate(DOT):
            for x, ch in enumerate(row):
                if ch == "X":
                    cells[(4 + x, 4 + y)] = "FG"
    rects = [(0, 0, N, N, None)]
    for y in range(N):
        x = 0
        while x < N:
            c = cells.get((x, y))
            if c is None:
                x += 1
                continue
            x2 = x
            while x2 < N and cells.get((x2, y)) == c:
                x2 += 1
            rects.append((x, y, x2 - x, 1, c))
            x = x2
    E(f"radio-{'checked-' if checked else ''}{state}", N, N, rects)


for st in ("normal", "focused"):
    radio(st)
    radio(st, True)

# ---------------------------------------------------------- arrows
UP = ["...X...",
      "..XXX..",
      ".XXXXX.",
      "XXXXXXX"]
DOWN = UP[::-1]
LEFT = ["...X",
        "..XX",
        ".XXX",
        "XXXX",
        ".XXX",
        "..XX",
        "...X"]
RIGHT = [r[::-1] for r in LEFT]
GLYPH = {"up": UP, "down": DOWN, "left": LEFT, "right": RIGHT}
STATE_COL = {"normal": "FG", "focused": "HEAD", "pressed": "HEAD", "disabled": "DIM",
             "toggled": "HEAD"}


def glyph_in(sz, rows, colour, ox=0, oy=0):
    h = len(rows)
    w = len(rows[0])
    x0 = (sz - w) // 2 + ox
    y0 = (sz - h) // 2 + oy
    return runs(rows, {"X": colour}, x0, y0)


# generic arrows, 9x9 cells
for d, rows in GLYPH.items():
    for st, col in STATE_COL.items():
        sh = 1 if st == "pressed" else 0
        E(f"arrow-{d}-{st}", 9, 9, [(0, 0, 9, 9, None)] +
          glyph_in(9, rows, col, sh, sh))
PLUS = ["...X...", "...X...", "...X...", "XXXXXXX", "...X...", "...X...", "...X..."]
MINUS = [".......", ".......", ".......", "XXXXXXX", ".......", ".......", "......."]
for nm, rows in (("plus", PLUS), ("minus", MINUS)):
    for st, col in STATE_COL.items():
        sh = 1 if st == "pressed" else 0
        E(f"arrow-{nm}-{st}", 9, 9, [(0, 0, 9, 9, None)] +
          glyph_in(9, rows, col, sh, sh))

# ------------------------------------------------- combo box arrow button
CB = 20
for st in ("normal", "focused", "pressed", "toggled", "disabled"):
    pressed = st in ("pressed", "toggled")
    tl, br = (SUNK_TL, SUNK_BR) if pressed else (RAISED_TL, RAISED_BR)
    r = bevel_box(CB, CB, tl, br, "FACE")
    sh = 1 if pressed else 0
    r += glyph_in(CB, GLYPH["down"], "DIM" if st == "disabled" else "FG", sh, sh)
    E(f"combo-arrow-{st}", CB, CB, r)

# submenu arrows
for d in ("right", "left"):
    for st, col in (("normal", "FG"), ("focused", "HEAD"), ("disabled", "DIM")):
        E(f"menuitem-{d}-{st}", 9, 9, [(0, 0, 9, 9, None)] + glyph_in(9, GLYPH[d], col))

# --------------------------------------------------------- scrollbar
SB = 16
SB_GLYPH = {"up": ["...X...", "..XXX..", ".XXXXX.", "XXXXXXX"]}
SB_GLYPH["down"] = SB_GLYPH["up"][::-1]
SB_GLYPH["left"] = ["...X", "..XX", ".XXX", "XXXX", ".XXX", "..XX", "...X"]
SB_GLYPH["right"] = [r[::-1] for r in SB_GLYPH["left"]]


for d, rows in SB_GLYPH.items():
    for st in ("normal", "focused", "pressed", "disabled"):
        pressed = st == "pressed"
        tl, br = (SUNK_TL, SUNK_BR) if pressed else (RAISED_TL, RAISED_BR)
        r = bevel_box(SB, SB, tl, br, "FACE")
        sh = 1 if pressed else 0
        r += glyph_in(SB, rows, "DIM" if st == "disabled" else "FG", sh, sh)
        E(f"sbarrow-{d}-{st}", SB, SB, r)
E("sbarrow-up-toggled", SB, SB, [(0, 0, SB, SB, "FACE")])

# trough: 50% checkerboard of FACE and BG
for st in ("normal",):
    E(f"sbgroove-{st}", 2, 2, [(0, 0, 2, 2, "BG"), (0, 0, 1, 1, "FACE"),
                               (1, 1, 1, 1, "FACE")])

# thumb: raised square-ish
for st in ("normal", "focused", "pressed"):
    raised("scrollbarslider", st)
# invisible grips (Win95 has no grip)
for st in ("normal", "focused", "pressed"):
    E(f"grip-{st}", 4, 4, [(0, 0, 4, 4, None)])

# ----------------------------------------------------------- slider
sunken("slider", "normal", "BG")
sunken("slider", "toggled", "BG")
E("slider-tick-normal", 5, 1, [(0, 0, 5, 1, "DIM")])
# handle: raised 11 x 21 (n=2) with a centre notch like the trackbar thumb
for st in ("normal", "focused", "pressed", "disabled"):
    tl, br = (SUNK_TL, SUNK_BR) if st == "pressed" else (RAISED_TL, RAISED_BR)
    E(f"slidercursor-{st}", 11, 21, bevel_box(11, 21, tl, br, "FACE"))

# ------------------------------------------------------------ progress
# Sunken trough, 3px frame: 2px bevel + 1px BG pad.
frame_set("progress", "normal", ["SHADOW", "DKSHADOW", "BG"],
          ["HILITE", "LIGHT", "BG"], "BG")
# chunk = 8 wide + 2 gap, tiled horizontally
E("progress-pattern-normal", 10, 4, [(0, 0, 10, 4, None), (0, 0, 8, 4, "FG")])
E("progress-pattern-disabled", 10, 4, [(0, 0, 10, 4, None), (0, 0, 8, 4, "DIM")])
E("progress-pattern-focused", 10, 4, [(0, 0, 10, 4, None), (0, 0, 8, 4, "FG")])
E("progress-pattern-toggled", 10, 4, [(0, 0, 10, 4, None), (0, 0, 8, 4, "FG")])

# transparent frame pieces, so no default-theme element can ever leak in
for base, states in (("itemview", ("focused", "pressed", "toggled")),
                     ("menubaritem", ("pressed", "toggled"))):
    for st in states:
        for pos in ("top", "bottom", "left", "right", "topleft", "topright",
                    "bottomleft", "bottomright"):
            E(f"{base}-{st}-{pos}", 1, 1, [(0, 0, 1, 1, None)])

# ------------------------------------------------------------ item views
solid("itemview-focused", "SURFACE")
solid("itemview-pressed", "TITLE")
solid("itemview-toggled", "TITLE")

# ------------------------------------------------------------ dock / mdi
solid("dock-normal", "FACE")
solid("dock-focused", "FACE")
solid("titlebar-normal", "TITLE_INACTIVE")
solid("titlebar-focused", "TITLE")

MDI = 14


def mdi(kind, rows, st):
    pressed = st == "pressed"
    tl, br = (SUNK_TL, SUNK_BR) if pressed else (RAISED_TL, RAISED_BR)
    r = bevel_box(MDI, MDI, tl, br, "FACE")
    sh = 1 if pressed else 0
    col = "DIM" if st == "disabled" else "FG"
    r += runs(rows, {"X": col}, (MDI - len(rows[0])) // 2 + sh, (MDI - len(rows)) // 2 + sh)
    E(f"mdi-{kind}-{st}", MDI, MDI, r)


M_CLOSE = ["XX....XX", ".XX..XX.", "..XXXX..", "...XX...", "..XXXX..", ".XX..XX.", "XX....XX"]
M_MAX = ["XXXXXXXXX", "XXXXXXXXX", "X.......X", "X.......X", "X.......X", "X.......X", "XXXXXXXXX"]
M_MIN = ["XXXXXX", "XXXXXX"]
M_REST = ["..XXXXX", "..XXXXX", "..X...X", "XXXXX.X", "XXXXX.X", "X...XXX", "X...X..", "XXXXX.."]
M_SHADE = ["XXXXXXX", "X.....X", "X.....X", "XXXXXXX"]
for st in ("normal", "focused", "pressed", "disabled"):
    mdi("close", M_CLOSE, st)
    mdi("maximize", M_MAX, st)
    mdi("minimize", M_MIN, st)
    mdi("restore", M_REST, st)
    mdi("shade", M_SHADE, st)
E("mdi-menu-normal", MDI, MDI, bevel_box(MDI, MDI, RAISED_TL, RAISED_BR, "FACE"))

# --------------------------------------------------------- tree expander
BOX = [(0, 0, 9, 9, "BG"),
       (0, 0, 9, 1, "SHADOW"), (0, 0, 1, 9, "SHADOW"),
       (8, 0, 1, 9, "HILITE"), (0, 8, 9, 1, "HILITE")]
for st, col in (("normal", "FG"), ("focused", "HEAD"), ("pressed", "HEAD"), ("disabled", "DIM")):
    E(f"tree-plus-{st}", 9, 9, BOX + [(2, 4, 5, 1, col), (4, 2, 1, 5, col)])
    E(f"tree-minus-{st}", 9, 9, BOX + [(2, 4, 5, 1, col)])

# ----------------------------------------------------- splitter, grips
for st in ("normal", "focused", "pressed"):
    solid(f"splitter-{st}", "FACE")
    E(f"splitter-grip-{st}", 4, 4, [(0, 0, 4, 4, None)])
# header separator (fixed name) - invisible, headers are full bevels
E("header-separator", 2, 2, [(0, 0, 2, 2, None)])
# size grip: diagonal etched lines, bottom-right
n = 13
sg = []
for d in (3, 7, 11):
    for dx in range(0, d + 1):
        x, y = n - 1 - dx, n - 1 - (d - dx)
        if 0 <= x < n and 0 <= y < n:
            sg.append((x, y, 1, 1, "SHADOW"))
        x2, y2 = n - 1 - dx, n - 1 - (d - 1 - dx)
        if 0 <= x2 < n and 0 <= y2 < n and d - 1 - dx >= 0:
            sg.append((x2, y2, 1, 1, "HILITE"))
for stn in ("normal", "focused"):
    E(f"sizegrip-{stn}", n, n, [(0, 0, n, n, None)] + sg)

# --------------------------------------------------------------- focus
# dotted focus rectangle: 1px, alternate pixel (tiled by frame.patternsize=2)
for pos, (w, h) in (("top", (2, 1)), ("bottom", (2, 1)), ("left", (1, 2)), ("right", (1, 2))):
    rects = [(0, 0, w, h, None)]
    rects += [(0, 0, 1, 1, "FG")]
    E(f"focus-{pos}", w, h, rects)

# ------------------------------------------------------------ dial (rare)
E("dial", 32, 32, [(0, 0, 32, 32, None), ("circle", 16, 16, 14, "FACE", "SHADOW")])
E("dial-notches", 32, 32, [(0, 0, 32, 32, None), ("circle", 16, 16, 15, "none", "DIM")])
E("dial-handle", 32, 32, [(0, 0, 32, 32, None), ("circle", 16, 6, 3, "FG", "none")])

# ------------------------------------------------------------- emit
COLS = 8
x = y = 0
rowh = 0
maxw = 640
out = []
pos = []
for eid, w, h, rects in els:
    if x + w > maxw:
        x = 0
        y += rowh + 4
        rowh = 0
    pos.append((eid, w, h, rects, x, y))
    x += w + 4
    rowh = max(rowh, h)
H = y + rowh + 4

hdr = ('<?xml version="1.0" encoding="UTF-8"?>\n'
       '<!-- Matrix95 for Kvantum: Windows 95 bevels in Matrix colours.\n'
       '     GENERATED by gen-matrix95-svg.py - edit that, not this.\n'
       '     Colours are double-brace placeholders filled by lib/common.sh render. -->\n'
       f'<svg xmlns="http://www.w3.org/2000/svg" width="{maxw}" height="{H}" '
       f'viewBox="0 0 {maxw} {H}" shape-rendering="crispEdges">\n')
out.append(hdr)


def ph(name):
    return "{" * 2 + name + "}" * 2


def fill(c):
    return 'fill="' + ph(c) + '"'


for eid, w, h, rects, ox, oy in pos:
    out.append(f'<g id="{eid}">\n')
    for r in rects:
        if r[0] == "circle":
            _, cx, cy, rad, f, s = r
            fa = 'fill="none"' if f == "none" else fill(f)
            sa = 'stroke="none"' if s == "none" else ('stroke="' + ph(s) + '" stroke-width="2"')
            out.append(f'<circle cx="{ox + cx}" cy="{oy + cy}" r="{rad}" {fa} {sa}/>\n')
            continue
        rx, ry, rw, rh, c = r[:5]
        if rw <= 0 or rh <= 0:
            continue
        if c is None:
            # transparent bounding box (keeps the element's size stable)
            out.append(f'<rect x="{ox + rx}" y="{oy + ry}" width="{rw}" height="{rh}" '
                       f'fill="#000000" fill-opacity="0"/>\n')
            continue
        out.append(f'<rect x="{ox + rx}" y="{oy + ry}" width="{rw}" height="{rh}" {fill(c)}/>\n')
    out.append('</g>\n')
out.append('</svg>\n')
sys.stdout.write("".join(out))
