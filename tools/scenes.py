# scenes.py: the eight Baby Beatdown stages painted with paintlib. python scenes.py [n] renders render/stageN.png
import sys, numpy as np
from paintlib import Canvas, W, H

SKY = {}  # stage -> (top rgb, horizon rgb) for the backdrop HDMA gradient

def sky_preview(c, top, hor):
    """Composite the transparent sky over a gradient for previewing."""
    yy = np.arange(H, dtype=np.float32)[:, None, None] / 168
    g = np.array(top, np.float32) * (1 - np.clip(yy, 0, 1)) + np.array(hor, np.float32) * np.clip(yy, 0, 1)
    g = np.broadcast_to(g, (H, W, 3)).copy()
    out = np.where(c.on[..., None], np.clip(c.rgb, 0, 255), g)
    from PIL import Image
    return Image.fromarray(out.astype(np.uint8))

def spectators(c, specs):
    for (x, yb, h, skin, cloth, hair) in specs:
        c.figure(x, yb, h, skin, cloth, hair)

# ------------------------------------------------------------------ 1 BAYOU PORCH
def bayou():
    c = Canvas(seed=11)
    SKY[1] = ((255, 128, 72), (250, 196, 128))
    # sun
    sun = c.circle(196, 86, 17)
    c.fill(sun, (255, 246, 200)); c.fill(c.circle(196, 86, 13), (255, 252, 230))
    # far cypress line (silhouette, hazy)
    far = c.mask()
    rng = np.random.default_rng(3)
    for i in range(22):
        x = i * 12 + 4 + rng.integers(0, 6)
        h = 24 + rng.integers(0, 22)
        far |= c.poly([(x - 7, 120), (x + 7, 120), (x + 3, 120 - h * 0.5), (x + 1, 120 - h), (x - 1, 120 - h), (x - 3, 120 - h * 0.5)])
    c.fill(far, (66, 96, 96), c.foliage(4), 0.25, vgrad=(90, 120, 0.95, 1.1))
    # water
    water = c.rect(0, 120, 255, 159)
    wn = c.value_noise(9, 21, octaves=2, aspect=0.25)
    c.fill(water, (72, 124, 128), wn, 0.35, vgrad=(120, 159, 1.15, 0.8))
    # reflections: sky colour streaks and the sun path
    yy, xx = np.mgrid[0:H, 0:W]
    refl = water & (np.abs(xx - 196) < 14 - (yy - 120) * 0.1) & (((xx * 3 + yy * 5) % 7) < 3)
    c.fill(refl, (240, 190, 120))
    glints = water & (((xx // 2 + yy * 3) % 11) == 0) & (wn > 0.12)
    c.fill(glints, (170, 220, 210))
    # distant dock posts in water
    for px in (150, 176, 232):
        post = c.rect(px, 110, px + 3, 140)
        c.fill(post, (74, 52, 36), c.wood(5, 99, False), 0.4); c.shade(post, (-1, 0), 1.2, 0.6)
    # big cypress on the right: trunk with buttress roots
    trunk = c.poly([(214, 160), (250, 160), (244, 120), (240, 60), (240, 0), (226, 0), (226, 60), (222, 120)])
    c.fill(trunk, (96, 70, 48), c.wood(7, 99, False, 0.3), 0.6, vgrad=(0, 160, 0.9, 1.05))
    c.shade(trunk, (-1, 0), 1.18, 0.55, 3)
    roots = c.poly([(206, 160), (256, 160), (256, 140), (246, 150), (240, 142), (232, 152), (222, 144)])
    c.fill(roots, (88, 62, 42), c.wood(8, 99, False), 0.5); c.shade(roots, (-1, -1), 1.15, 0.6, 2)
    c.outline(trunk | roots, k=0.5)
    # moss strands hanging from the top right
    for i in range(7):
        x = 196 + i * 8
        strand = c.poly([(x, 0), (x + 3, 0), (x + 2 + (i % 2), 30 + i * 5), (x + 1, 30 + i * 5)])
        c.fill(strand, (120, 150, 110), c.grain(i), 0.3)
    # the shack on the left
    wall = c.rect(0, 64, 96, 158)
    c.fill(wall, (122, 96, 66), c.wood(12, 11, True, 0.22), 0.6, vgrad=(64, 158, 1.0, 0.86))
    roof = c.poly([(0, 66), (108, 66), (104, 50), (0, 44)])
    c.fill(roof, (110, 72, 56), c.wood(13, 6, True), 0.55); c.shade(roof, (-1, -1), 1.25, 0.6, 2)
    c.shadow(roof, 0, 6, 0.6)
    win = c.rect(22, 84, 58, 118)
    c.fill(win, (34, 28, 36)); c.shade(win, (1, 1), 1.3, 0.7, 2)
    glow = c.rect(26, 88, 54, 114)
    c.fill(glow, (120, 74, 40), c.value_noise(6, 33), 0.4)
    shutter = c.rect(58, 82, 70, 120)
    c.fill(shutter, (84, 110, 96), c.wood(14, 5, True), 0.5); c.shade(shutter, (-1, -1), 1.2, 0.6)
    c.outline(win | shutter, k=0.45)
    # porch posts and rail
    for px in (6, 100):
        post = c.rect(px, 66, px + 6, 160)
        c.fill(post, (140, 110, 76), c.wood(15, 99, False), 0.45); c.shade(post, (-1, 0), 1.2, 0.55, 2); c.outline(post, k=0.5)
    rail = c.rect(0, 126, 106, 130)
    c.fill(rail, (150, 118, 80), c.wood(16, 99, True), 0.4); c.shade(rail, (0, -1), 1.2, 0.6)
    # beads on the rail (mardi gras)
    for i, col in enumerate([(150, 60, 200), (90, 210, 100), (255, 210, 60)] * 6):
        x = 8 + i * 5
        y = 131 + int(2 * np.sin(i / 2.5))
        c.fill(c.circle(x, y, 1.6), col)
    # lantern on the post
    lan = c.rect(100, 92, 108, 104); c.fill(lan, (60, 50, 44)); c.fill(c.rect(102, 94, 106, 102), (255, 210, 110)); c.outline(lan, k=0.4)
    # spectators on the porch behind the rail
    spectators(c, [(24, 160, 30, (236, 190, 150), (200, 60, 50), (60, 30, 20)),
                   (52, 160, 26, (120, 80, 50), (240, 200, 70), (20, 12, 10)),
                   (80, 160, 32, (236, 190, 150), (80, 120, 200), (170, 110, 50))])
    # the fighting deck: wide boards running toward the camera
    deck = c.rect(0, 160, 255, 223)
    wt = c.pwood(17, plank=16, pw=32, horizontal=False, grainamt=0.45)
    c.fill(deck, (170, 128, 84), wt, 0.5)
    yy, xx = np.mgrid[0:H, 0:W]
    nails = deck & ((xx % 16) == 8) & ((yy % 32) == 12)
    c.fill(nails, (70, 50, 34))
    edge = c.rect(0, 158, 255, 161)
    c.fill(edge, (205, 164, 108), c.periodic(32, 4, 18), 0.3); c.shade(edge, (0, -1), 1.25, 0.6, 1)
    c.shadow(trunk | roots, -6, 6, 0.7, soft=2)
    c.shadow(c.rect(0, 64, 106, 160), 4, 6, 0.78, soft=2)
    return c


def clouds(c, items, light=(255, 255, 255), shade=(205, 214, 232)):
    for (cx, cy, w) in items:
        m = c.ellipse(cx, cy + 2, w * 0.5, w * 0.2) | c.ellipse(cx - w * 0.28, cy, w * 0.28, w * 0.2) | c.ellipse(cx + w * 0.12, cy - 3, w * 0.3, w * 0.22) | c.ellipse(cx + w * 0.34, cy + 1, w * 0.22, w * 0.15)
        c.fill(m, light, c.value_noise(6, int(cx), octaves=2), 0.08)
        c.shade(m, (0, -1), 1.03, 0.86, 2)
        under = m & ~np.roll(m, 3, 0)
        c.fill(under & m, shade)

def hills(c, y_base, y_bot, amp, color, seed, period=1.5, phase=0.0, tex_amt=0.3):
    yy, xx = np.mgrid[0:H, 0:W]
    a = xx / W * 6.2832
    top = y_base - amp * (0.6 * np.sin(a * period + phase) + 0.3 * np.sin(a * period * 2.3 + phase * 1.7) + 0.1 * np.sin(a * period * 5.1))
    m = (yy >= top) & (yy <= y_bot)
    c.fill(m, color, c.foliage(seed), tex_amt, vgrad=(int(y_base - amp), y_bot, 1.08, 0.92))
    c.shade(m, (0, -1), 1.12, 0.9, 1)
    return m

def picket_fence(c, y_top, y_bot, color, dark, x0=0, x1=W - 1, pitch=10, pw=6):
    yy, xx = np.mgrid[0:H, 0:W]
    inx = (xx >= x0) & (xx <= x1)
    pick = inx & (((xx - x0) % pitch) < pw) & (yy >= y_top) & (yy <= y_bot)
    tip = inx & (((xx - x0) % pitch) < pw) & (yy >= y_top - 3) & (yy < y_top) & (np.abs(((xx - x0) % pitch) - (pw - 1) / 2) <= (yy - (y_top - 3)) * 0.9)
    m = pick | tip
    c.fill(m, color, c.periodic(pitch, 16, 41, cell=4), 0.25)
    c.shade(m, (-1, 0), 1.1, 0.78, 1)
    for ry in (y_top + 10, y_bot - 10):
        rail = c.rect(x0, ry, x1, ry + 3)
        c.fill(rail, dark, c.periodic(32, 4, 42), 0.3); c.shade(rail, (0, -1), 1.15, 0.7, 1)
    c.outline(m, k=0.6)
    return m

def house(c, x0, x1, y_top, y_bot, wall, trim, roof, seed=5):
    body = c.rect(x0, y_top, x1, y_bot)
    c.fill(body, wall, c.pwood(seed, plank=6, pw=64, horizontal=True, grainamt=0.25), 0.5, vgrad=(y_top, y_bot, 1.0, 0.88))
    rf = c.poly([(x0 - 8, y_top), (x1 + 8, y_top), (x1 - 4, y_top - 18), (x0 + 4, y_top - 18)])
    c.fill(rf, roof, c.periodic(32, 8, seed + 1, cell=3), 0.3)
    c.shade(rf, (0, -1), 1.15, 0.7, 2)
    c.shadow(rf, 0, 5, 0.7)
    c.outline(rf, k=0.55)
    return body

def window(c, x0, y0, x1, y1, frame, glass, lit=False):
    f = c.rect(x0, y0, x1, y1)
    c.fill(f, frame); c.shade(f, (-1, -1), 1.15, 0.7, 1)
    g = c.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2)
    c.fill(g, glass, c.value_noise(5, x0, octaves=2), 0.12 if not lit else 0.3)
    mx, my = (x0 + x1) // 2, (y0 + y1) // 2
    c.fill(c.rect(mx, y0 + 2, mx, y1 - 2), frame); c.fill(c.rect(x0 + 2, my, x1 - 2, my), frame)
    if not lit:
        c.fill(g & c.poly([(x0 + 2, y0 + 2), (x1 - 2, y0 + 2), (x0 + 2, y1 - 2)]), [min(255, v * 1.25) for v in glass])
    c.outline(f, k=0.5)

# ------------------------------------------------------------------ 2 BACKYARD
def backyard():
    c = Canvas(seed=22)
    SKY[2] = ((78, 140, 236), (196, 226, 250))
    c.fill(c.circle(40, 28, 15), (255, 252, 220)); c.fill(c.circle(40, 28, 11), (255, 255, 245))
    clouds(c, [(96, 44, 54), (176, 24, 66), (236, 56, 44)])
    hills(c, 108, 124, 10, (116, 170, 104), 3, 1.4, 1.0)
    hills(c, 116, 124, 7, (92, 150, 86), 4, 2.6, 2.5)
    # neighbour house back-left
    body = house(c, 6, 110, 62, 124, (236, 226, 206), (120, 90, 60), (150, 70, 60), 5)
    window(c, 22, 76, 50, 104, (255, 255, 255), (120, 170, 210))
    window(c, 66, 76, 94, 104, (255, 255, 255), (120, 170, 210))
    door = c.rect(104, 90, 112, 124); c.fill(door, (120, 70, 50)); c.outline(door, k=0.5)
    # big oak on the right
    oak = c.tree(226, 128, 118, (96, 66, 44), (62, 134, 62), seed=7, spread=1.15)
    # clothesline from house to oak with diapers
    yy, xx = np.mgrid[0:H, 0:W]
    for x in range(112, 206):
        y = int(70 + ((x - 112) / 94) * 6 + 7 * np.sin((x - 112) / 94 * 3.1416))
        c.rgb[y, x] = (210, 210, 220); c.on[y, x] = True
    for i, dx in enumerate((122, 146, 170, 190)):
        y = int(70 + ((dx - 112) / 94) * 6 + 7 * np.sin((dx - 112) / 94 * 3.1416))
        dia = c.poly([(dx - 6, y + 1), (dx + 6, y + 1), (dx + 4, y + 14), (dx, y + 17), (dx - 4, y + 14)])
        c.fill(dia, (250, 250, 255) if i % 2 == 0 else (255, 222, 236), c.value_noise(4, i), 0.08)
        c.shade(dia, (-1, -1), 1.02, 0.84, 1); c.outline(dia, k=0.7)
        for px in (dx - 4, dx + 4): c.fill(c.rect(px, y, px, y + 2), (230, 180, 60))
    # picket fence across the mid ground, lawn below
    lawn = c.rect(0, 126, 255, 159)
    c.fill(lawn, (96, 168, 84), c.grass(9), 0.25, vgrad=(126, 159, 1.0, 1.08))
    picket_fence(c, 118, 156, (246, 246, 240), (200, 190, 170))
    # doghouse right of centre on the lawn
    dh = c.rect(176, 128, 214, 158); c.fill(dh, (176, 88, 60), c.pwood(8, plank=6, pw=40), 0.45); c.shade(dh, (-1, -1), 1.15, 0.65, 2)
    droof = c.poly([(172, 130), (218, 130), (195, 112)]); c.fill(droof, (90, 56, 40), c.periodic(16, 8, 9), 0.3); c.shade(droof, (-1, -1), 1.2, 0.6, 1)
    hole = c.ellipse(195, 148, 9, 11) & dh; c.fill(hole, (40, 24, 20))
    c.outline(dh | droof, k=0.5)
    bowl = c.ellipse(160, 156, 9, 3); c.fill(bowl, (220, 60, 50)); c.fill(c.ellipse(160, 155, 6, 1.6), (160, 120, 60)); c.outline(bowl, k=0.5)
    # toys: ball and a bone
    ball = c.circle(34, 152, 5); c.fill(ball, (230, 60, 60)); c.fill(ball & c.rect(0, 150, 255, 154), (250, 250, 250)); c.shade(ball, (-1, -1), 1.2, 0.7, 1); c.outline(ball, k=0.5)
    # spectators peeking over the fence (babies with big heads)
    spectators(c, [(52, 128, 24, (236, 190, 150), (255, 210, 70), (60, 30, 20)),
                   (126, 128, 22, (120, 80, 50), (90, 150, 230), (20, 12, 10)),
                   (150, 128, 26, (236, 190, 150), (230, 90, 140), (170, 110, 50))])
    # floor: lawn with a stone path (periodic)
    fl = c.rect(0, 160, 255, 223)
    c.fill(fl, (108, 180, 92), c.periodic(32, 16, 10, cell=3), 0.28)
    clover = fl & (c.periodic(32, 16, 11, cell=2) > 0.22)
    c.fill(clover, (84, 156, 76))
    flowers = fl & (c.periodic(64, 32, 12, cell=2) > 0.40)
    c.fill(flowers, (255, 250, 200))
    edge = c.rect(0, 158, 255, 160); c.fill(edge, (70, 120, 60))
    c.shadow(oak, -8, 6, 0.72, soft=2)
    c.shadow(c.rect(0, 62, 110, 124), 4, 6, 0.8, soft=2)
    return c

# ------------------------------------------------------------------ 3 ROOFTOP
def rooftop():
    c = Canvas(seed=33)
    SKY[3] = ((6, 8, 36), (84, 44, 112))
    rng = np.random.default_rng(5)
    for i in range(90):
        x, y = int(rng.integers(0, 256)), int(rng.integers(0, 112))
        c.rgb[y, x] = (255, 255, 255) if i % 3 else (200, 210, 255); c.on[y, x] = True
    moon = c.circle(204, 34, 14); c.fill(moon, (250, 246, 210)); c.fill(c.circle(199, 30, 3), (225, 220, 180)); c.fill(c.circle(208, 39, 2), (225, 220, 180))
    # far skyline (silhouettes with lit windows)
    yy, xx = np.mgrid[0:H, 0:W]
    far = c.mask()
    for i in range(16):
        x0 = i * 17 + (i % 3) * 4; h = 30 + (i * 37) % 44
        far |= c.rect(x0, 128 - h, x0 + 14, 128)
    c.fill(far, (46, 40, 80), c.value_noise(8, 2), 0.12, vgrad=(50, 128, 0.9, 1.1))
    wins = far & (((xx % 5) == 2) & ((yy % 7) == 3)) & (c.grain(4) > 0.1)
    c.fill(wins, (255, 230, 130))
    # mid buildings (closer, with brick and more windows)
    mid = c.mask()
    for i in range(7):
        x0 = i * 38 + 2; h = 22 + (i * 23) % 26
        b = c.rect(x0, 158 - h, x0 + 28, 158)
        c.fill(b, (92, 78, 112) if i % 2 else (112, 92, 118), c.bricks(8, 4, -0.35, i), 0.35, vgrad=(158 - h, 158, 1.0, 0.86))
        c.fill(c.rect(x0, 158 - h, x0 + 28, 158 - h + 1), (140, 126, 160))
        w = b & (((xx - x0) % 7) >= 2) & (((xx - x0) % 7) <= 4) & (((yy - (158 - h)) % 8) >= 3) & (((yy - (158 - h)) % 8) <= 6)
        c.fill(w & (c.grain(i + 7) > -0.2), (255, 220, 120)); c.fill(w & (c.grain(i + 7) <= -0.2), (40, 36, 60))
        mid |= b
    c.outline(mid, k=0.6)
    # water tower on the left
    legs = c.poly([(22, 158), (26, 158), (36, 96), (34, 96)]) | c.poly([(58, 158), (62, 158), (52, 96), (50, 96)]) | c.rect(28, 130, 56, 132)
    c.fill(legs, (70, 50, 50)); c.shade(legs, (-1, 0), 1.2, 0.6)
    tank = c.rect(24, 66, 62, 98); c.fill(tank, (150, 86, 70), c.pwood(3, plank=5, pw=48, horizontal=False, grainamt=0.3), 0.5); c.shade(tank, (-1, 0), 1.2, 0.55, 3)
    for ry in (72, 84, 94): c.fill(c.rect(24, ry, 62, ry + 1), (70, 44, 40))
    cone = c.poly([(20, 66), (66, 66), (43, 52)]); c.fill(cone, (90, 60, 60), c.periodic(16, 8, 4), 0.3); c.shade(cone, (-1, -1), 1.2, 0.6, 1)
    c.outline(tank | cone | legs, k=0.5)
    # chimney + vent + neon sign on the right
    chim = c.rect(206, 112, 226, 158); c.fill(chim, (120, 60, 56), c.bricks(10, 5, -0.4, 9), 0.4); c.shade(chim, (-1, 0), 1.15, 0.62, 2); c.outline(chim, k=0.5)
    cap = c.rect(203, 108, 229, 113); c.fill(cap, (90, 80, 90)); c.outline(cap, k=0.5)
    vent = c.rect(236, 138, 250, 158); c.fill(vent, (130, 130, 150)); c.shade(vent, (-1, 0), 1.2, 0.6, 2); c.fill(c.ellipse(243, 136, 9, 5), (150, 150, 170)); c.outline(vent, k=0.5)
    sign = c.rect(150, 118, 196, 134); c.fill(sign, (30, 24, 44)); c.outline(sign, k=1.0, color=(255, 90, 160))
    for i, ch in enumerate("ZZZ"):
        c.fill(c.rect(158 + i * 12, 122, 164 + i * 12, 130) & ~c.rect(159 + i * 12, 123, 163 + i * 12, 129), (255, 120, 190))
    # a pillow fort / blanket on the ledge, spectators = kittens on the ledge
    ledge = c.rect(0, 156, 255, 161); c.fill(ledge, (120, 112, 130), c.periodic(32, 6, 6), 0.25); c.shade(ledge, (0, -1), 1.2, 0.7, 1)
    spectators(c, [(100, 156, 22, (210, 210, 230), (90, 90, 140), None),
                   (124, 156, 20, (240, 200, 160), (200, 80, 100), (60, 40, 30))])
    # floor: tar roof with gravel (periodic) and skylight strips
    fl = c.rect(0, 160, 255, 223)
    c.fill(fl, (74, 68, 90), c.periodic(32, 32, 7, cell=2), 0.35)
    grav = fl & (c.periodic(32, 32, 8, cell=1) > 0.28); c.fill(grav, (120, 114, 136))
    for gy in (176, 200):
        strip = c.rect(0, gy, 255, gy + 1); c.fill(strip, (52, 46, 66))
    c.shadow(tank | cone, 6, 6, 0.75, soft=2)
    c.shadow(chim, -4, 4, 0.75, soft=1)
    return c

# ------------------------------------------------------------------ 4 MUD FARM
def farm():
    c = Canvas(seed=44)
    SKY[4] = ((132, 186, 240), (240, 232, 208))
    c.fill(c.circle(214, 24, 14), (255, 252, 225)); c.fill(c.circle(214, 24, 10), (255, 255, 240))
    clouds(c, [(70, 30, 60), (160, 50, 44)])
    hills(c, 100, 122, 9, (164, 186, 96), 3, 1.1, 0.3)
    # crop rows on the far hill
    yy, xx = np.mgrid[0:H, 0:W]
    rows = c.rect(0, 106, 255, 122) & ((((xx + (yy - 106) * 3) // 6) % 2) == 0) & c.on
    c.fill(rows, (130, 150, 70))
    # windmill far right
    pole = c.rect(176, 62, 179, 120); c.fill(pole, (120, 110, 100)); c.shade(pole, (-1, 0), 1.2, 0.6)
    for k in range(4):
        ang = k * 1.5708 + 0.5
        bl = c.poly([(177, 70), (177 + np.cos(ang) * 24 - np.sin(ang) * 3, 70 + np.sin(ang) * 24 + np.cos(ang) * 3), (177 + np.cos(ang) * 24 + np.sin(ang) * 3, 70 + np.sin(ang) * 24 - np.cos(ang) * 3)])
        c.fill(bl, (230, 230, 230)); c.outline(bl, k=0.6)
    # the big red barn, left
    barn = c.rect(6, 72, 118, 158)
    c.fill(barn, (170, 44, 40), c.pwood(5, plank=8, pw=56, horizontal=False, grainamt=0.3), 0.5, vgrad=(72, 158, 1.0, 0.86))
    trimc = (240, 236, 228)
    for (x0, y0, x1, y1) in ((6, 72, 118, 75), (6, 72, 9, 158), (115, 72, 118, 158)):
        c.fill(c.rect(x0, y0, x1, y1), trimc)
    roofm = c.poly([(0, 74), (124, 74), (106, 46), (62, 34), (18, 46)])
    c.fill(roofm, (110, 60, 50), c.periodic(32, 8, 6, cell=3), 0.3); c.shade(roofm, (-1, -1), 1.2, 0.6, 2); c.shadow(roofm, 0, 5, 0.7)
    loft = c.rect(50, 50, 74, 70); c.fill(loft, (60, 30, 26)); c.outline(loft, k=1.0, color=trimc)
    hay_l = c.ellipse(62, 66, 10, 5) & loft; c.fill(hay_l, (230, 190, 90), c.grain(3), 0.3)
    doors = c.rect(40, 104, 86, 158); c.fill(doors, (150, 36, 34), c.pwood(7, plank=8, pw=48, horizontal=False), 0.45)
    for (xa, ya, xb, yb) in ((40, 104, 86, 158), (86, 104, 40, 158)):
        c.fill(c.line_mask(xa, ya, xb, yb, 3), trimc)
    c.fill(c.rect(40, 104, 86, 106), trimc); c.fill(c.rect(40, 104, 42, 158), trimc); c.fill(c.rect(84, 104, 86, 158), trimc); c.fill(c.rect(62, 104, 64, 158), trimc)
    c.outline(barn | roofm, k=0.55)
    # silo right of the barn
    silo = c.rect(126, 58, 150, 158); c.fill(silo, (200, 196, 190), c.periodic(8, 16, 8, cell=4), 0.2); c.shade(silo, (-1, 0), 1.15, 0.6, 5)
    for ry in range(66, 156, 12): c.fill(c.rect(126, ry, 150, ry), (150, 146, 140))
    dome = c.ellipse(138, 58, 13, 8) & c.rect(0, 0, 255, 58); c.fill(dome, (160, 150, 150)); c.shade(dome, (-1, -1), 1.2, 0.6, 2)
    c.outline(silo | dome, k=0.55)
    # fence + hay bales + tree right
    oak = c.tree(226, 124, 64, (100, 70, 44), (80, 140, 60), seed=4)
    picket_fence(c, 132, 156, (190, 150, 90), (120, 90, 50), 156, 255, 14, 4)
    for (bx, by) in ((168, 150), (200, 152)):
        bale = c.ellipse(bx, by, 16, 9); c.fill(bale, (226, 186, 86), c.value_noise(3, bx, octaves=2, aspect=4), 0.3); c.shade(bale, (-1, -1), 1.15, 0.7, 2)
        c.fill(c.rect(bx - 16, by - 2, bx + 16, by - 1) & bale, (150, 110, 50)); c.outline(bale, k=0.55)
    # chickens + a piglet spectator
    for (cx, cy) in ((160, 128), (176, 130), (236, 130)):
        bird = c.ellipse(cx, cy, 4, 3) | c.circle(cx + 3, cy - 3, 2); c.fill(bird, (250, 250, 240)); c.outline(bird, k=0.6)
        c.fill(c.rect(cx + 3, cy - 5, cx + 3, cy - 5), (230, 40, 40)); c.fill(c.rect(cx + 5, cy - 3, cx + 6, cy - 3), (240, 160, 40))
    spectators(c, [(126, 158, 0, (0, 0, 0), (0, 0, 0), None)])
    # floor: mud with periodic puddles and ruts
    fl = c.rect(0, 160, 255, 223)
    c.fill(fl, (138, 96, 56), c.periodic(32, 32, 9, cell=3), 0.3)
    ruts = fl & (((yy % 16) == 5) | ((yy % 16) == 6)) & (c.periodic(32, 16, 10, cell=4) > -0.1); c.fill(ruts, (100, 68, 40))
    pud = fl & (c.periodic(128, 64, 11, cell=16) > 0.21); c.fill(pud, (118, 146, 176), c.periodic(128, 64, 12, cell=3), 0.12)
    c.fill(pud & (c.periodic(128, 64, 13, cell=2) > 0.3), (190, 214, 232))
    wet = fl & ~pud & (c.periodic(128, 64, 11, cell=16) > 0.12); c.tint(wet, 0.86)
    c.outline(pud, k=0.8)
    edge = c.rect(0, 158, 255, 160); c.fill(edge, (96, 66, 38))
    c.shadow(barn | roofm, 5, 7, 0.78, soft=2); c.shadow(silo, 6, 6, 0.75, soft=2); c.shadow(oak, -6, 5, 0.72, soft=2)
    return c

# ------------------------------------------------------------------ 5 DUCK POND
def pond():
    c = Canvas(seed=55)
    SKY[5] = ((84, 156, 238), (212, 238, 250))
    clouds(c, [(44, 34, 50), (150, 22, 66), (226, 46, 40)])
    hills(c, 112, 130, 10, (92, 158, 102), 3, 2.0, 0.8)
    # treeline + willow
    for i in range(9):
        c.tree(10 + i * 28, 130, 34 + (i % 3) * 8, (90, 66, 44), (62, 138, 70), seed=i, spread=1.0)
    wil = c.tree(222, 132, 96, (96, 70, 46), (110, 170, 80), seed=21, spread=1.2)
    yy, xx = np.mgrid[0:H, 0:W]
    for i in range(14):
        x = 186 + i * 5 + (i % 2)
        strand = c.poly([(x, 86 + (i % 3) * 4), (x + 2, 86 + (i % 3) * 4), (x + 1, 128 + (i % 4) * 6)])
        c.fill(strand, (132, 190, 96), c.grain(i), 0.25)
    # wooden dock on the left
    deck = c.poly([(0, 134), (96, 134), (104, 158), (0, 158)])
    c.fill(deck, (160, 120, 78), c.pwood(5, plank=8, pw=48, horizontal=True, grainamt=0.4), 0.5, vgrad=(134, 158, 1.0, 0.86))
    c.shade(deck, (0, -1), 1.15, 0.7, 1); c.outline(deck, k=0.55)
    for px in (8, 56, 100):
        post = c.rect(px, 124, px + 5, 170); c.fill(post, (110, 80, 50), c.wood(6, 99, False), 0.4); c.shade(post, (-1, 0), 1.2, 0.6, 1); c.outline(post, k=0.5)
    # reeds and cattails right/centre
    for i in range(16):
        x = 110 + i * 9 + (i % 3) * 2; top = 118 + (i % 4) * 6
        c.fill(c.rect(x, top, x + 1, 160), (70, 140, 60) if i % 2 else (96, 170, 76))
        c.fill(c.rect(x - 1, top - 9, x + 2, top - 1), (120, 70, 40))
    # spectators: ducklings on the dock
    spectators(c, [(24, 134, 18, (250, 220, 70), (250, 220, 70), None), (44, 134, 16, (250, 220, 70), (250, 220, 70), None), (72, 134, 18, (236, 190, 150), (90, 150, 230), (60, 30, 20))])
    # pond floor: water (periodic ripples) with lily pads and the dock's reflection
    fl = c.rect(0, 160, 255, 223)
    c.fill(fl, (46, 112, 182), c.periodic(64, 16, 7, cell=3), 0.28)
    rip = fl & (c.periodic(64, 16, 8, cell=5) > 0.16); c.fill(rip, (120, 190, 240))
    glint = fl & (c.periodic(64, 16, 9, cell=2) > 0.33); c.fill(glint, (220, 245, 255))
    pads = c.mask()
    for (px, py) in ((40, 184), (84, 204), (150, 178), (196, 210), (236, 186), (120, 216)):
        pad = c.ellipse(px, py, 13, 5) & ~c.poly([(px, py), (px + 14, py - 6), (px + 14, py - 1)])
        c.fill(pad, (76, 160, 84), c.value_noise(3, px), 0.12); c.shade(pad, (-1, -1), 1.15, 0.72, 1); c.outline(pad, k=0.6)
        pads |= pad
    lot = c.ellipse(150, 174, 4, 3) | c.ellipse(147, 172, 2, 3) | c.ellipse(153, 172, 2, 3); c.fill(lot, (255, 150, 190)); c.fill(c.circle(150, 174, 1.4), (255, 230, 120))
    shore = c.rect(0, 158, 255, 161); c.fill(shore, (90, 140, 70), c.periodic(32, 3, 10), 0.2)
    c.shadow(wil, -6, 5, 0.75, soft=2)
    return c

# ------------------------------------------------------------------ 6 HONEY CAVE
def cave():
    c = Canvas(seed=66)
    SKY[6] = ((16, 10, 12), (62, 40, 34))
    # back wall of rock fills the whole upper area
    back = c.rect(0, 0, 255, 159)
    c.fill(back, (84, 64, 58), c.periodic(64, 64, 3, cell=12, octaves=3), 0.5)
    c.tint(c.rect(0, 0, 255, 48), 0.78); c.tint(c.rect(0, 48, 255, 96), 0.9)
    yy, xx = np.mgrid[0:H, 0:W]
    # boulders / rock lumps
    rng = np.random.default_rng(6)
    for i in range(9):
        x, y = int(rng.integers(0, 256)), int(rng.integers(20, 150))
        rk = c.ellipse(x, y, 12 + rng.integers(0, 16), 8 + rng.integers(0, 10))
        c.fill(rk, (112, 86, 74), c.stone(10 + i, 10), 0.35, vgrad=(y - 12, y + 12, 1.1, 0.8))
        c.shade(rk, (-1, -1), 1.18, 0.62, 2); c.outline(rk, k=0.6)
    # stalactites
    for i in range(7):
        x = i * 38 + 12; h = 18 + (i * 7) % 26
        st = c.poly([(x - 7, 0), (x + 7, 0), (x, h)])
        c.fill(st, (104, 80, 70), c.stone(30 + i, 8), 0.3, vgrad=(0, h, 1.05, 0.8)); c.shade(st, (-1, 0), 1.15, 0.6, 1); c.outline(st, k=0.55)
    # honeycomb patches with dripping honey
    for (hx, hy, r) in ((44, 70, 24), (210, 60, 26), (128, 40, 18)):
        comb = c.ellipse(hx, hy, r, r * 0.8)
        c.fill(comb, (232, 160, 48), c.periodic(8, 8, 40 + hx, cell=4), 0.25)
        cells = comb & ((((xx + (yy // 4) * 2) % 8) < 1) | ((yy % 4) < 1)); c.fill(cells, (150, 96, 30))
        c.shade(comb, (-1, -1), 1.15, 0.7, 2); c.outline(comb, k=0.55)
        for k in range(3):
            dx = hx - r * 0.5 + k * r * 0.5
            drip = c.poly([(dx - 3, hy + r * 0.7), (dx + 3, hy + r * 0.7), (dx + 1, hy + r * 0.7 + 14 + k * 6), (dx - 1, hy + r * 0.7 + 14 + k * 6)]) | c.circle(dx, hy + r * 0.7 + 15 + k * 6, 2.5)
            c.fill(drip, (255, 196, 70)); c.shade(drip, (-1, -1), 1.15, 0.75, 1)
    # torch glow (the ambient candle sprites sit here) and honey pots
    for (gx, gy) in ((36, 70), (204, 70), (132, 54)):
        c.tint(c.circle(gx, gy, 26), 1.18, (255, 200, 120))
    for (px, py) in ((22, 150), (236, 150)):
        pot = c.ellipse(px, py, 11, 10) | c.rect(px - 8, py - 13, px + 8, py - 8)
        c.fill(pot, (190, 130, 60), c.value_noise(4, px), 0.15); c.shade(pot, (-1, -1), 1.2, 0.6, 2); c.outline(pot, k=0.5)
        c.fill(c.rect(px - 8, py - 13, px + 8, py - 12), (255, 200, 80))
    # bear-cub spectators on a rock shelf
    shelf = c.poly([(96, 150), (170, 150), (176, 160), (90, 160)]); c.fill(shelf, (120, 92, 80), c.stone(50, 8), 0.3); c.shade(shelf, (0, -1), 1.2, 0.7, 1); c.outline(shelf, k=0.55)
    spectators(c, [(112, 150, 22, (150, 100, 60), (150, 100, 60), (110, 70, 40)), (140, 150, 20, (180, 130, 80), (180, 130, 80), (120, 80, 50))])
    # floor: cave rock (periodic), honey puddles
    fl = c.rect(0, 160, 255, 223)
    c.fill(fl, (96, 80, 80), c.periodic(32, 32, 20, cell=3), 0.4)
    cracks = fl & (np.abs(c.periodic(32, 32, 21, cell=4)) < 0.02); c.fill(cracks, (50, 40, 44))
    hp = fl & (c.periodic(128, 64, 22, cell=16) > 0.24); c.fill(hp, (226, 160, 50), c.periodic(128, 64, 23, cell=3), 0.12); c.fill(hp & (c.periodic(128, 64, 24, cell=2) > 0.32), (255, 220, 120)); c.outline(hp, k=0.7)
    return c

# ------------------------------------------------------------------ 7 CARROT GARDEN
def garden():
    c = Canvas(seed=77)
    SKY[7] = ((250, 168, 192), (255, 240, 214))
    c.fill(c.circle(60, 40, 16), (255, 250, 220)); c.fill(c.circle(60, 40, 12), (255, 255, 240))
    clouds(c, [(150, 30, 52), (230, 60, 38)], (255, 250, 250), (236, 196, 206))
    hills(c, 100, 124, 12, (150, 190, 100), 3, 1.4, 2.0)
    hills(c, 112, 124, 8, (110, 160, 84), 4, 2.2, 0.4)
    # cottage back-right with a chimney
    house(c, 150, 236, 70, 124, (240, 226, 196), (150, 120, 90), (120, 80, 60), 7)
    window(c, 164, 84, 190, 108, (120, 80, 50), (110, 160, 200))
    door = c.rect(206, 92, 222, 124); c.fill(door, (110, 70, 44), c.pwood(9, plank=4, pw=16, horizontal=False), 0.3); c.outline(door, k=0.5)
    chim = c.rect(216, 46, 228, 70); c.fill(chim, (130, 80, 70), c.bricks(6, 3, -0.4, 2), 0.4); c.outline(chim, k=0.5)
    # scarecrow left
    pole = c.rect(40, 70, 43, 130); c.fill(pole, (120, 90, 60)); c.fill(c.rect(22, 86, 62, 89), (120, 90, 60))
    shirt = c.poly([(28, 88), (56, 88), (52, 116), (32, 116)]); c.fill(shirt, (90, 120, 200), c.bricks(12, 12, -0.2, 3), 0.25); c.shade(shirt, (-1, -1), 1.15, 0.7, 1)
    head = c.ellipse(42, 78, 8, 8); c.fill(head, (226, 196, 130), c.grain(2), 0.15); hat = c.poly([(30, 72), (54, 72), (50, 62), (34, 62)]) | c.rect(26, 71, 58, 73); c.fill(hat, (180, 150, 80)); c.outline(head | hat | shirt, k=0.55)
    for (ex, ey) in ((39, 77), (45, 77)): c.fill(c.rect(ex, ey, ex, ey), (20, 16, 20))
    # picket fence + raised beds in the mid ground
    picket_fence(c, 122, 150, (246, 246, 240), (190, 180, 160), 0, 255, 10, 6)
    yy, xx = np.mgrid[0:H, 0:W]
    bed = c.rect(0, 150, 255, 159); c.fill(bed, (110, 76, 46), c.periodic(32, 10, 5), 0.3)
    # bunny spectators behind the fence, plus a watering can
    spectators(c, [(84, 128, 24, (236, 236, 240), (236, 236, 240), None), (112, 128, 20, (210, 190, 180), (255, 180, 200), None), (236, 128, 26, (236, 190, 150), (90, 170, 90), (170, 110, 50))])
    can = c.ellipse(132, 150, 10, 7) | c.rect(140, 140, 150, 143) | c.rect(122, 138, 142, 141); c.fill(can, (100, 150, 110)); c.shade(can, (-1, -1), 1.2, 0.65, 2); c.outline(can, k=0.5)
    # floor: soil rows with carrot tops (periodic 64x32)
    fl = c.rect(0, 160, 255, 223)
    c.fill(fl, (128, 88, 52), c.periodic(64, 32, 11, cell=3), 0.3)
    furrow = fl & (((yy - 160) % 16) < 2); c.fill(furrow, (90, 60, 36))
    crown = fl & (((yy - 160) % 16) >= 9) & (((yy - 160) % 16) <= 11) & (((xx + ((yy - 160) // 16) * 7) % 16) < 5); c.fill(crown, (240, 130, 40))
    leaf = fl & (((yy - 160) % 16) >= 5) & (((yy - 160) % 16) <= 9) & (((xx + ((yy - 160) // 16) * 7) % 16) < 6) & (c.periodic(16, 16, 12, cell=2) > -0.15); c.fill(leaf, (90, 180, 70))
    c.fill(leaf & (c.periodic(16, 16, 13, cell=1) > 0.2), (150, 230, 110))
    edge = c.rect(0, 158, 255, 160); c.fill(edge, (80, 52, 32))
    c.shadow(c.rect(150, 52, 236, 124), 5, 6, 0.8, soft=2)
    return c

# ------------------------------------------------------------------ 8 BIG LEAF
def bigleaf():
    c = Canvas(seed=88)
    SKY[8] = ((214, 244, 160), (124, 200, 96))
    c.sun_haze(130, 20, 60, (255, 255, 220), 0.0)
    # giant blurred leaves far back (bokeh)
    for (cx, cy, r, col) in ((60, 36, 30, (170, 224, 120)), (200, 54, 24, (160, 216, 112)), (130, 22, 18, (200, 240, 150))):
        m = c.circle(cx, cy, r); c.fill(m, col, c.value_noise(8, cx), 0.08); c.fill(c.circle(cx, cy, r * 0.6), [min(255, v * 1.1) for v in col])
    # towering grass blades
    yy, xx = np.mgrid[0:H, 0:W]
    for i in range(18):
        x = i * 15 + (i % 3) * 4; h = 60 + (i * 29) % 70
        bl = c.poly([(x - 5, 160), (x + 5, 160), (x + 2 + (i % 2) * 8, 160 - h), (x + 1 + (i % 2) * 8, 160 - h - 6)])
        c.fill(bl, (72, 150, 62) if i % 2 else (96, 176, 78), c.value_noise(4, i, aspect=5), 0.2, vgrad=(160 - h, 160, 1.15, 0.85))
        c.shade(bl, (-1, 0), 1.2, 0.68, 1); c.outline(bl, k=0.6)
    # a giant leaf arching over from the right with veins
    big = c.ellipse(226, 70, 70, 36) & c.rect(150, 0, 255, 110)
    c.fill(big, (88, 170, 76), c.value_noise(6, 9), 0.18, vgrad=(34, 110, 1.1, 0.85))
    for k in range(-3, 4):
        c.fill(c.line_mask(236, 70, 170 + abs(k) * 6, 70 + k * 11, 1) & big, (60, 130, 56))
    c.fill(c.line_mask(256, 70, 160, 72, 2) & big, (56, 124, 52))
    c.shade(big, (-1, -1), 1.15, 0.7, 2); c.outline(big, k=0.55)
    # mushrooms and a flower left
    for (mx, my, r, col) in ((34, 150, 16, (220, 70, 60)), (62, 154, 10, (230, 170, 80))):
        stem = c.rect(mx - r * 0.3, my - 4, mx + r * 0.3, 160); c.fill(stem, (240, 230, 210)); c.shade(stem, (-1, 0), 1.1, 0.75, 2)
        cap = c.ellipse(mx, my - 4, r, r * 0.55) & c.rect(0, 0, 255, my - 2); c.fill(cap, col, c.value_noise(5, mx), 0.12); c.shade(cap, (-1, -1), 1.15, 0.7, 2)
        spots = cap & (c.periodic(8, 6, mx, cell=3) > 0.26); c.fill(spots, (255, 250, 240)); c.outline(cap | stem, k=0.55)
    stem = c.rect(118, 90, 121, 160); c.fill(stem, (80, 150, 70)); c.shade(stem, (-1, 0), 1.1, 0.7)
    for k in range(6):
        ang = k / 6 * 6.283
        pet = c.ellipse(119 + np.cos(ang) * 12, 84 + np.sin(ang) * 12, 9, 6); c.fill(pet, (255, 140, 190), c.value_noise(4, k), 0.1); c.shade(pet, (-1, -1), 1.12, 0.75, 1); c.outline(pet, k=0.6)
    core = c.circle(119, 84, 7); c.fill(core, (255, 220, 90)); c.fill(core & (c.grain(3) > 0.2), (230, 170, 50)); c.outline(core, k=0.6)
    # dew drops on the big leaf, ladybug spectators on a twig
    for (dx, dy, r) in ((200, 84, 6), (236, 96, 5), (178, 60, 4)):
        d = c.circle(dx, dy, r); c.fill(d, (150, 215, 240)); c.fill(c.circle(dx - r * 0.35, dy - r * 0.35, r * 0.35), (240, 252, 255)); c.outline(d, k=0.65)
    twig = c.poly([(140, 140), (250, 132), (250, 136), (140, 146)]); c.fill(twig, (120, 84, 50), c.wood(4, 99, True), 0.4); c.outline(twig, k=0.55)
    for (bx, by, col) in ((170, 134, (230, 50, 50)), (196, 132, (240, 150, 40)), (224, 130, (230, 50, 50))):
        bug = c.ellipse(bx, by, 7, 5); c.fill(bug, col); c.fill(c.circle(bx - 6, by, 3), (30, 24, 30)); c.fill(bug & (c.periodic(5, 5, bx, cell=2) > 0.25), (30, 24, 30)); c.outline(bug, k=0.5)
    # floor: a giant leaf surface (periodic cells + veins)
    fl = c.rect(0, 160, 255, 223)
    c.fill(fl, (108, 196, 92), c.periodic(32, 32, 13, cell=4), 0.22)
    cells = fl & (np.abs(c.periodic(32, 32, 14, cell=5)) < 0.03); c.fill(cells, (70, 150, 66))
    veins = fl & ((((xx - 128) * 3 + (yy - 160) * 5) % 64) < 2); c.fill(veins, (62, 138, 60))
    mid = fl & (np.abs(xx - 128) < 2); c.fill(mid, (56, 126, 56))
    edge = c.rect(0, 158, 255, 160); c.fill(edge, (60, 130, 60))
    c.shadow(big, -8, 8, 0.75, soft=3)
    return c

SCENES = { 1: bayou, 2: backyard, 3: rooftop, 4: farm, 5: pond, 6: cave, 7: garden, 8: bigleaf }


if __name__ == "__main__":
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "render")
    ids = [int(a) for a in sys.argv[1:]] or sorted(SCENES)
    for i in ids:
        c = SCENES[i]()
        c.image().save(os.path.join(out, f"stage{i}.png"))
        sky_preview(c, *SKY[i]).resize((W * 2, H * 2), 0).save(os.path.join(out, f"stage{i}_preview.png"))
        print("rendered", i, "painted px", int(c.on.sum()))
