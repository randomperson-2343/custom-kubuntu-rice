#!/usr/bin/env python3
import sys
sys.path.insert(0, ".")
from gen import Grid, FG, HEAD, DIM, HI, svg_doc

N = 24
g = Grid(N, N)
import math
X0 = 6                               # flag spans x = 6..23 (18 columns): pane 8, gap 2, pane 8
for c in range(18):
    off = round(1.4 * math.sin(2 * math.pi * c / 20 + 2.2))   # one gentle wave, 1-unit steps
    if 8 <= c < 10:
        continue                      # vertical gap between the left and right panes
    left = c < 8
    x = X0 + c
    g.rect(x, 3 + off + 1, 1, 8, FG if left else HEAD)
    g.rect(x, 13 + off + 1, 1, 8, DIM if left else HI)
# pixel speed trail, left of the flag
for y, h, x0, x1, col in [(5, 2, 2, 4, FG), (9, 2, 0, 4, DIM), (13, 2, 1, 4, HI), (17, 2, 0, 4, DIM), (21, 1, 2, 4, FG)]:
    g.rect(x0, y, x1 - x0 + 1, h, col)
body = "\n".join('  <rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % (x, y, w, h, c) for x, y, w, h, c in g.rects())
doc = svg_doc(N, N, body, "Matrix 95 start logo ({{NAME}})")
open("/home/user/custom-kubuntu-rice/templates/icons/matrix95-start.svg", "w").write(doc)
print("ok")
