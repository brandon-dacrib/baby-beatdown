# scenes2.py: the eight Baby Beatdown arenas painted at the full 384x224 arena width in the Street Fighter II
# recipe: a sky band (transparent for the backdrop gradient) with clouds / sun / skyline, a tall middle layer
# with big structures and large spectators with real faces, flanking props at both edges, and a perspective
# floor (converging planks / tiles / ruts) from y = 156 to the bottom. The fighters' feet are at y = 176.
# python scenes2.py [n...] renders render/stageN.png (+ _preview.png). Replaces scenes.py for the native build.
import sys, os, math
import numpy as np
import paintlib
paintlib.W = 384
from paintlib import Canvas
W, H = 384, 224
FLOOR0 = 156          # far edge of the floor band
VX, VY = 192, 96      # vanishing point for floor perspective

SKY = {}

# ------------------------------------------------------------------ people
SKINS = {"ivory": (246, 206, 172), "tan": (216, 162, 112), "brown": (152, 96, 56), "dark": (96, 60, 40)}
def mouth_colour(skin):
    # lips are a darker, slightly redder shade of the person's own skin: never one pink for everyone
    r, g, b = skin
    return (int(r * 0.55 + 70 * 0.45), int(g * 0.45 + 30 * 0.55), int(b * 0.45 + 40 * 0.55))

def person(c, x, yb, h, skin, shirt, pants, hair=None, hat=None, pose="stand", seed=0, flip=False):
    """A spectator h pixels tall, feet at yb, centre x. pose: stand / cheer / sit / lean. Returns the mask."""
    skin = SKINS.get(skin, skin)
    hr = h * 0.11                       # head radius
    hy = yb - h + hr + 1                # head centre
    tw = h * 0.17                       # torso half width
    s = -1 if flip else 1
    parts = c.mask()
    if pose == "sit":
        torso = c.poly([(x - tw, hy + hr * 0.9), (x + tw, hy + hr * 0.9), (x + tw, yb - h * 0.3), (x - tw, yb - h * 0.3)])
        legs = c.rect(x - tw * 1.2, yb - h * 0.3, x + tw * 1.4, yb - h * 0.12) | c.rect(x + tw * 0.6, yb - h * 0.3, x + tw * 1.4, yb)
    else:
        torso = c.poly([(x - tw, hy + hr * 0.9), (x + tw, hy + hr * 0.9), (x + tw * 0.9, yb - h * 0.42), (x - tw * 0.9, yb - h * 0.42)])
        legs = c.rect(x - tw * 0.85, yb - h * 0.44, x - tw * 0.1, yb) | c.rect(x + tw * 0.1, yb - h * 0.44, x + tw * 0.85, yb)
    aw = max(2, h * 0.06)
    if pose == "cheer":
        arms = c.line_mask(x - tw, hy + hr * 1.6, x - tw * 1.8, hy - hr * 1.2, aw) | c.line_mask(x + tw, hy + hr * 1.6, x + tw * 1.8, hy - hr * 1.4, aw)
    elif pose == "lean":
        arms = c.line_mask(x - tw, hy + hr * 1.6, x - tw * 1.6, yb - h * 0.45, aw) | c.line_mask(x + tw, hy + hr * 1.6, x + tw * 0.4, yb - h * 0.38, aw)
    else:
        arms = c.line_mask(x - tw, hy + hr * 1.6, x - tw * 1.35, yb - h * 0.40, aw) | c.line_mask(x + tw, hy + hr * 1.6, x + tw * 1.35, yb - h * 0.40, aw)
    hands = c.circle(x - tw * (1.8 if pose == "cheer" else 1.35), (hy - hr * 1.2) if pose == "cheer" else (yb - h * 0.40), aw * 0.9) | \
            c.circle(x + tw * (1.8 if pose == "cheer" else 1.35), (hy - hr * 1.4) if pose == "cheer" else (yb - h * 0.40), aw * 0.9)
    shoes = c.rect(x - tw * 0.95, yb - 2, x - tw * 0.05, yb) | c.rect(x + tw * 0.05, yb - 2, x + tw * 0.95, yb)
    head = c.ellipse(x, hy, hr, hr * 1.1)
    neck = c.rect(x - hr * 0.35, hy + hr * 0.8, x + hr * 0.35, hy + hr * 1.3)
    c.fill(legs, pants, c.grain(seed), 0.12); c.shade(legs, (-1, 0), 1.15, 0.7, 1)
    c.fill(shoes, (40, 30, 34))
    c.fill(torso, shirt, c.grain(seed + 1), 0.12); c.shade(torso, (-1, -1), 1.22, 0.68, 2)
    c.fill(arms, shirt); c.shade(arms, (-1, 0), 1.15, 0.7, 1)
    c.fill(hands, skin); c.fill(neck, [v * 0.85 for v in skin])
    c.fill(head, skin); c.shade(head, (-1, -1), 1.12, 0.74, 2)
    body = legs | shoes | torso | arms | hands | neck | head
    if hair is not None:
        hm = c.ellipse(x, hy - hr * 0.35, hr * 1.02, hr * 0.8) & ~c.ellipse(x, hy + hr * 0.25, hr * 0.95, hr * 0.8)
        c.fill(hm, hair, c.grain(seed + 2), 0.15); c.shade(hm, (-1, -1), 1.2, 0.7, 1)
        body |= hm
    if hat is not None:
        kind, col = hat
        if kind == "cap":
            hm = c.ellipse(x, hy - hr * 0.5, hr * 1.05, hr * 0.7) | c.rect(x + s * hr * 0.2, hy - hr * 0.4, x + s * hr * 1.9, hy - hr * 0.15)
        elif kind == "straw":
            hm = c.ellipse(x, hy - hr * 0.6, hr * 1.0, hr * 0.7) | c.rect(x - hr * 1.8, hy - hr * 0.35, x + hr * 1.8, hy - hr * 0.1)
        else:  # beanie
            hm = c.ellipse(x, hy - hr * 0.45, hr * 1.05, hr * 0.85)
        c.fill(hm, col); c.shade(hm, (-1, -1), 1.2, 0.7, 1)
        body |= hm
    c.outline(body, k=0.42)
    # face: whites, pupils, brows, a mouth in the person's own darker tone
    ex = hr * 0.42; ey = hy - hr * 0.1
    for dx in (-ex, ex):
        c.fill(c.ellipse(x + dx, ey, max(1.2, hr * 0.26), max(1.2, hr * 0.3)), (250, 248, 244))
        px, py = int(x + dx + s * 0.3), int(ey)
        if 0 <= px < W and 0 <= py < H: c.rgb[py, px] = (22, 18, 26)
        c.fill(c.rect(x + dx - hr * 0.3, ey - hr * 0.55, x + dx + hr * 0.3, ey - hr * 0.45), [v * 0.5 for v in skin])
    mw = max(1, int(hr * 0.5)); my = int(hy + hr * 0.5)
    c.fill(c.rect(x - mw, my, x + mw, my + max(1, int(hr * 0.12))), mouth_colour(skin))
    return body

