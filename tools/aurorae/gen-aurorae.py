#!/usr/bin/env python3
"""Generates the Matrix95 Aurorae template SVGs (pixel art -> merged <rect>s)."""
import math, os, sys

OUT = "/home/user/custom-kubuntu-rice/templates/aurorae"

def P(name):  # palette placeholder
    return "{{%s}}" % name

# ---------------------------------------------------------------- helpers
class Grid:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.c = [[None] * w for _ in range(h)]
    def px(self, x, y, col):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.c[y][x] = col
    def rect(self, x, y, w, h, col):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.px(xx, yy, col)
    def art(self, x0, y0, rows, col, on="X"):
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch == on:
                    self.px(x0 + dx, y0 + dy, col)
    def rects(self):
        """Greedy merge: horizontal runs, then stack identical runs vertically."""
        runs = []
        for y in range(self.h):
            x = 0
            while x < self.w:
                col = self.c[y][x]
                if col is None:
                    x += 1
                    continue
                x2 = x
                while x2 < self.w and self.c[y][x2] == col:
                    x2 += 1
                runs.append([x, y, x2 - x, 1, col])
                x = x2
        merged = []
        for r in runs:
            for m in merged:
                if m[0] == r[0] and m[2] == r[2] and m[4] == r[4] and m[1] + m[3] == r[1]:
                    m[3] += 1
                    break
            else:
                merged.append(r)
        return merged

def svg_rects(grid, ox, oy, indent="    "):
    out = []
    for x, y, w, h, col in grid.rects():
        out.append('%s<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % (indent, x + ox, y + oy, w, h, col))
    return "\n".join(out)

def group(id_, grid, ox, oy):
    return '  <g id="%s">\n%s\n  </g>' % (id_, svg_rects(grid, ox, oy))

def svg_doc(w, h, body, title):
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" shape-rendering="crispEdges">\n'
            '  <title>%s</title>\n%s\n</svg>\n' % (w, h, w, h, title, body))

HI, LI, FA, SH, DK = P("HILITE"), P("LIGHT"), P("FACE"), P("SHADOW"), P("DKSHADOW")
TITLE, TITLE_I = P("TITLE"), P("TITLE_INACTIVE")
FG, HEAD, DIM, FAINT = P("FG"), P("HEAD"), P("DIM"), P("FAINT")

# ---------------------------------------------------------------- window frame
FRAME = 4        # BorderLeft/Right/Bottom and TitleEdgeTop
TITLE_H = 22     # TitleHeight
TOP = FRAME + TITLE_H   # 26 = height of decoration-top

def frame_pieces(title_col):
    """Returns dict element-suffix -> Grid for a raised 4px Win95 frame with a solid title bar."""
    W = 16  # tile width for the straight pieces (tiled, content is uniform)
    # top-left 4 x TOP
    tl = Grid(FRAME, TOP)
    for y in range(TOP):
        tl.px(0, y, HI)
        if y >= 1: tl.px(1, y, LI)
        if y >= 2: tl.px(2, y, FA); tl.px(3, y, FA)
    tl.rect(0, 0, FRAME, 1, HI)
    tl.rect(1, 1, FRAME - 1, 1, LI)
    # top 16 x TOP
    top = Grid(W, TOP)
    top.rect(0, 0, W, 1, HI)
    top.rect(0, 1, W, 1, LI)
    top.rect(0, 2, W, 2, FA)
    top.rect(0, FRAME, W, TITLE_H, title_col)
    # top-right
    tr = Grid(FRAME, TOP)
    for y in range(TOP):
        tr.px(3, y, DK)
        if y >= 1: tr.px(2, y, SH)
        if y >= 2: tr.px(0, y, FA); tr.px(1, y, FA)
    tr.rect(0, 0, 3, 1, HI)
    tr.rect(0, 1, 2, 1, LI)
    # left / right (16 tall tile)
    left = Grid(FRAME, 16)
    left.rect(0, 0, 1, 16, HI); left.rect(1, 0, 1, 16, LI); left.rect(2, 0, 2, 16, FA)
    right = Grid(FRAME, 16)
    right.rect(0, 0, 2, 16, FA); right.rect(2, 0, 1, 16, SH); right.rect(3, 0, 1, 16, DK)
    # bottom-left 4x4
    bl = Grid(FRAME, FRAME)
    bl.rect(0, 0, 1, 3, HI)
    bl.rect(1, 0, 1, 2, LI)
    bl.rect(2, 0, 2, 2, FA)
    bl.rect(1, 2, 3, 1, SH)
    bl.rect(0, 3, 4, 1, DK)
    # bottom 16x4
    bot = Grid(W, FRAME)
    bot.rect(0, 0, W, 2, FA); bot.rect(0, 2, W, 1, SH); bot.rect(0, 3, W, 1, DK)
    # bottom-right
    br = Grid(FRAME, FRAME)
    br.rect(0, 0, 2, 2, FA)
    br.rect(2, 0, 1, 3, SH)
    br.rect(0, 2, 2, 1, SH)
    br.rect(3, 0, 1, 4, DK)
    br.rect(0, 3, 4, 1, DK)
    center = Grid(16, 16); center.rect(0, 0, 16, 16, FA)
    return {"topleft": tl, "top": top, "topright": tr, "left": left, "center": center,
            "right": right, "bottomleft": bl, "bottom": bot, "bottomright": br}

