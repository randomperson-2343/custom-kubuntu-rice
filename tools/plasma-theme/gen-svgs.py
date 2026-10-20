#!/usr/bin/env python3
"""Generate the Matrix 95 Plasma desktop-theme SVG templates.

Developer tool only: the committed output lives in ../Matrix95/. Run it after
changing the design, then commit the regenerated files:

    python3 templates/plasma-theme/tools/gen-svgs.py

Every picture is drawn on a pixel grid (one SVG <rect> per run of pixels, all
coordinates are integers, shape-rendering=crispEdges, no gradients, no blur).
Colors are written as {{KEY}} placeholders (FACE, HILITE, ...) that
lib/common.sh `render` fills from palettes/<name>.sh.

A KSvg "frame" is a 9-slice: <prefix>topleft, top, topright, left, center,
right, bottomleft, bottom, bottomright, plus <prefix>hint-{top,bottom,left,
right}-margin rects whose height/width is the content margin. Each slice is a
<g id="..."> that always covers its whole cell (transparent cells get a
fill="none" rect) so Qt reports the right size.
"""
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "templates", "plasma-theme", "Matrix95")

# ---------------------------------------------------------------- pixel image


class Img:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.px[yy][xx] = c

    def bevel(self, x, y, w, h, tl, br, depth=2, fill=None):
        """Draw a Windows-95 style bevel box.

        tl = (outer, inner) colors for the top/left edges,
        br = (outer, inner) colors for the bottom/right edges.
        Pixels where the two edge directions meet (top-right and bottom-left
        corners) take the bottom/right color, like GDI's DrawEdge.
        fill: None, a color, or a function (x, y) -> color for the interior.
        """
        for j in range(h):
            for i in range(w):
                dt, dl, db, dr = j, i, h - 1 - j, w - 1 - i
                d = min(dt, dl, db, dr)
                if d >= depth:
                    if fill is not None:
                        self.px[y + j][x + i] = fill(x + i, y + j) if callable(fill) else fill
                    continue
                is_tl = dt == d or dl == d
                is_br = db == d or dr == d
                use_br = is_br  # ties (TR/BL corners) go to bottom-right
                self.px[y + j][x + i] = (br if use_br else tl)[d]


def checker(a, b):
    """50% checkerboard: Windows 95 dithers pressed buttons like this."""
    return lambda x, y: a if (x + y) % 2 == 0 else b


# ---------------------------------------------------------------- svg output


def runs(img, x0, y0, x1, y1):
    """Merge a pixel region into rectangles: [(x, y, w, h, color)]."""
    rows = []
    for y in range(y0, y1):
        row, x = [], x0
        while x < x1:
            c = img.px[y][x]
            n = 1
            while x + n < x1 and img.px[y][x + n] == c:
                n += 1
            if c is not None:
                row.append((x, n, c))
            x += n
        rows.append(row)
    out, open_ = [], {}
    for k, row in enumerate(rows + [[]]):
        keys = {(x, n, c) for x, n, c in row}
        for key in list(open_):
            if key not in keys:
                ys, = open_.pop(key)
                out.append((key[0], y0 + ys, key[1], y0 + k - (y0 + ys), key[2]))
        for key in keys:
            if key not in open_:
                open_[key] = (k,)
    return out