def crowd(c, specs):
    for sp in specs: person(c, *sp[:3], **sp[3])

# ------------------------------------------------------------------ floors (perspective)
def _horizon_rows(y0, y1, n, power=1.7):
    return [y0 + (y1 - y0) * (i / n) ** power for i in range(n + 1)]

def floor_planks(c, color, seam=(0.55, 0.5, 0.45), y0=FLOOR0, y1=H - 1, nx=12, seed=4, along=True):
    m = c.rect(0, y0, W - 1, y1)
    c.fill(m, color, c.value_noise(7, seed, octaves=2, aspect=0.2), 0.3, vgrad=(y0, y1, 0.86, 1.08))
    yy, xx = np.mgrid[0:H, 0:W]
    lines = c.mask()
    if along:   # planks run toward the camera: seams converge on the vanishing point
        for i in range(nx + 1):
            xb = -W * 0.3 + i * (W * 1.6 / nx)
            lines |= c.line_mask(VX + (xb - VX) * 0.25, y0, xb, y1 + 1, 1)
        for y in _horizon_rows(y0, y1, 5, 1.9)[1:-1]:
            lines |= c.rect(0, y, W - 1, y)
    else:       # planks run across: rows get taller toward the camera
        for y in _horizon_rows(y0, y1, 9, 1.6)[1:-1]:
            lines |= c.rect(0, y, W - 1, y)
            lines |= c.rect(0, y + 1, W - 1, y + 1)
        rng = np.random.default_rng(seed)
        for y in _horizon_rows(y0, y1, 9, 1.6)[:-1]:
            for k in range(4):
                xx0 = rng.integers(0, W); lines |= c.rect(xx0, y, xx0, y + 12)
    lines &= m
    c.rgb[lines] *= np.array(seam, np.float32)
    c.outline(m, k=0.7)

def floor_tiles(c, color, grout=(0.55, 0.52, 0.5), y0=FLOOR0, y1=H - 1, nx=10, ny=6, seed=5, tex=None):
    m = c.rect(0, y0, W - 1, y1)
    c.fill(m, color, tex if tex is not None else c.stone(seed, 9), 0.22, vgrad=(y0, y1, 0.88, 1.06))
    lines = c.mask()
    for i in range(nx + 1):
        xb = -W * 0.25 + i * (W * 1.5 / nx)
        lines |= c.line_mask(VX + (xb - VX) * 0.3, y0, xb, y1 + 1, 1)
    for y in _horizon_rows(y0, y1, ny, 1.8)[1:-1]:
        lines |= c.rect(0, y, W - 1, y)
    lines &= m
    c.rgb[lines] *= np.array(grout, np.float32)
    c.outline(m, k=0.7)

def floor_ground(c, color, streak=(0.8, 0.78, 0.72), y0=FLOOR0, y1=H - 1, seed=6, kind="dirt"):
    m = c.rect(0, y0, W - 1, y1)
    tex = c.grass(seed) if kind == "grass" else c.value_noise(5, seed, octaves=3, aspect=0.25)
    c.fill(m, color, tex, 0.35, vgrad=(y0, y1, 0.86, 1.08))
    rng = np.random.default_rng(seed)
    streaks = c.mask()
    for y in _horizon_rows(y0, y1, 14, 1.5)[1:-1]:
        x0 = rng.integers(-40, W); x1 = x0 + rng.integers(30, 140)
        streaks |= c.rect(x0, y, x1, y + (1 if y < 190 else 2))
    c.rgb[streaks & m] *= np.array(streak, np.float32)
    c.outline(m, k=0.7)

# ------------------------------------------------------------------ props
def crate(c, x0, y0, x1, y1, color=(190, 140, 80), seed=1):
    m = c.rect(x0, y0, x1, y1)
    c.fill(m, color, c.wood(seed, 7, True, 0.3), 0.5); c.shade(m, (-1, -1), 1.3, 0.6, 2)
    bars = c.rect(x0, y0, x1, y0 + 3) | c.rect(x0, y1 - 3, x1, y1) | c.rect(x0, y0, x0 + 3, y1) | c.rect(x1 - 3, y0, x1, y1)
    bars |= c.line_mask(x0, y0, x1, y1, 3) | c.line_mask(x1, y0, x0, y1, 3)
    c.fill(bars & m, [v * 0.8 for v in color]); c.shade(bars & m, (-1, -1), 1.2, 0.7, 1)
    c.outline(m, k=0.45); c.shadow(m, 4, 3, 0.6)
    return m

def barrel(c, cx, yb, w, h, color=(150, 90, 50), band=(90, 90, 100), seed=2):
    m = c.poly([(cx - w * 0.42, yb), (cx + w * 0.42, yb), (cx + w * 0.5, yb - h * 0.5), (cx + w * 0.42, yb - h), (cx - w * 0.42, yb - h), (cx - w * 0.5, yb - h * 0.5)])
    c.fill(m, color, c.wood(seed, 99, False, 0.35), 0.45); c.shade(m, (-1, 0), 1.3, 0.55, 3)
    for k in (0.15, 0.5, 0.85):
        b = c.rect(cx - w * 0.52, yb - h * k - 1, cx + w * 0.52, yb - h * k + 1) & (m | c.rect(cx - w * 0.52, yb - h * k - 1, cx + w * 0.52, yb - h * k + 1))
        c.fill(b & m, band); c.shade(b & m, (0, -1), 1.3, 0.7, 1)
    c.outline(m, k=0.45); c.shadow(m, 4, 2, 0.6)
    return m

def pot(c, cx, yb, w, h, color=(210, 150, 60), seed=3):
    m = c.poly([(cx - w * 0.3, yb), (cx + w * 0.3, yb), (cx + w * 0.5, yb - h * 0.55), (cx + w * 0.35, yb - h * 0.85), (cx + w * 0.4, yb - h), (cx - w * 0.4, yb - h), (cx - w * 0.35, yb - h * 0.85), (cx - w * 0.5, yb - h * 0.55)])
    c.fill(m, color, c.value_noise(4, seed), 0.2, vgrad=(yb - h, yb, 1.05, 0.85)); c.shade(m, (-1, -1), 1.3, 0.55, 3)
    c.fill(c.rect(cx - w * 0.4, yb - h, cx + w * 0.4, yb - h + 2) & m, [v * 0.7 for v in color])
    c.outline(m, k=0.45); c.shadow(m, 3, 2, 0.6)
    return m

