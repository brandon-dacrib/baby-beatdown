#!/usr/bin/env python3
"""Build Studio sheet sources (kind=sheet, 4bpp) from render/poses/charN.json.
One cell per pose, 64x64, 8 cells per row. Writes cart/sources/charN.json and a cell index."""
import json, sys, os
FULL = list(range(0,18)) + list(range(48,78)) + list(range(81,89))   # 56 poses (Lua-mode reference)
CORE = [0, 1, 3, 4]   # idle walk punch kick: 4 cells each; the OBJ region holds 512 tiles = 8 cells for both fighters
POSES = CORE if "--core" in sys.argv else FULL
COLS = min(8, len(POSES))
args=[a for a in sys.argv[1:] if not a.startswith("--")]
out_dir = args[0] if args else "cart/sources"
index = {}
for ci in range(1, 9):
    j = json.load(open(f"render/poses/char{ci}.json"))
    pal = {format(i+1, "x"): "#%02x%02x%02x" % tuple(j["palette"][i]) for i in range(15)}
    rows = (len(POSES) + COLS - 1) // COLS
    grid = [["." ] * (COLS * 64) for _ in range(rows * 64)]
    cells = {}
    for n, p in enumerate(POSES):
        g = j["poses"].get(str(p))
        if g is None: continue
        cx, cy = (n % COLS) * 64, (n // COLS) * 64
        for y in range(64):
            row = g[y]
            for x in range(64):
                c = row[x]
                if c != "0": grid[cy + y][cx + x] = c
        cells[p] = n
    src = {"kind": "obj", "cell_size": 64, "bit_depth": 4, "palette": pal, "grid": ["".join(r) for r in grid]}
    json.dump(src, open(f"{out_dir}/char{ci}.json", "w"), separators=(",", ":"))
    index[ci] = {"name": j["name"], "cells": cells, "cols": COLS}
    used = sum(1 for r in grid for c in r if c != ".")
    print(f"char{ci} {j['name']}: {len(cells)} poses, {rows} rows, {used} px")
json.dump(index, open(f"{out_dir}/index.json", "w"), indent=0)