class Sheet:
    """Collects groups onto one canvas and writes the SVG."""

    def __init__(self, title):
        self.title = title
        self.items = []  # strings
        self.cy = 0  # next free row for frames
        self.width = 0
        self.hints = []  # (id, w, h)

    def group(self, gid, img, x, y, w, h, ox, oy):
        """Emit pixels [x, x+w) x [y, y+h) of img as <g id=gid> at (ox, oy)."""
        body = []
        for rr in runs(img, x, y, x + w, y + h):
            assert isinstance(rr[4], str) and rr[4].isupper(), (gid, rr)
        has_hole = any(img.px[yy][xx] is None for yy in range(y, y + h) for xx in range(x, x + w))
        if has_hole:
            body.append('<rect x="%d" y="%d" width="%d" height="%d" fill="none"/>' % (ox, oy, w, h))
        for rx, ry, rw, rh, c in runs(img, x, y, x + w, y + h):
            body.append('<rect x="%d" y="%d" width="%d" height="%d" fill="{{%s}}"/>'
                        % (ox + rx - x, oy + ry - y, rw, rh, c))
        self.items.append('<g id="%s">%s</g>' % (gid, "".join(body)))

    def frame(self, prefix, img, widths, margins=None, tile_center=False):
        """Slice img into a 9-slice with edge widths (lw, rw, th, bh)."""
        lw, rw, th, bh = widths
        xs = [0, lw, img.w - rw, img.w]
        ys = [0, th, img.h - bh, img.h]
        names = [["topleft", "top", "topright"],
                 ["left", "center", "right"],
                 ["bottomleft", "bottom", "bottomright"]]
        oy = self.cy
        for r in range(3):
            for c in range(3):
                w, h = xs[c + 1] - xs[c], ys[r + 1] - ys[r]
                if w <= 0 or h <= 0:
                    continue
                self.group(prefix + names[r][c], img, xs[c], ys[r], w, h, xs[c], oy + ys[r])
        self.cy += img.h + 2
        self.width = max(self.width, img.w)
        if margins:
            mt, mb, ml, mr = margins
            self.hints += [(prefix + "hint-top-margin", 4, mt), (prefix + "hint-bottom-margin", 4, mb),
                           (prefix + "hint-left-margin", ml, 4), (prefix + "hint-right-margin", mr, 4)]
        if tile_center:
            self.hints.append((prefix + "hint-tile-center", 1, 1))

    def raw(self, gid, img, ox_hint=None):
        """Standalone element (not a frame slice) from a whole image."""
        oy = self.cy
        self.group(gid, img, 0, 0, img.w, img.h, 0, oy)
        self.cy += img.h + 2
        self.width = max(self.width, img.w)

    def write(self, relpath):
        hx = self.width + 2
        hy = 0
        hint_items = []
        for gid, w, h in self.hints:
            hint_items.append('<rect id="%s" x="%d" y="%d" width="%d" height="%d" fill="none"/>'
                              % (gid, hx, hy, w, h))
            hy += h + 2
        W = hx + 14
        H = max(self.cy, hy)
        path = os.path.join(OUT, relpath)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
            f.write('<!-- Matrix 95 {{NAME}}: %s. Generated by templates/plasma-theme/tools/gen-svgs.py; '
                    'colors come from palettes/{{ID}}.sh. Pixel art: do not add gradients, blur or '
                    'non-integer coordinates. -->\n' % self.title)
            f.write('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" '
                    'shape-rendering="crispEdges">\n' % (W, H, W, H))
            for it in self.items:
                f.write(it + "\n")
            for it in hint_items:
                f.write(it + "\n")
            f.write("</svg>\n")
        print("wrote", os.path.relpath(path))


# ---------------------------------------------------------------- the pieces

RAISED = (("HILITE", "LIGHT"), ("DKSHADOW", "SHADOW"))
SUNKEN = (("SHADOW", "DKSHADOW"), ("HILITE", "LIGHT"))
ETCHED = (("SHADOW", "HILITE"), ("HILITE", "SHADOW"))


def box(w, h, edges, fill, depth=2, inset=(0, 0, 0, 0)):
    """Image w x h with a bevel box; inset = transparent (l, t, r, b) gap."""
    img = Img(w, h)
    l, t, r, b = inset
    img.bevel(l, t, w - l - r, h - t - b, edges[0], edges[1], depth, fill)
    return img


def ring(w, h, color):
    """1px outline, transparent inside (hover/focus overlays)."""
    img = Img(w, h)
    img.bevel(0, 0, w, h, (color, color), (color, color), 1, None)
    return img


