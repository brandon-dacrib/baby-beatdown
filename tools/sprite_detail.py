#!/usr/bin/env python3
"""sprite_detail.py: a detail pass over the dumped fighter poses (render/poses_orig -> render/poses).

The toy renders each pose with flat tone bands (light / mid / dark per body part). This pass keeps the
silhouettes and features and adds what 16-bit sprites usually have on top:
  * dithered transitions between neighbouring tones (checkerboard blend along every tone boundary)
  * a one-pixel darker rim inside the outline on the shadow side (bottom / right)
  * a one-pixel lighter rim inside the outline on the lit side (top / left)
  * fur speckle on the animal babies' mid tone, a stitched seam on the diaper
Palette indices (toy/art.lua): 1 outline, 2 fur dark, 3 fur mid, 4 fur light, 5 diaper, 6 diaper shade,
7 accent dark, 8 accent light, 9 eye white, 10 pupil, 11 pink, 12 belly light, 13 nose, 14 highlight, 15 misc."""
import json, os, sys
import numpy as np
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(root, "render", "poses_orig"); DST = os.path.join(root, "render", "poses")
FAMILIES = [(2, 3, 4), (5, 6), (7, 8)]          # dark .. light ramps (diaper: 6 is the shade of 5)
DARKER = {3: 2, 4: 3, 5: 6, 8: 7, 12: 3}
LIGHTER = {2: 3, 3: 4, 6: 5, 7: 8}
FACE = {9, 10, 11, 13, 14}                         # never touched
FURRY = {"puppy", "kitten", "piglet", "duck", "bear", "bunny"}

def detail(g, kind, seed):
    a = np.array([[int(ch, 16) for ch in row] for row in g], np.int32)
    out = a.copy()
    H, W = a.shape
    yy, xx = np.mgrid[0:H, 0:W]
    on = a != 0
    def nb(dy, dx):
        n = np.zeros_like(a); src = a
        ys = slice(max(0, dy), H + min(0, dy)); xs = slice(max(0, dx), W + min(0, dx))
        yd = slice(max(0, -dy), H + min(0, -dy)); xd = slice(max(0, -dx), W + min(0, -dx))
        n[yd, xd] = src[ys, xs]
        return n
    right, down, left, up = nb(0, 1), nb(1, 0), nb(0, -1), nb(-1, 0)
    checker = ((xx + yy) & 1) == 0
    # dithered tone boundaries: a pixel of tone T next to the lighter tone of its family takes the lighter tone
    # on the checkerboard (and vice versa), one pixel deep on each side
    for dark, light in [(d, l) for d, l in LIGHTER.items()]:
        edge = (a == dark) & ((right == light) | (up == light)) & checker
        out[edge] = light
        edge2 = (a == light) & ((left == dark) | (down == dark)) & ~checker
        out[edge2] = dark
    # rims inside the outline
    body = on & (a != 1) & ~np.isin(a, list(FACE))
    shadow_rim = body & ((right == 1) | (down == 1) | (right == 0) | (down == 0))
    lit_rim = body & ((left == 1) | (up == 1)) & ~shadow_rim
    for t, d in DARKER.items(): out[shadow_rim & (a == t)] = d
    for t, l in LIGHTER.items(): out[lit_rim & (a == t) & checker] = l
    # fur speckle: sparse darker dots in the mid fur tone of the animals
    if kind in FURRY:
        rng = np.random.default_rng(seed)
        spots = (a == 3) & (rng.random((H, W)) < (0.03 if kind == "piglet" else 0.07)) & (left == 3) & (right == 3) & (up == 3) & (down == 3)
        out[spots] = 2
    # cute but angry: furrowed brows. Each eye is a 4x6 block of eye white (index 9); the flat brow above it becomes
    # a thick line that dips toward the nose (the babies face right, so the inner end is on the right)
    seen = np.zeros_like(a, bool)
    for y in range(H):
        for x in range(W):
            if a[y, x] == 9 and not seen[y, x] and (x == 0 or a[y, x - 1] != 9) and (y == 0 or a[y - 1, x] != 9):
                w = 0
                while x + w < W and a[y, x + w] == 9: w += 1
                h = 0
                while y + h < H and a[y + h, x] == 9: h += 1
                seen[y:y + h, x:x + w] = True
                if 3 <= w <= 5 and h >= 4:
                    for i in range(-1, w + 1):
                        by = y - 3 + (i + 1) * 3 // (w + 2)      # dips 2 rows across the eye
                        for t in range(2):
                            py, px = by + t, x + i
                            if 0 <= py < H and 0 <= px < W and a[py, px] != 9: out[py, px] = 1
    # diaper seam: a dotted shade line one third down the diaper
    dia = a == 5
    if dia.any():
        ys_ = np.nonzero(dia.any(1))[0]; y0, y1 = ys_[0], ys_[-1]
        seam = dia & (yy == y0 + (y1 - y0) // 3) & ((xx & 1) == 0)
        out[seam] = 6
    return ["".join(format(int(v), "x") for v in row) for row in out]

if __name__ == "__main__":
    os.makedirs(DST, exist_ok=True)
    for ci in range(1, 9):
        j = json.load(open(os.path.join(SRC, f"char{ci}.json")))
        kind = ["human", "puppy", "kitten", "piglet", "duck", "bear", "bunny", "bug"][ci - 1]
        for p, g in j["poses"].items():
            j["poses"][p] = detail(g, kind, ci * 100 + int(p))
        json.dump(j, open(os.path.join(DST, f"char{ci}.json"), "w"), separators=(",", ":"))
        print("char", ci, j["name"], len(j["poses"]), "poses")
