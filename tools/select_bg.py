# select_bg.py: paints the player-select background: a map of the United States with the eight stage
# locations, the portrait grid panel and the big-portrait frame. Quantized as stage 9 using BG palettes 3..7
# only (palette 0 is kept for the big portrait, 1 and 2 are the HUD font).
# Layout (pixels): map 8..248 x 16..100; big portrait 8..104 x 120..216; grid cells 32x32 at
# x = 112 + i*32, y = 112 / 144. python select_bg.py writes render/stage9.png.
import sys, os, json, numpy as np
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import paintlib
paintlib.W = 256
from paintlib import Canvas
W, H = 256, 224

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

# the lower 48 states as a coarse outline in map pixels (x 12..244, y 20..98), traced clockwise from Seattle
USA = [(16, 22), (40, 20), (70, 24), (100, 22), (130, 20), (156, 22), (176, 26), (196, 22), (214, 20), (230, 26), (238, 34),
       (232, 42), (222, 48), (216, 56), (208, 62), (214, 68), (218, 76), (212, 84), (204, 80), (196, 76), (186, 80), (178, 86),
       (170, 96), (164, 90), (156, 84), (148, 86), (140, 84), (128, 86), (118, 84), (108, 80), (100, 84), (92, 88), (84, 80),
       (72, 78), (60, 74), (48, 70), (36, 64), (24, 56), (14, 44), (12, 32)]
# stage dots: (x, y, label col, label row, label) — the labels are what the game lights up (STAGE_NAME)
LOCS = [(22, 58, 1, 9, "LA"), (178, 40, 20, 3, "OHIO"), (218, 34, 24, 2, "NYC"), (128, 44, 13, 7, "IOWA"),
        (134, 26, 15, 2, "MINN"), (168, 56, 17, 8, "KENTUCKY"), (184, 68, 21, 10, "GEORGIA"), (198, 90, 22, 12, "FLORIDA")]

def paint():
    c = Canvas(seed=9)
    land = c.poly(USA)
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
    inner = land
    for r in (1, 2, 3):
        s = land
        for dx, dy in ((r, 0), (-r, 0), (0, r), (0, -r)):
            s = s & np.roll(np.roll(land, dy, 0), dx, 1)
        inner = s
    c.tint(land & ~inner, 0.82)
    c.outline(land, (120, 96, 60))
    # relief: the Rockies and Appalachians, woods, the Great Lakes, the Mississippi
    for (x, y, r) in ((50, 40, 9), (62, 54, 7), (44, 60, 6), (192, 50, 6), (186, 60, 5)):
        hill = c.ellipse(x, y, r, r * 0.6) & land
        c.fill(hill, (170, 140, 90)); c.shade(hill, (-1, -1), 1.2, 0.7, 1)
    for (x, y) in ((100, 34), (120, 40), (88, 62), (150, 68), (204, 46)):
        wood = c.ellipse(x, y, 7, 4) & land
        c.fill(wood, (104, 150, 86), c.foliage(3), 0.3); c.outline(wood, k=0.7)
    lakes = (c.ellipse(160, 30, 10, 4) | c.ellipse(172, 34, 6, 3) | c.ellipse(148, 28, 5, 3)) & land
    c.fill(lakes, (90, 160, 230)); c.outline(lakes, (50, 90, 160))
    river = c.mask()
    for i in range(60):
        x = 128 + int(4 * np.sin(i / 6.0)); y = 30 + i
        if y < 92: river |= c.rect(x, y, x + 1, y)
    c.fill(river & land, (90, 160, 230))
    for (x, y, col, row, name) in LOCS:
        c.fill(c.rect(x - 2, y - 2, x + 2, y + 2), (250, 250, 255))
        c.fill(c.rect(x - 1, y - 1, x + 1, y + 1), (210, 210, 220))
        c.outline(c.rect(x - 2, y - 2, x + 2, y + 2), (40, 40, 80))
        stamp(c, col * 8, row * 8, name, (34, 30, 60), (176, 176, 196), (222, 222, 236))
    panel = c.rect(108, 108, 243, 179)
    c.fill(panel, (40, 36, 72)); c.shade(panel, (-1, -1), 1.3, 0.6, 2)
    for i in range(4):
        for j in range(2):
            cell = c.rect(112 + i * 32, 112 + j * 32, 112 + i * 32 + 31, 112 + j * 32 + 31)
            c.fill(cell, (18, 18, 44), c.value_noise(6, 11 + i + j * 4), 0.25)
            c.outline(cell, (70, 70, 120))
    c.outline(panel, (150, 150, 210))
    frame = c.rect(4, 116, 107, 219)
    inner = c.rect(8, 120, 103, 215)
    c.fill(frame & ~inner, (150, 150, 210)); c.shade(frame & ~inner, (-1, -1), 1.2, 0.6, 1)
    c.fill(c.rect(4, 116, 107, 117), (210, 210, 240)); c.fill(c.rect(4, 116, 5, 219), (210, 210, 240))
    return c

if __name__ == "__main__":
    c = paint()
    c.image().save(os.path.join(here, "..", "render", "stage9.png"))
    print("rendered the select map")