def make_panel():
    s = Sheet("panel background (widgets/panel-background)")
    # Bottom panel (default prefix): 2px raised top edge like the Win95 taskbar.
    im = Img(6, 6)
    im.rect(0, 0, 6, 6, "FACE")
    im.rect(0, 0, 6, 1, "HILITE")
    im.rect(0, 1, 6, 1, "LIGHT")
    s.frame("", im, (1, 1, 2, 1), margins=(4, 2, 1, 1))
    # Top panel: the raised side faces the screen center, i.e. the bottom edge.
    im = Img(6, 6)
    im.rect(0, 0, 6, 6, "FACE")
    im.rect(0, 4, 6, 1, "SHADOW")
    im.rect(0, 5, 6, 1, "DKSHADOW")
    s.frame("north-", im, (1, 1, 1, 2), margins=(2, 4, 1, 1))
    # Left panel: edge on the right.
    im = Img(6, 6)
    im.rect(0, 0, 6, 6, "FACE")
    im.rect(4, 0, 1, 6, "SHADOW")
    im.rect(5, 0, 1, 6, "DKSHADOW")
    s.frame("west-", im, (1, 2, 1, 1), margins=(1, 1, 2, 4))
    # Right panel: edge on the left.
    im = Img(6, 6)
    im.rect(0, 0, 6, 6, "FACE")
    im.rect(0, 0, 1, 6, "HILITE")
    im.rect(1, 0, 1, 6, "LIGHT")
    s.frame("east-", im, (2, 1, 1, 1), margins=(1, 1, 4, 2))
    s.write("widgets/panel-background.svg")
    s.write("solid/widgets/panel-background.svg")


def make_dialog():
    s = Sheet("popups, menus and dialogs (dialogs/background)")
    s.frame("", box(8, 8, RAISED, "FACE"), (2, 2, 2, 2), margins=(3, 3, 3, 3))
    s.write("dialogs/background.svg")
    s.write("solid/dialogs/background.svg")


def make_tooltip():
    s = Sheet("tooltip (widgets/tooltip)")
    # 1px DKSHADOW outline plus a 1px HILITE line inside it, SURFACE fill.
    im = box(6, 6, (("DKSHADOW", "HILITE"), ("DKSHADOW", "HILITE")), "SURFACE")
    s.frame("", im, (2, 2, 2, 2), margins=(3, 3, 4, 4))
    s.write("widgets/tooltip.svg")
    s.write("solid/widgets/tooltip.svg")


def make_tasks():
    s = Sheet("task manager buttons (widgets/tasks)")
    face = "FACE"
    dither = checker("FACE", "LIGHT")
    W, H = 10, 8
    inset = (1, 0, 1, 0)  # 1px transparent gap left/right between buttons
    wd = (3, 3, 2, 2)
    mg = (5, 5, 5, 5)

    def state(prefix, edges, fill, tile=False):
        s.frame(prefix, box(W, H, edges, fill, 2, inset), wd, margins=mg, tile_center=tile)

    state("normal-", RAISED, face)
    state("minimized-", RAISED, face)
    # Active window: sunken, dithered face.
    state("focus-", SUNKEN, dither, tile=True)
    # Hover: raised with a bright HEAD-tinted outer edge.
    state("hover-", (("HEAD", "HILITE"), ("DKSHADOW", "SHADOW")), face)
    state("focus-hover-", (("SHADOW", "DKSHADOW"), ("HEAD", "HILITE")), dither, tile=True)
    # Demands attention: ALERT outline around a raised button.
    state("attention-", (("ALERT", "HILITE"), ("ALERT", "SHADOW")), face)
    state("attention-hover-", (("ALERT", "HEAD"), ("ALERT", "SHADOW")), face)
    # Pinned launchers have no frame until hovered; then a thin 1px raised box.
    lh = box(8, 6, (("HILITE", "HILITE"), ("SHADOW", "SHADOW")), face, 1, (1, 0, 1, 0))
    s.frame("launcher-hover-", lh, (2, 2, 1, 1), margins=(3, 3, 3, 3))
    # Task progress (taskbar progress overlay): a flat LIGHT fill.
    pg = Img(4, 4)
    pg.rect(0, 0, 4, 4, "LIGHT")
    s.frame("progress-", pg, (0, 0, 0, 0), margins=None)
    # Group expander (small box with a plus) for grouped tasks.
    for side in ("bottom", "top", "left", "right"):
        g = box(9, 9, (("HEAD", "HEAD"), ("HEAD", "HEAD")), "SURFACE", 1)
        g.rect(2, 4, 5, 1, "HEAD")
        g.rect(4, 2, 1, 5, "HEAD")
        s.raw("group-expander-" + side, g)
    s.write("widgets/tasks.svg")