def frame_set(prefix, pieces, oy):
    """Lay the nine pieces out on a 48-wide strip starting at oy. Returns (svg, height)."""
    pos = {"topleft": (0, 0), "top": (8, 0), "topright": (28, 0),
           "left": (0, TOP + 6), "center": (8, TOP + 6), "right": (28, TOP + 6),
           "bottomleft": (0, TOP + 6 + 16 + 6), "bottom": (8, TOP + 6 + 16 + 6), "bottomright": (28, TOP + 6 + 16 + 6)}
    parts = []
    for name, g in pieces.items():
        x, y = pos[name]
        parts.append(group("%s-%s" % (prefix, name), g, x, oy + y))
    height = TOP + 6 + 16 + 6 + FRAME + 8
    return "\n".join(parts), height

def maximized_pieces(title_col):
    c = Grid(16, TITLE_H)
    c.rect(0, 0, 16, TITLE_H, title_col)
    return {"center": c}

def make_decoration():
    body = []
    oy = 0
    for prefix, pieces in (("decoration", frame_pieces(TITLE)),
                           ("decoration-inactive", frame_pieces(TITLE_I))):
        s, h = frame_set(prefix, pieces, oy)
        body.append(s); oy += h
    for prefix, col in (("decoration-maximized", TITLE), ("decoration-maximized-inactive", TITLE_I)):
        body.append(group(prefix + "-center", maximized_pieces(col)["center"], 8, oy))
        oy += TITLE_H + 8
    return svg_doc(48, oy, "\n".join(body), "Matrix 95 window decoration ({{NAME}})")

# ---------------------------------------------------------------- buttons
BW, BH = 20, 18

def bevel(g, sunken):
    """2px Windows 95 push-button bevel on a BW x BH grid, interior FACE."""
    if not sunken:
        o_tl, i_tl, o_br, i_br = HI, LI, DK, SH
    else:
        o_tl, i_tl, o_br, i_br = SH, DK, HI, LI
    g.rect(0, 0, BW, BH, FA)
    # bottom-right first (owns the top-right / bottom-left corner pixels)
    g.rect(1, BH - 2, BW - 2, 1, i_br)      # inner bottom
    g.rect(BW - 2, 1, 1, BH - 2, i_br)      # inner right
    g.rect(1, 1, BW - 3, 1, i_tl)           # inner top
    g.rect(1, 1, 1, BH - 3, i_tl)           # inner left
    g.rect(0, 0, BW - 1, 1, o_tl)           # outer top
    g.rect(0, 0, 1, BH - 1, o_tl)           # outer left
    g.rect(0, BH - 1, BW, 1, o_br)          # outer bottom
    g.rect(BW - 1, 0, 1, BH, o_br)          # outer right

MIN_ART = ["XXXXXXXX",
           "XXXXXXXX"]
MAX_ART = ["XXXXXXXXXX",
           "XXXXXXXXXX",
           "X........X",
           "X........X",
           "X........X",
           "X........X",
           "X........X",
           "X........X",
           "XXXXXXXXXX"]
REST_ART = ["...XXXXXXXX",
            "...XXXXXXXX",
            "...X......X",
            "..........X",
            "XXXXXXXX..X",
            "XXXXXXXX..X",
            "X......X.XX",
            "X......X...",
            "X......X...",
            "XXXXXXXX..."]
CLOSE_ART = ["XX......XX",
             ".XX....XX.",
             "..XX..XX..",
             "...XXXX...",
             "....XX....",
             "...XXXX...",
             "..XX..XX..",
             ".XX....XX.",
             "XX......XX"]
HELP_ART = [".XXXXX.",
            "XX...XX",
            "XX...XX",
            "....XX.",
            "...XX..",
            "...XX..",
            ".......",
            "...XX..",
            "...XX.."]

def glyph_min(g, col, d):
    g.art(6 + d, 11 + d, MIN_ART, col)
def glyph_max(g, col, d):
    g.art(5 + d, 4 + d, MAX_ART, col)
def glyph_restore(g, col, d):
    g.art(4 + d, 4 + d, REST_ART, col)
def glyph_close(g, col, d):
    g.art(5 + d, 4 + d, CLOSE_ART, col)
def glyph_help(g, col, d):
    g.art(6 + d, 4 + d, HELP_ART, col)

GLYPHS = {"minimize": glyph_min, "maximize": glyph_max, "restore": glyph_restore,
          "close": glyph_close, "help": glyph_help}

# state -> (sunken bevel?, glyph colour, glyph offset)
STATES = [
    ("active",               False, FG,    0),
    ("hover",                False, HEAD,  0),
    ("pressed",              True,  FG,    1),
    ("deactivated",          False, "EMBOSS", 0),
    ("inactive",             False, DIM,   0),
    ("hover-inactive",       False, FG,    0),
    ("pressed-inactive",     True,  DIM,   1),
    ("deactivated-inactive", False, "EMBOSS", 0),
]

def make_button(name):
    parts = []
    for i, (state, sunk, col, d) in enumerate(STATES):
        g = Grid(BW, BH)
        bevel(g, sunk)
        if col == "EMBOSS":      # disabled: Win95 embossed look, light copy 1px down-right under a faint glyph
            GLYPHS[name](g, LI, 1)
            GLYPHS[name](g, FAINT, 0)
        else:
            GLYPHS[name](g, col, d)
        parts.append(group("%s-center" % state, g, 0, i * (BH + 2)))
    h = len(STATES) * (BH + 2) - 2
    return svg_doc(BW, h, "\n".join(parts), "Matrix 95 %s button ({{NAME}})" % name)

def write(name, text):
    with open(os.path.join(OUT, name), "w") as f:
        f.write(text)

if __name__ == "__main__":
    write("decoration.svg", make_decoration())
    for b in GLYPHS:
        write(b + ".svg", make_button(b))
    print("ok")
