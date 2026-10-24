# select_bg.py: paints the player-select background (a map of the babies' world with the eight stage
# locations, the portrait grid panel and the big-portrait frame) and quantizes it as stage 9 using BG
# palettes 3..7 only (palette 0 is kept for the big portrait, 1 and 2 are the HUD font).
# Layout (pixels): map 8..248 x 16..100; big portrait 8..104 x 120..216; grid cells 32x32 at
# x = 112 + i*32, y = 112 / 144. python select_bg.py writes render/stage9.png and toy/bg9*.lua.
import sys, os, json, numpy as np
from PIL import Image
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
from paintlib import Canvas, W, H
import quantize

FONT = json.load(open(os.path.join(here, "..", "toy", "sources", "font.json")))["grid"]

def glyph(ch):
    b = ord(ch)
    if 65 <= b <= 90: return b - 64
    if 48 <= b <= 57: return b - 48 + 27
    return {33: 37, 46: 38, 45: 39, 58: 40}.get(b, 0)

def stamp(c, x, y, text, outline, fill, light=None):
    """Bake HUD-font text into the painting (same glyphs the game uses, so overlays line up)."""
    for i, ch in enumerate(text):
        g = glyph(ch)
        if g == 0: continue
        for row in range(8):
            for col in range(8):
                v = FONT[row][g * 8 + col]
                if v == ".": continue
                px, py = x + i * 8 + col, y + row
                if 0 <= px < W and 0 <= py < H:
                    c.rgb[py, px] = outline if v == "1" else (light or fill) if v == "4" else fill
                    c.on[py, px] = True

LOCS = [  # (dot x, dot y, label col, label row, label)
    (30, 70, 1, 10, "BAYOU"), (70, 44, 7, 7, "YARD"), (102, 30, 11, 3, "ROOF"), (124, 64, 13, 9, "FARM"),
    (152, 42, 17, 6, "POND"), (178, 76, 20, 11, "CAVE"), (210, 34, 24, 5, "GARDEN"), (232, 68, 27, 10, "LEAF"),
]

def island(c, cx, cy, rx, ry, seed, bumps):
    yy, xx = np.mgrid[0:H, 0:W]
    d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
    n = c.value_noise(14, seed, octaves=3, aspect=1.0) * bumps
    return (d + n) <= 1

def paint():
    c = Canvas(seed=9)
    # ---- map: three islands with a glowing coast
    land = island(c, 62, 58, 58, 36, 1, 0.9) | island(c, 150, 60, 50, 36, 2, 0.9) | island(c, 222, 56, 34, 32, 3, 0.8)
    land &= c.rect(6, 18, 250, 100)
    glow = land.copy()
    for r in (1, 2, 3, 4, 5):
        g = land
        for dx, dy in ((r, 0), (-r, 0), (0, r), (0, -r), (r, r), (-r, -r), (r, -r), (-r, r)):
            g = g | np.roll(np.roll(land, dy, 0), dx, 1)
        glow = glow | g
    c.fill(glow & ~land, (70, 110, 230))
    ring = glow & ~land
    for r, col in ((4, (54, 84, 200)), (3, (64, 100, 220)), (2, (84, 130, 240)), (1, (120, 170, 250))):
        g = land
        for dx, dy in ((r, 0), (-r, 0), (0, r), (0, -r), (r, r), (-r, -r), (r, -r), (-r, r)):
            g = g | np.roll(np.roll(land, dy, 0), dx, 1)
        c.fill(g & ~land & ring, col)
    tex = c.value_noise(10, 7, octaves=3)
    c.fill(land, (204, 178, 124), tex, 0.16)
    # relief: darker shoreline, lighter interior
    inner = land
    for r in (1, 2, 3):
        s = land
        for dx, dy in ((r, 0), (-r, 0), (0, r), (0, -r)):
            s = s & np.roll(np.roll(land, dy, 0), dx, 1)
        inner = s
    c.tint(land & ~inner, 0.82)
    c.outline(land, (120, 96, 60))
    # a few hills / woods / water on the islands
    for (x, y, r) in ((44, 40, 7), (160, 80, 6), (236, 44, 5)):
        hill = c.ellipse(x, y, r, r * 0.6) & land
        c.fill(hill, (170, 140, 90)); c.shade(hill, (-1, -1), 1.2, 0.7, 1)
    for (x, y) in ((22, 56), (90, 70), (140, 34), (196, 52), (240, 78)):
        wood = c.ellipse(x, y, 7, 4) & land
        c.fill(wood, (104, 150, 86), c.foliage(3), 0.3); c.outline(wood, k=0.7)
    lake = c.ellipse(146, 52, 7, 4) & land
    c.fill(lake, (90, 160, 230)); c.outline(lake, (50, 90, 160))
    # location dots and baked grey labels
    for (x, y, col, row, name) in LOCS:
        c.fill(c.rect(x - 2, y - 2, x + 2, y + 2), (250, 250, 255))
        c.fill(c.rect(x - 1, y - 1, x + 1, y + 1), (210, 210, 220))
        c.outline(c.rect(x - 2, y - 2, x + 2, y + 2), (40, 40, 80))
        stamp(c, col * 8, row * 8, name, (34, 30, 60), (176, 176, 196), (222, 222, 236))
    # ---- portrait grid panel
    panel = c.rect(108, 108, 243, 179)
    c.fill(panel, (40, 36, 72)); c.shade(panel, (-1, -1), 1.3, 0.6, 2)
    for i in range(4):
        for j in range(2):
            cell = c.rect(112 + i * 32, 112 + j * 32, 112 + i * 32 + 31, 112 + j * 32 + 31)
            c.fill(cell, (18, 18, 44), c.value_noise(6, 11 + i + j * 4), 0.25)
            c.outline(cell, (70, 70, 120))
    c.outline(panel, (150, 150, 210))
    # ---- big portrait frame (interior left unpainted: the portrait tiles go there)
    frame = c.rect(4, 116, 107, 219)
    inner = c.rect(8, 120, 103, 215)
    c.fill(frame & ~inner, (150, 150, 210)); c.shade(frame & ~inner, (-1, -1), 1.2, 0.6, 1)
    c.fill(c.rect(4, 116, 107, 117), (210, 210, 240)); c.fill(c.rect(4, 116, 5, 219), (210, 210, 240))
    return c

if __name__ == "__main__":
    c = paint()
    c.image().save(os.path.join(here, "..", "render", "stage9.png"))
    quantize.run(9, os.path.join(here, "..", "render", "stage9.png"), os.path.join(here, "..", "toy"),
                 ((6, 6, 60), (26, 30, 110)), slots=[3, 4, 5, 6, 7], floor_rule=False, label="player select background")