def make_button():
    s = Sheet("push buttons in Plasma widgets (widgets/button)")
    s.frame("normal-", box(8, 8, RAISED, "FACE"), (2, 2, 2, 2), margins=(4, 4, 6, 6))
    s.frame("pressed-", box(8, 8, SUNKEN, checker("FACE", "LIGHT")), (2, 2, 2, 2), margins=(4, 4, 6, 6),
            tile_center=True)
    s.frame("hover-", ring(6, 6, "HEAD"), (1, 1, 1, 1), margins=(1, 1, 1, 1))
    s.frame("focus-", ring(6, 6, "FG"), (1, 1, 1, 1), margins=(1, 1, 1, 1))
    # Flat/tool buttons: flat until hovered, then a thin raised box.
    s.frame("toolbutton-hover-", box(6, 6, (("HILITE", "HILITE"), ("SHADOW", "SHADOW")), "FACE", 1),
            (1, 1, 1, 1), margins=(3, 3, 3, 3))
    s.frame("toolbutton-pressed-", box(6, 6, (("SHADOW", "SHADOW"), ("HILITE", "HILITE")), "FACE", 1),
            (1, 1, 1, 1), margins=(3, 3, 3, 3))
    s.write("widgets/button.svg")


def make_frame():
    s = Sheet("group boxes and frames (widgets/frame)")
    s.frame("plain-", box(8, 8, ETCHED, None), (2, 2, 2, 2), margins=(3, 3, 3, 3))
    s.frame("sunken-", box(8, 8, SUNKEN, "SURFACE"), (2, 2, 2, 2), margins=(3, 3, 3, 3))
    s.frame("raised-", box(8, 8, RAISED, "FACE"), (2, 2, 2, 2), margins=(3, 3, 3, 3))
    s.write("widgets/frame.svg")


def make_viewitem():
    s = Sheet("list and menu item highlight (widgets/viewitem)")
    # Text keeps the normal ink color on these, so every fill stays dark.
    blank = Img(6, 6)
    s.frame("normal-", blank, (2, 2, 2, 2), margins=(4, 4, 4, 4))
    hov = Img(6, 6)
    hov.rect(0, 0, 6, 6, "LIGHT")
    s.frame("hover-", hov, (2, 2, 2, 2), margins=(4, 4, 4, 4))
    # Selected = same fill with a 1px HILITE outline; selected+hover: HEAD outline.
    # (FG text on TITLE only reaches 3.8:1 for amber, on LIGHT it is 5.9:1 or better.)
    for pre, edge in (("selected-", "HILITE"), ("selected+hover-", "HEAD")):
        im = box(6, 6, ((edge, edge), (edge, edge)), "LIGHT", 1)
        s.frame(pre, im, (2, 2, 2, 2), margins=(4, 4, 4, 4))
    s.write("widgets/viewitem.svg")


def make_lineedit():
    s = Sheet("text fields (widgets/lineedit)")
    s.frame("base-", box(8, 8, SUNKEN, "SURFACE"), (2, 2, 2, 2), margins=(3, 3, 4, 4))
    s.frame("hover-", ring(6, 6, "DIM"), (1, 1, 1, 1), margins=(1, 1, 1, 1))
    s.frame("focus-", ring(6, 6, "FG"), (1, 1, 1, 1), margins=(1, 1, 1, 1))
    s.write("widgets/lineedit.svg")


def make_tabbar():
    s = Sheet("open-popup marker in the system tray (widgets/tabbar)")
    s.frame("active-tab-", box(8, 8, SUNKEN, checker("FACE", "LIGHT")), (2, 2, 2, 2), margins=(2, 2, 2, 2),
            tile_center=True)
    s.write("widgets/tabbar.svg")


if __name__ == "__main__":
    make_panel()
    make_dialog()
    make_tooltip()
    make_tasks()
    make_button()
    make_frame()
    make_viewitem()
    make_lineedit()
    make_tabbar()