def window(c, x0, y0, x1, y1, frame, glass, lit=False, bars=True):
    f = c.rect(x0, y0, x1, y1); g = c.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3)
    c.fill(f, frame); c.shade(f, (-1, -1), 1.25, 0.65, 1)
    c.fill(g, glass, c.value_noise(6, 21), 0.25, vgrad=(y0, y1, 1.15, 0.85))
    if lit:
        c.fill(c.rect(x0 + 5, y0 + 5, x1 - 5, y1 - 5), [min(255, v * 1.1) for v in glass])
    if bars:
        mid = c.rect((x0 + x1) // 2 - 1, y0, (x0 + x1) // 2 + 1, y1) | c.rect(x0, (y0 + y1) // 2 - 1, x1, (y0 + y1) // 2 + 1)
        c.fill(mid & f, frame)
    c.outline(f, k=0.45)
    return f

def lantern(c, cx, cy, r, color=(255, 200, 90), glow=True):
    if glow: c.sun_haze(cx, cy, r * 3, color, 0.35)
    m = c.ellipse(cx, cy, r, r * 1.25)
    c.fill(m, color, c.value_noise(3, 7), 0.15); c.shade(m, (-1, -1), 1.15, 0.65, 2)
    c.fill(c.rect(cx - r * 0.3, cy - r * 1.6, cx + r * 0.3, cy - r * 1.1), (60, 40, 30))
    c.outline(m, (80, 40, 20))
    return m

def clouds(c, items, light=(255, 255, 255), shade=(200, 210, 232)):
    for (x, y, w) in items:
        m = c.ellipse(x, y, w, w * 0.4) | c.ellipse(x - w * 0.45, y + w * 0.1, w * 0.55, w * 0.32) | c.ellipse(x + w * 0.45, y + w * 0.12, w * 0.5, w * 0.3) | c.ellipse(x + w * 0.1, y - w * 0.2, w * 0.4, w * 0.35)
        c.fill(m, light, c.value_noise(8, int(x)), 0.08)
        c.fill(m & c.rect(0, y + w * 0.12, W - 1, H - 1), shade)
        c.outline(m, k=0.88)

def sun(c, cx, cy, r, core=(255, 250, 215), rim=(255, 225, 150)):
    c.fill(c.circle(cx, cy, r), rim); c.fill(c.circle(cx, cy, r * 0.8), core)

def hills(c, y_base, y_bot, amp, color, seed, period=1.5, phase=0.0, tex_amt=0.3):
    xx = np.arange(W)
    top = y_base - amp * (0.6 + 0.4 * np.sin(xx / W * period * 6.283 + phase)) - amp * 0.3 * np.sin(xx / 17.0 + seed)
    m = c.mask()
    for x in range(W): m[int(max(0, top[x])):y_bot + 1, x] = True
    c.fill(m, color, c.foliage(seed), tex_amt, vgrad=(y_base - amp, y_bot, 1.1, 0.9))
    c.outline(m, k=0.75)
    return m

def picket_fence(c, y_top, y_bot, color, dark, x0=0, x1=W - 1, pitch=10, pw=6):
    m = c.mask()
    for x in range(x0, x1, pitch):
        m |= c.poly([(x, y_bot), (x + pw, y_bot), (x + pw, y_top + 3), (x + pw / 2, y_top), (x, y_top + 3)])
    rails = c.rect(x0, y_top + 8, x1, y_top + 11) | c.rect(x0, y_bot - 10, x1, y_bot - 7)
    c.fill(rails, dark); c.fill(m, color, c.wood(3, 99, False, 0.2), 0.3); c.shade(m, (-1, 0), 1.15, 0.7, 1)
    c.outline(m, k=0.6)
    return m | rails

def skyline(c, y_base, seed, color, lit=(255, 220, 130), n=16, lo=20, hi=80):
    rng = np.random.default_rng(seed)
    m = c.mask(); x = -10
    while x < W:
        w = int(rng.integers(16, 40)); h = int(rng.integers(lo, hi))
        b = c.rect(x, y_base - h, x + w, y_base); m |= b
        c.fill(b, color, c.value_noise(4, seed + x), 0.1, vgrad=(y_base - h, y_base, 1.1, 0.85))
        for wy in range(y_base - h + 4, y_base - 4, 6):
            for wx in range(x + 3, x + w - 3, 5):
                if rng.random() < 0.45: c.fill(c.rect(wx, wy, wx + 2, wy + 3), lit)
        x += w + int(rng.integers(0, 4))
    c.outline(m, k=0.6)
    return m

# ------------------------------------------------------------------ 1 LOS ANGELES: Venice Beach boardwalk at sunset
# Brandon is Creole, born in Los Angeles: palms, the Pacific, a pier, muscle-beach spectators, skate rails.
def bayou():
    c = Canvas(seed=11); SKY[1] = ((255, 120, 80), (255, 210, 140))
    sun(c, 300, 78, 22, (255, 250, 210), (255, 220, 150))
    clouds(c, [(60, 28, 36), (190, 20, 30), (330, 36, 26)], (255, 236, 214), (240, 160, 120))
    hills(c, 100, 112, 10, (150, 120, 140), 2, period=1.1)                                   # Santa Monica mountains, hazy
    # ocean with a sun path, the pier on the right
    water = c.rect(0, 108, W - 1, 142); wn = c.value_noise(9, 21, octaves=2, aspect=0.25)
    c.fill(water, (60, 130, 170), wn, 0.3, vgrad=(108, 142, 1.1, 0.85))
    yy, xx = np.mgrid[0:H, 0:W]
    c.fill(water & (np.abs(xx - 300) < 18 - (yy - 108) * 0.3) & (((xx * 3 + yy * 5) % 7) < 3), (255, 210, 140))
    c.fill(water & (((xx // 2 + yy * 3) % 11) == 0) & (wn > 0.12), (190, 230, 240))
    surf = water & (yy >= 138) & (((xx + yy * 2) % 9) < 4); c.fill(surf, (235, 245, 250))
    pier = c.rect(250, 96, 384, 104); c.fill(pier, (120, 90, 60), c.wood(5, 99, True, 0.3), 0.4); c.shade(pier, (0, -1), 1.2, 0.6, 1); c.outline(pier, k=0.5)
    for px in range(262, 384, 24):
        post = c.rect(px, 104, px + 3, 140); c.fill(post, (90, 66, 44)); c.outline(post, k=0.5)
    wheel = c.circle(330, 60, 30) & ~c.circle(330, 60, 26); c.fill(wheel, (240, 240, 250))
    for k in range(8):
        a_ = k * math.pi / 4; sp = c.line_mask(330, 60, 330 + math.cos(a_) * 28, 60 + math.sin(a_) * 28, 2); c.fill(sp, (230, 230, 240))
        c.fill(c.circle(330 + math.cos(a_) * 28, 60 + math.sin(a_) * 28, 3), [(240, 80, 90), (255, 200, 60), (90, 180, 240)][k % 3])
    c.fill(c.rect(328, 60, 332, 96), (200, 200, 210)); c.outline(wheel, k=0.5)
    # beach, the boardwalk wall with graffiti, lifeguard tower
    sand = c.rect(0, 142, W - 1, FLOOR0 - 1); c.fill(sand, (236, 212, 160), c.value_noise(5, 8, octaves=2), 0.2)
    wall = c.rect(0, 126, 150, FLOOR0 - 1); c.fill(wall, (220, 220, 230), c.bricks(16, 6, -0.35, 3), 0.3); c.shade(wall, (-1, -1), 1.15, 0.7, 2)
    for (x, w_, col) in ((8, 30, (240, 80, 140)), (44, 22, (80, 200, 230)), (72, 36, (255, 210, 60)), (114, 28, (120, 220, 90))):
        tag = c.ellipse(x + w_ / 2, 140, w_ / 2, 7); c.fill(tag, col); c.outline(tag, k=0.5)
    c.outline(wall, k=0.5)
    tower = c.rect(166, 100, 206, 128); c.fill(tower, (90, 150, 220), c.wood(6, 7, True, 0.2), 0.3); c.shade(tower, (-1, -1), 1.2, 0.65, 2)
    c.fill(c.rect(166, 96, 210, 101), (240, 240, 250)); window(c, 174, 106, 198, 120, (240, 240, 250), (140, 200, 230), bars=False)
    legs = c.rect(168, 128, 171, 150) | c.rect(201, 128, 204, 150); c.fill(legs, (60, 100, 160)); c.outline(tower | legs, k=0.5)
    # palm trees framing the stage
    for (x, h, lean) in ((40, 150, -1), (350, 140, 1), (230, 120, -1)):
        trunk = c.poly([(x - 5, FLOOR0), (x + 5, FLOOR0), (x + lean * 12 + 3, FLOOR0 - h), (x + lean * 12 - 3, FLOOR0 - h)])
        c.fill(trunk, (150, 110, 70), c.wood(x, 6, True, 0.3), 0.45); c.shade(trunk, (-1, 0), 1.2, 0.6, 2); c.outline(trunk, k=0.5)
        tx, ty = x + lean * 12, FLOOR0 - h
        for k in range(7):
            a_ = -math.pi + k * math.pi / 6
            frond = c.poly([(tx, ty), (tx + math.cos(a_) * 34, ty + math.sin(a_) * 18 + 10), (tx + math.cos(a_ + 0.3) * 26, ty + math.sin(a_ + 0.3) * 14 + 14)])
            c.fill(frond, (60, 150, 70), c.foliage(k), 0.3); c.shade(frond, (-1, -1), 1.2, 0.7, 1); c.outline(frond, k=0.55)
        c.fill(c.circle(tx, ty + 4, 4), (140, 100, 50))
    # the muscle-beach crowd on the sand
    crowd(c, [(60, FLOOR0 - 2, 44, dict(skin="brown", shirt=(255, 200, 60), pants=(60, 60, 120), hair=(20, 16, 18), pose="cheer")),
              (104, FLOOR0 - 2, 40, dict(skin="tan", shirt=(240, 60, 90), pants=(240, 240, 250), hat=("cap", (40, 60, 160)), pose="lean")),
              (284, FLOOR0 - 2, 42, dict(skin="dark", shirt=(60, 200, 230), pants=(50, 50, 60), hair=(20, 16, 18), pose="cheer", flip=True)),
              (318, FLOOR0 - 2, 38, dict(skin="ivory", shirt=(250, 250, 250), pants=(230, 120, 60), hair=(220, 180, 80), pose="stand", flip=True))])
    # a skate rail and a surfboard
    rail = c.rect(132, FLOOR0 - 12, 192, FLOOR0 - 9) | c.rect(134, FLOOR0 - 9, 137, FLOOR0) | c.rect(187, FLOOR0 - 9, 190, FLOOR0)
    c.fill(rail, (200, 200, 215)); c.outline(rail, k=0.5)
    board = c.ellipse(346, FLOOR0 - 2, 8, 26); c.fill(board, (255, 120, 60)); c.fill(c.rect(345, FLOOR0 - 24, 347, FLOOR0 + 18) & board, (255, 230, 120)); c.outline(board, k=0.5)
    barrel(c, 16, FLOOR0 + 14, 22, 30, (90, 140, 200), (200, 200, 210))
    floor_planks(c, (190, 150, 100), (0.55, 0.5, 0.45), along=False, seed=14)
    return c

# ------------------------------------------------------------------ 2 BACKYARD (Guile's crowd at the fence)
def backyard():
    c = Canvas(seed=22); SKY[2] = ((78, 140, 236), (196, 226, 250))
    clouds(c, [(50, 28, 36), (190, 18, 28), (330, 34, 40)])
    hills(c, 112, 124, 10, (110, 170, 90), 2, period=2.0)
    # the house: wall, roof, big window, door
    wall = c.rect(20, 46, 232, 140); c.fill(wall, (236, 222, 190), c.wood(3, 8, True, 0.12), 0.35, vgrad=(46, 140, 1.05, 0.9)); c.shade(wall, (-1, -1), 1.15, 0.7, 2)
    roof = c.poly([(8, 50), (244, 50), (214, 14), (38, 14)]); c.fill(roof, (120, 60, 50), c.bricks(14, 5, -0.4, 4), 0.45); c.shade(roof, (-1, -1), 1.25, 0.6, 2); c.shadow(roof, 0, 5, 0.65); c.outline(roof, k=0.45)
    window(c, 40, 66, 108, 112, (255, 255, 255), (120, 190, 230)); window(c, 148, 66, 216, 112, (255, 255, 255), (120, 190, 230))
    door = c.rect(118, 90, 142, 140); c.fill(door, (90, 60, 40), c.wood(5, 99, False, 0.3), 0.4); c.shade(door, (-1, -1), 1.2, 0.65, 2); c.outline(door, k=0.5)
    c.fill(c.circle(138, 116, 1.5), (240, 200, 80)); c.outline(wall, k=0.5)
    # big tree right, swing
    c.tree(318, 142, 150, (110, 76, 46), (70, 150, 70), seed=7, spread=1.25)
    for k in range(2):
        rope = c.rect(300 + k * 18, 80, 301 + k * 18, 128); c.fill(rope, (200, 180, 120))
    seat = c.rect(294, 128, 326, 132); c.fill(seat, (140, 100, 60)); c.outline(seat, k=0.5)
    # fence and spectators
    picket_fence(c, 126, 152, (250, 250, 250), (200, 200, 205), pitch=11, pw=7)
    crowd(c, [(60, 152, 44, dict(skin="dark", shirt=(240, 60, 60), pants=(50, 60, 120), hair=(20, 16, 18), pose="cheer")),
              (100, 152, 40, dict(skin="ivory", shirt=(90, 190, 90), pants=(80, 70, 60), hair=(220, 180, 80), pose="stand")),
              (150, 152, 46, dict(skin="brown", shirt=(70, 110, 220), pants=(60, 60, 70), hat=("cap", (230, 50, 50)), pose="lean")),
              (200, 152, 38, dict(skin="tan", shirt=(250, 200, 60), pants=(90, 130, 200), hair=(60, 40, 30), pose="cheer", flip=True)),
              (250, 152, 44, dict(skin="ivory", shirt=(230, 120, 180), pants=(70, 80, 120), hair=(120, 70, 40), pose="stand"))])
    # props: grill left, sandbox right
    grill = c.ellipse(26, 146, 16, 8) | c.rect(10, 146, 42, 154) | c.rect(14, 154, 16, 170) | c.rect(36, 154, 38, 170)
    c.fill(grill, (50, 50, 56)); c.shade(grill, (-1, -1), 1.3, 0.6, 2); c.outline(grill, k=0.5)
    box = c.rect(330, 160, 384, 176); c.fill(box, (170, 120, 70), c.wood(6, 99, True, 0.3), 0.4); c.shade(box, (-1, -1), 1.2, 0.6, 2); c.outline(box, k=0.5)
    floor_ground(c, (96, 168, 72), (0.82, 0.9, 0.7), kind="grass", seed=21)
    return c

# ------------------------------------------------------------------ 3 ROOFTOP (night city, water tower, neon)
def rooftop():
    c = Canvas(seed=33); SKY[3] = ((6, 8, 36), (84, 44, 112))
    rng = np.random.default_rng(5)
    for i in range(60):
        x, y = rng.integers(0, W), rng.integers(0, 70); c.fill(c.rect(x, y, x, y), (255, 255, 230))
    c.fill(c.circle(300, 36, 16), (255, 250, 220)); c.fill(c.circle(300, 36, 13), (255, 255, 240))
    skyline(c, 124, 9, (36, 32, 60), n=20, lo=30, hi=96)
    skyline(c, 150, 10, (22, 20, 40), n=20, lo=10, hi=40, lit=(255, 230, 150))
    # parapet wall across
    par = c.rect(0, 136, W - 1, FLOOR0 - 1); c.fill(par, (120, 70, 60), c.bricks(12, 5, -0.5, 7), 0.45, vgrad=(136, FLOOR0, 1.05, 0.9)); c.shade(par, (0, -1), 1.2, 0.7, 2)
    cap = c.rect(0, 134, W - 1, 138); c.fill(cap, (170, 150, 140)); c.outline(cap | par, k=0.55)
    # water tower on the left
    legs = c.line_mask(40, 136, 52, 56, 3) | c.line_mask(100, 136, 88, 56, 3) | c.line_mask(52, 100, 88, 100, 2)
    c.fill(legs, (80, 70, 70)); tank = c.poly([(42, 60), (98, 60), (94, 20), (46, 20)])
    c.fill(tank, (150, 110, 90), c.wood(8, 99, False, 0.3), 0.4); c.shade(tank, (-1, 0), 1.25, 0.55, 3)
    cone = c.poly([(36, 22), (104, 22), (70, 4)]); c.fill(cone, (100, 80, 80)); c.shade(cone, (-1, -1), 1.2, 0.6, 2); c.outline(tank | cone | legs, k=0.45)
    # neon sign right
    sign = c.rect(262, 40, 374, 90); c.fill(sign, (30, 24, 44)); c.shade(sign, (-1, -1), 1.3, 0.6, 2); c.outline(sign, (120, 110, 160))
    c.fill(c.rect(272, 50, 364, 60), (255, 70, 120)); c.fill(c.rect(272, 70, 364, 80), (80, 240, 255))
    for x in range(276, 364, 12): c.fill(c.rect(x, 52, x + 6, 58), (30, 24, 44)); c.fill(c.rect(x + 3, 72, x + 9, 78), (30, 24, 44))
    c.fill(c.rect(316, 90, 320, 134), (80, 70, 90)); c.fill(c.rect(300, 90, 304, 134), (80, 70, 90))
    # AC units, crates, spectators on the roof
    for x0 in (120, 160):
        ac = c.rect(x0, 112, x0 + 34, 136); c.fill(ac, (170, 170, 180), c.value_noise(3, 4), 0.1); c.shade(ac, (-1, -1), 1.3, 0.6, 2)
        c.fill(c.circle(x0 + 17, 124, 8), (90, 90, 100)); c.fill(c.circle(x0 + 17, 124, 2), (170, 170, 180)); c.outline(ac, k=0.45)
    crowd(c, [(214, 136, 44, dict(skin="brown", shirt=(240, 240, 240), pants=(40, 40, 50), hat=("beanie", (220, 60, 60)), pose="cheer")),
              (246, 136, 40, dict(skin="ivory", shirt=(90, 90, 200), pants=(60, 60, 70), hair=(40, 30, 30), pose="lean", flip=True)),
              (110, 136, 42, dict(skin="dark", shirt=(250, 200, 60), pants=(80, 60, 90), hair=(20, 16, 18), pose="stand"))])
    crate(c, 0, FLOOR0 - 30, 34, FLOOR0 + 2, (120, 100, 90)); barrel(c, 364, FLOOR0 + 12, 24, 34, (90, 90, 110), (160, 160, 170))
    floor_tiles(c, (104, 96, 110), (0.6, 0.6, 0.66), nx=8, ny=5, seed=9)
    return c

# ------------------------------------------------------------------ 4 FARM (barn, silo, windmill, hay)
def farm():
    c = Canvas(seed=44); SKY[4] = ((132, 186, 240), (240, 232, 208))
    sun(c, 60, 40, 18); clouds(c, [(150, 28, 30), (290, 20, 36)])
    hills(c, 120, 140, 16, (150, 190, 90), 3, period=1.2)
    # windmill far right, silo, barn left-centre
    silo = c.rect(236, 40, 268, 140); c.fill(silo, (200, 200, 205), c.value_noise(5, 3, aspect=0.2), 0.2, vgrad=(40, 140, 1.05, 0.85)); c.shade(silo, (-1, 0), 1.25, 0.6, 4)
    dome = c.ellipse(252, 40, 17, 10); c.fill(dome, (150, 60, 50)); c.shade(dome, (-1, -1), 1.2, 0.65, 2); c.outline(silo | dome, k=0.5)
    mast = c.rect(340, 60, 346, 140); c.fill(mast, (120, 100, 80)); c.outline(mast, k=0.5)
    for a in range(4):
        ang = a * math.pi / 2 + 0.4
        blade = c.line_mask(343, 62, 343 + math.cos(ang) * 34, 62 + math.sin(ang) * 34, 3); c.fill(blade, (220, 220, 230)); c.outline(blade, k=0.5)
    wall = c.rect(28, 68, 218, 150); c.fill(wall, (196, 54, 46), c.wood(6, 9, False, 0.22), 0.5, vgrad=(68, 150, 1.05, 0.86)); c.shade(wall, (-1, -1), 1.2, 0.65, 2)
    roof = c.poly([(16, 70), (230, 70), (200, 30), (46, 30)]); c.fill(roof, (110, 70, 60), c.wood(7, 5, True, 0.2), 0.4); c.shade(roof, (-1, -1), 1.25, 0.6, 2); c.shadow(roof, 0, 5, 0.6); c.outline(roof, k=0.45)
    loft = c.rect(108, 40, 138, 66); c.fill(loft, (60, 40, 36)); c.fill(c.rect(110, 48, 136, 66), (230, 190, 90), c.thatch(5), 0.3)
    door = c.rect(90, 96, 156, 150); c.fill(door, (230, 230, 230)); c.fill(c.line_mask(92, 98, 154, 148, 4) | c.line_mask(154, 98, 92, 148, 4), (190, 50, 44)); c.outline(door, k=0.5)
    c.outline(wall, k=0.5)
    # hay bales, fence, animals, spectators
    for (x, y) in ((264, 150), (296, 150), (280, 132)):
        bale = c.rect(x - 16, y - 18, x + 16, y); c.fill(bale, (226, 190, 90), c.thatch(x), 0.35); c.shade(bale, (-1, -1), 1.2, 0.65, 2); c.outline(bale, k=0.5)
    picket_fence(c, 130, 154, (170, 130, 80), (120, 90, 60), x0=300, x1=W, pitch=14, pw=4)
    crowd(c, [(176, 154, 42, dict(skin="ivory", shirt=(90, 130, 220), pants=(70, 80, 120), hat=("straw", (230, 200, 110)), pose="stand")),
              (210, 154, 40, dict(skin="brown", shirt=(250, 250, 250), pants=(60, 50, 50), hair=(40, 30, 30), pose="cheer")),
              (44, 154, 44, dict(skin="dark", shirt=(60, 160, 90), pants=(60, 60, 120), hat=("cap", (240, 200, 60)), pose="lean", flip=True))])
    pig = c.ellipse(340, 148, 18, 11) | c.circle(360, 142, 8); c.fill(pig, (250, 180, 190)); c.shade(pig, (-1, -1), 1.15, 0.7, 2); c.outline(pig, k=0.5)
    c.fill(c.rect(364, 141, 368, 144), (240, 130, 150))
    crate(c, 0, FLOOR0 - 24, 26, FLOOR0 + 2); barrel(c, 372, FLOOR0 + 14, 22, 30)
    floor_ground(c, (170, 128, 80), (0.8, 0.74, 0.62), seed=31)
    return c

# ------------------------------------------------------------------ 5 POND (willows, a pier, lily pads)
def pond():
    c = Canvas(seed=55); SKY[5] = ((84, 156, 238), (212, 238, 250))
    clouds(c, [(80, 24, 40), (250, 30, 34)])
    hills(c, 100, 120, 14, (90, 150, 80), 4, period=1.6)
    # willow trees left and right
    for (x, h, seed) in ((50, 150, 3), (334, 160, 4)):
        c.tree(x, 148, h, (100, 70, 44), (120, 180, 90), seed=seed, spread=1.3)
        for i in range(10):
            sx = x - h * 0.3 + i * (h * 0.06); strand = c.poly([(sx, 148 - h * 0.6), (sx + 3, 148 - h * 0.6), (sx + 2, 148 - h * 0.1), (sx, 148 - h * 0.1)])
            c.fill(strand, (100, 170, 80), c.grain(i), 0.3)
    # water
    water = c.rect(0, 118, W - 1, FLOOR0 - 1); wn = c.value_noise(9, 21, octaves=2, aspect=0.25)
    c.fill(water, (70, 140, 200), wn, 0.3, vgrad=(118, FLOOR0, 1.1, 0.85))
    yy, xx = np.mgrid[0:H, 0:W]
    c.fill(water & (((xx // 2 + yy * 3) % 11) == 0) & (wn > 0.1), (200, 240, 255))
    for (x, y, r) in ((110, 140, 12), (260, 146, 14), (190, 128, 9), (300, 132, 10)):
        pad = c.ellipse(x, y, r, r * 0.45) & ~c.poly([(x, y), (x + r, y - r * 0.5), (x + r, y)]); c.fill(pad, (80, 170, 70)); c.outline(pad, k=0.6)
    c.fill(c.ellipse(260, 142, 4, 3), (250, 140, 200)); c.fill(c.ellipse(110, 136, 3, 2), (250, 230, 120))
    # ducks and spectators on a raft
    raft = c.rect(150, 120, 240, 130); c.fill(raft, (150, 110, 60), c.wood(9, 8, True, 0.3), 0.4); c.shade(raft, (-1, -1), 1.2, 0.6, 1); c.outline(raft, k=0.5)
    crowd(c, [(172, 121, 36, dict(skin="tan", shirt=(240, 90, 60), pants=(60, 80, 140), hat=("straw", (230, 200, 110)), pose="sit")),
              (214, 121, 36, dict(skin="dark", shirt=(90, 200, 160), pants=(80, 70, 60), hair=(20, 16, 18), pose="cheer", flip=True))])
    for (x, y) in ((70, 134), (320, 142)):
        duck = c.ellipse(x, y, 8, 5) | c.circle(x + 7, y - 6, 4); c.fill(duck, (250, 240, 120)); c.fill(c.rect(x + 10, y - 6, x + 14, y - 4), (240, 140, 40)); c.outline(duck, k=0.55)
    reeds = c.mask()
    for x in range(8, 60, 7): reeds |= c.rect(x, 124 - (x % 3) * 6, x + 1, FLOOR0)
    for x in range(330, 384, 7): reeds |= c.rect(x, 126 - (x % 4) * 5, x + 1, FLOOR0)
    c.fill(reeds, (70, 130, 60)); c.fill(c.rect(0, 150, W - 1, FLOOR0 - 1) & reeds, (50, 100, 50))
    floor_planks(c, (150, 112, 70), (0.5, 0.46, 0.4), along=True, nx=14, seed=18)
    return c

# ------------------------------------------------------------------ 6 CAVE (crystals, lanterns, bones, a chasm)
def cave():
    c = Canvas(seed=66); SKY[6] = ((16, 10, 12), (62, 40, 34))
    rock = c.rect(0, 0, W - 1, FLOOR0 - 1)
    c.fill(rock, (90, 70, 62), c.stone(3, 16), 0.5, vgrad=(0, FLOOR0, 0.8, 1.05))
    stal = c.mask(); rng = np.random.default_rng(6)
    for i in range(20):
        x = i * 20 + rng.integers(0, 8); h = 20 + rng.integers(0, 40)
        stal |= c.poly([(x - 7, 0), (x + 7, 0), (x, h)])
    c.fill(stal, (76, 60, 54), c.stone(4, 8), 0.4); c.shade(stal, (-1, 0), 1.2, 0.6, 2); c.outline(stal, k=0.5)
    # glowing crystal clusters
    for (x, y, h, col) in ((60, 150, 40, (120, 220, 255)), (320, 150, 46, (200, 120, 255)), (190, 100, 26, (120, 255, 200))):
        c.sun_haze(x, y - h / 2, h * 1.6, col, 0.3)
        for k, (dx, hh) in enumerate(((0, h), (-12, h * 0.6), (12, h * 0.7))):
            cr = c.poly([(x + dx - 6, y), (x + dx + 6, y), (x + dx + 2, y - hh), (x + dx - 3, y - hh)])
            c.fill(cr, col, c.value_noise(3, k), 0.15, vgrad=(y - hh, y, 1.2, 0.8)); c.shade(cr, (-1, 0), 1.25, 0.6, 2); c.outline(cr, k=0.5)
    # a stone ledge with spectators and hanging lanterns
    ledge = c.rect(120, 96, 270, 108); c.fill(ledge, (110, 90, 80), c.stone(5, 10), 0.4); c.shade(ledge, (0, -1), 1.3, 0.6, 2); c.outline(ledge, k=0.5)
    crowd(c, [(150, 96, 36, dict(skin="brown", shirt=(240, 160, 50), pants=(70, 60, 60), hair=(30, 20, 20), pose="cheer")),
              (196, 96, 40, dict(skin="ivory", shirt=(120, 90, 200), pants=(60, 60, 70), hat=("beanie", (60, 180, 120)), pose="stand")),
              (240, 96, 36, dict(skin="dark", shirt=(90, 200, 220), pants=(80, 60, 60), hair=(20, 16, 18), pose="lean", flip=True))])
    for (x, y) in ((40, 60), (344, 60), (192, 44)):
        c.fill(c.rect(x - 1, 0, x + 1, y - 14), (70, 60, 50)); lantern(c, x, y, 9)
    for (x, y) in ((100, FLOOR0 - 4), (280, FLOOR0 - 6)):
        bone = c.line_mask(x - 14, y, x + 14, y - 4, 3) | c.circle(x - 15, y - 1, 3) | c.circle(x + 15, y - 5, 3); c.fill(bone, (230, 225, 200)); c.outline(bone, k=0.6)
    pot(c, 22, FLOOR0 + 8, 30, 32, (210, 150, 60)); pot(c, 362, FLOOR0 + 8, 30, 32, (90, 140, 200))
    floor_tiles(c, (96, 84, 80), (0.5, 0.48, 0.46), nx=9, ny=6, seed=12)
    return c

# ------------------------------------------------------------------ 7 GARDEN (greenhouse, topiary, gnomes)
def garden():
    c = Canvas(seed=77); SKY[7] = ((250, 168, 192), (255, 240, 214))
    sun(c, 330, 34, 16, (255, 250, 230), (255, 220, 170)); clouds(c, [(80, 26, 36), (220, 36, 30)], (255, 245, 240), (240, 190, 200))
    hedge = c.rect(0, 96, W - 1, 132); c.fill(hedge, (60, 130, 60), c.foliage(5), 0.5, vgrad=(96, 132, 1.1, 0.85)); c.shade(hedge, (0, -1), 1.25, 0.7, 2); c.outline(hedge, k=0.55)
    # greenhouse centre
    gh = c.poly([(120, 134), (264, 134), (264, 70), (192, 40), (120, 70)])
    c.fill(gh, (190, 230, 230), c.value_noise(6, 8), 0.12, vgrad=(40, 134, 1.1, 0.9)); c.shade(gh, (-1, -1), 1.15, 0.75, 2)
    frame = c.mask()
    for x in range(120, 268, 24): frame |= c.rect(x, 40, x + 2, 134)
    frame |= c.rect(120, 70, 264, 72) | c.rect(120, 102, 264, 104) | c.line_mask(120, 70, 192, 40, 3) | c.line_mask(264, 70, 192, 40, 3)
    c.fill(frame & gh, (250, 250, 250)); c.outline(gh, k=0.5)
    for (x, col) in ((140, (240, 80, 120)), (176, (255, 200, 60)), (212, (240, 120, 200)), (248, (255, 120, 80))):
        plant = c.ellipse(x, 120, 10, 9); c.fill(plant, (70, 150, 70), c.foliage(x), 0.4); c.fill(c.circle(x, 116, 4), col); c.outline(plant, k=0.6)
    # topiary left / right, flower beds, gnome spectators
    for (x, seed) in ((40, 3), (344, 4)):
        c.tree(x, 148, 110, (110, 76, 46), (60, 150, 60), seed=seed, spread=0.8)
    bed = c.rect(0, 134, W - 1, FLOOR0 - 1); c.fill(bed, (110, 70, 50), c.value_noise(4, 9), 0.3)
    rng = np.random.default_rng(7)
    for i in range(40):
        x = rng.integers(0, W); y = rng.integers(136, FLOOR0 - 3); col = [(240, 80, 120), (255, 220, 80), (240, 240, 250), (250, 140, 60)][i % 4]
        c.fill(c.rect(x, y - 4, x, y), (60, 130, 60)); c.fill(c.circle(x, y - 5, 2), col)
    crowd(c, [(92, 150, 34, dict(skin="ivory", shirt=(60, 90, 200), pants=(60, 60, 80), hat=("beanie", (230, 40, 40)), pose="stand")),
              (292, 150, 34, dict(skin="brown", shirt=(60, 160, 90), pants=(60, 60, 80), hat=("beanie", (230, 40, 40)), pose="cheer", flip=True)),
              (192, 150, 40, dict(skin="tan", shirt=(250, 230, 220), pants=(80, 120, 60), hat=("straw", (240, 210, 120)), pose="lean"))])
    pot(c, 20, FLOOR0 + 8, 30, 30, (200, 110, 70)); pot(c, 364, FLOOR0 + 8, 30, 30, (200, 110, 70))
    floor_tiles(c, (190, 180, 160), (0.62, 0.6, 0.56), nx=10, ny=6, seed=15, tex=c.stone(15, 6))
    return c

# ------------------------------------------------------------------ 8 BIG LEAF (Blanka's jungle, baby sized)
def bigleaf():
    c = Canvas(seed=88); SKY[8] = ((214, 244, 160), (124, 200, 96))
    sun(c, 192, 30, 22, (255, 255, 230), (240, 250, 180))
    # giant leaves and stems
    for (x, y, rx, ry, rot, col, seed) in ((70, 70, 90, 46, 0.3, (70, 160, 60), 1), (330, 60, 96, 50, -0.35, (90, 180, 70), 2), (200, 40, 70, 36, 0.1, (110, 190, 80), 3)):
        yy, xx = np.mgrid[0:H, 0:W]
        dx, dy = xx - x, yy - y; cs, sn = math.cos(rot), math.sin(rot)
        u, v = dx * cs + dy * sn, -dx * sn + dy * cs
        leaf = (u / rx) ** 2 + (v / ry) ** 2 <= 1
        c.fill(leaf, col, c.foliage(seed), 0.35, vgrad=(y - ry, y + ry, 1.1, 0.85)); c.shade(leaf, (-1, -1), 1.25, 0.65, 3)
        vein = np.abs(v) < 1.6; c.fill(leaf & vein, [k * 0.7 for k in col])
        for k in range(-3, 4):
            vv = np.abs(v - k * ry * 0.3 - u * 0.35 * np.sign(k + 0.1)) < 0.8
            c.fill(leaf & vv & (np.abs(u) < rx * 0.9), [kk * 0.78 for kk in col])
        c.outline(leaf, k=0.5)
    for (x0, x1) in ((60, 70), (320, 332), (196, 204)):
        stem = c.poly([(x0, FLOOR0), (x1 + 6, FLOOR0), (x1, 60), (x0 + 2, 60)]); c.fill(stem, (90, 140, 60), c.wood(4, 99, False, 0.3), 0.4); c.shade(stem, (-1, 0), 1.2, 0.6, 2); c.outline(stem, k=0.5)
    # mushrooms, ladybugs, a snail, bug spectators
    for (x, y, r, col) in ((130, 150, 22, (230, 70, 60)), (270, 150, 18, (240, 200, 90))):
        c.fill(c.rect(x - 6, y - r * 0.6, x + 6, y), (240, 230, 200)); cap = c.ellipse(x, y - r * 0.6, r, r * 0.55); c.fill(cap, col); c.shade(cap, (-1, -1), 1.25, 0.65, 2)
        for (dx, dy) in ((-8, -4), (4, -8), (10, 0)): c.fill(c.circle(x + dx, y - r * 0.6 + dy, 2.5), (250, 240, 240))
        c.outline(cap, k=0.5)
    crowd(c, [(170, 152, 38, dict(skin="tan", shirt=(240, 60, 60), pants=(40, 40, 50), hair=(30, 20, 20), pose="cheer")),
              (230, 152, 36, dict(skin="dark", shirt=(60, 200, 220), pants=(60, 60, 90), hair=(20, 16, 18), pose="stand", flip=True))])
    bug = c.ellipse(40, 146, 12, 8); c.fill(bug, (230, 50, 50)); c.fill(c.rect(39, 138, 41, 154) & bug, (30, 20, 20))
    for (dx, dy) in ((-6, -2), (5, -3), (-3, 3), (6, 3)): c.fill(c.circle(40 + dx, 146 + dy, 1.8), (30, 20, 20))
    c.fill(c.circle(52, 144, 4), (30, 20, 20)); c.outline(bug, k=0.5)
    snail = c.circle(340, 144, 11) | c.ellipse(352, 150, 12, 5); c.fill(snail, (200, 140, 90)); c.fill(c.circle(340, 144, 6), (160, 100, 70)); c.outline(snail, k=0.5)
    floor_ground(c, (120, 86, 56), (0.78, 0.74, 0.66), seed=44)
    yy, xx = np.mgrid[0:H, 0:W]
    moss = (yy >= FLOOR0) & (c.value_noise(6, 17) > 0.12); c.fill(moss, (90, 150, 60), c.grass(5), 0.3)
    return c

SCENES = {1: bayou, 2: backyard, 3: rooftop, 4: farm, 5: pond, 6: cave, 7: garden, 8: bigleaf}

def sky_preview(c, top, hor):
    yy = np.arange(H, dtype=np.float32)[:, None, None] / 168
    g = np.array(top, np.float32) * (1 - np.clip(yy, 0, 1)) + np.array(hor, np.float32) * np.clip(yy, 0, 1)
    g = np.broadcast_to(g, (H, W, 3)).copy()
    out = np.where(c.on[..., None], np.clip(c.rgb, 0, 255), g)
    from PIL import Image
    return Image.fromarray(out.astype(np.uint8))

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__)); out = os.path.join(here, "..", "render")
    ids = [int(a) for a in sys.argv[1:]] or sorted(SCENES)
    for i in ids:
        c = SCENES[i]()
        c.image().save(os.path.join(out, f"stage{i}.png"))
        sky_preview(c, *SKY[i]).resize((W * 2, H * 2), 0).save(os.path.join(out, f"stage{i}_preview.png"))
        print("rendered", i, "painted px", int(c.on.sum()))
