# paintlib.py: a small painterly toolkit for 256x224 SNES stage art.
# Canvas is float RGB 0..255 plus a "painted" mask; unpainted pixels become palette index 0
# (transparent) so the game's per-scanline backdrop gradient shows through as the sky.
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 256, 224

class Canvas:
    def __init__(self, seed=1):
        self.rgb = np.zeros((H, W, 3), np.float32)
        self.on = np.zeros((H, W), bool)
        self.rng = np.random.default_rng(seed)
        self.seed = seed

    # ---------------------------------------------------------------- masks
    def mask(self):
        return np.zeros((H, W), bool)

    def poly(self, pts):
        im = Image.new("L", (W, H), 0)
        ImageDraw.Draw(im).polygon([(float(x), float(y)) for x, y in pts], fill=255)
        return np.array(im) > 0

    def rect(self, x0, y0, x1, y1):
        m = self.mask(); m[max(0, int(y0)):min(H, int(y1) + 1), max(0, int(x0)):min(W, int(x1) + 1)] = True
        return m

    def ellipse(self, cx, cy, rx, ry):
        yy, xx = np.mgrid[0:H, 0:W]
        return ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1

    def circle(self, cx, cy, r):
        return self.ellipse(cx, cy, r, r)

    def line_mask(self, x0, y0, x1, y1, w=1):
        im = Image.new("L", (W, H), 0)
        ImageDraw.Draw(im).line([(x0, y0), (x1, y1)], fill=255, width=int(w))
        return np.array(im) > 0

    # ---------------------------------------------------------------- noise
    def value_noise(self, scale, seed=0, octaves=3, persistence=0.5, aspect=1.0):
        rng = np.random.default_rng(self.seed * 1000 + seed)
        out = np.zeros((H, W), np.float32)
        amp, total = 1.0, 0.0
        for o in range(octaves):
            sx = max(1.0, scale / (2 ** o))
            sy = max(1.0, sx * aspect)
            gw, gh = int(W / sx) + 3, int(H / sy) + 3
            g = rng.random((gh, gw)).astype(np.float32)
            yy, xx = np.mgrid[0:H, 0:W]
            fx, fy = xx / sx, yy / sy
            ix, iy = fx.astype(int), fy.astype(int)
            tx, ty = fx - ix, fy - iy
            tx = tx * tx * (3 - 2 * tx); ty = ty * ty * (3 - 2 * ty)
            a = g[iy, ix]; b = g[iy, ix + 1]; c = g[iy + 1, ix]; d = g[iy + 1, ix + 1]
            v = a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty
            out += (v - 0.5) * amp
            total += amp
            amp *= persistence
        return out / total  # roughly -0.5..0.5

    def grain(self, seed=0):
        rng = np.random.default_rng(self.seed * 7777 + seed)
        return rng.random((H, W)).astype(np.float32) - 0.5

    # ---------------------------------------------------------------- painting
    def fill(self, m, color, tex=None, amount=0.0, vgrad=None):
        """Paint colour into mask. tex: HxW noise in -0.5..0.5 scaled by amount (fraction of colour).
        vgrad=(y0,y1,k0,k1): multiply brightness from k0 at y0 to k1 at y1."""
        col = np.array(color, np.float32)
        img = np.broadcast_to(col, (H, W, 3)).copy()
        if tex is not None and amount:
            img *= (1 + tex * amount)[..., None]
        if vgrad is not None:
            y0, y1, k0, k1 = vgrad
            yy = np.arange(H, dtype=np.float32)[:, None]
            k = np.clip((yy - y0) / max(1, y1 - y0), 0, 1) * (k1 - k0) + k0
            img *= np.broadcast_to(k, (H, W))[..., None]
        self.rgb[m] = img[m]
        self.on[m] = True

    def tint(self, m, k, color=None):
        """Multiply brightness in mask (k<1 darkens). Optional colour shift toward color by (1-k)."""
        if color is None:
            self.rgb[m] *= k
        else:
            c = np.array(color, np.float32)
            self.rgb[m] = self.rgb[m] * k + c * (1 - k)

    def shade(self, m, light=(-1, -1), lit=1.25, dark=0.72, width=1):
        """Bevel: brighten the edge facing the light, darken the opposite edge."""
        for w in range(1, width + 1):
            inner = m.copy()
            dx, dy = light[0] * w, light[1] * w
            shifted = np.roll(np.roll(m, -dy, 0), -dx, 1)
            lit_edge = m & ~shifted
            shifted2 = np.roll(np.roll(m, dy, 0), dx, 1)
            dark_edge = m & ~shifted2
            f = 1 - (w - 1) / (width + 0.0001) * 0.6
            self.rgb[lit_edge] *= 1 + (lit - 1) * f
            self.rgb[dark_edge] *= 1 - (1 - dark) * f

    def outline(self, m, color=None, k=0.55):
        edge = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
        if color is None:
            self.rgb[edge] *= k
        else:
            self.rgb[edge] = np.array(color, np.float32)

    def shadow(self, m, dx, dy, k=0.62, soft=0):
        """Cast shadow of mask onto whatever is already painted (not onto the mask itself)."""
        s = np.roll(np.roll(m, dy, 0), dx, 1)
        if dy > 0: s[:dy, :] = False
        if dx > 0: s[:, :dx] = False
        if dx < 0: s[:, dx:] = False
        s &= ~m
        if soft:
            im = Image.fromarray((s * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(soft))
            a = np.array(im).astype(np.float32) / 255
            self.rgb[self.on] *= (1 - (1 - k) * a[self.on])[:, None]
        else:
            s &= self.on
            self.rgb[s] *= k

    def ao(self, m, k=0.8, r=2):
        """Darken painted pixels just outside the mask below it (contact shadow)."""
        s = np.roll(m, r, 0) & ~m & self.on
        self.rgb[s] *= k

    def vignette_floor(self, y0, k_top=1.0, k_bot=0.78):
        yy = np.arange(H, dtype=np.float32)[:, None]
        k = np.clip((yy - y0) / max(1, H - 1 - y0), 0, 1) * (k_bot - k_top) + k_top
        kk = np.broadcast_to(k, (H, W))
        sel = self.on & (np.mgrid[0:H, 0:W][0] >= y0)
        self.rgb[sel] *= kk[sel][:, None]

    def sun_haze(self, cx, cy, r, color, strength=0.5):
        yy, xx = np.mgrid[0:H, 0:W]
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
        a = np.clip(1 - d, 0, 1) ** 2 * strength
        c = np.array(color, np.float32)
        sel = self.on
        self.rgb[sel] = self.rgb[sel] * (1 - a[sel])[:, None] + c * a[sel][:, None]

    # ---------------------------------------------------------------- textures
    def wood(self, seed=0, plank=12, horizontal=True, grainamt=0.18):
        """Plank texture: value -0.5..0.5 with grain and plank seams."""
        g = self.value_noise(6, seed, octaves=2, aspect=(0.18 if horizontal else 5.5)) * 1.3
        yy, xx = np.mgrid[0:H, 0:W]
        c = yy if horizontal else xx
        seam = ((c % plank) == 0) | ((c % plank) == plank - 1)
        t = g * grainamt / 0.18 * 0.5
        t[seam] -= 0.32
        t[(c % plank) == 1] += 0.10
        return t

    def thatch(self, seed=0, amt=1.0):
        a = self.value_noise(5, seed, octaves=2, aspect=0.12)
        b = self.grain(seed + 1) * 0.35
        yy, xx = np.mgrid[0:H, 0:W]
        strokes = (((xx * 2 + yy * 7 + (xx // 9) * 3) % 13) < 2).astype(np.float32) * -0.25
        return (a * 1.4 + b + strokes) * amt

    def stone(self, seed=0, size=14):
        n = self.value_noise(size, seed, octaves=3)
        cracks = (np.abs(self.value_noise(size * 1.3, seed + 5, octaves=2)) < 0.025).astype(np.float32) * -0.45
        return n * 0.9 + cracks

    def grass(self, seed=0):
        a = self.value_noise(3, seed, octaves=2, aspect=4.0)
        b = self.grain(seed + 3) * 0.4
        return a * 1.2 + b

    def foliage(self, seed=0):
        a = self.value_noise(7, seed, octaves=3)
        b = self.grain(seed + 9) * 0.3
        return a * 1.5 + b

    def bricks(self, bw=16, bh=8, mortar=-0.45, seed=0):
        yy, xx = np.mgrid[0:H, 0:W]
        row = yy // bh
        xo = (row % 2) * (bw // 2)
        m = (((xx + xo) % bw) == 0) | ((yy % bh) == 0)
        t = self.value_noise(5, seed, octaves=2) * 0.5
        t[m] = mortar
        t[((yy % bh) == 1) & ~m] += 0.12
        return t

    # ---------------------------------------------------------------- objects
    def tree(self, x, yb, h, trunk, leaf, seed=0, spread=1.0):
        tw = max(3, h // 9)
        trunkm = self.poly([(x - tw, yb), (x + tw, yb), (x + tw * 0.6, yb - h * 0.55), (x - tw * 0.6, yb - h * 0.55)])
        self.fill(trunkm, trunk, self.wood(seed, plank=99, horizontal=False), 0.5)
        self.shade(trunkm, (-1, 0), 1.2, 0.6, 2)
        rng = np.random.default_rng(seed)
        canopy = self.mask()
        for i in range(9):
            ang = i / 9 * 6.283
            r = h * 0.22 * spread
            cx = x + np.cos(ang) * r * (0.6 + rng.random() * 0.5)
            cy = yb - h * 0.62 + np.sin(ang) * r * 0.55 * (0.6 + rng.random() * 0.5)
            canopy |= self.ellipse(cx, cy, h * 0.17 * spread, h * 0.15)
        canopy |= self.ellipse(x, yb - h * 0.66, h * 0.26 * spread, h * 0.22)
        self.fill(canopy, leaf, self.foliage(seed + 1), 0.55)
        self.shade(canopy, (-1, -1), 1.3, 0.62, 2)
        self.outline(canopy, k=0.55)
        return canopy | trunkm

    def figure(self, x, yb, h, skin, cloth, hair=None, face=1, seed=0):
        """A small spectator: head, body, legs. x = centre, yb = feet line, h = height."""
        hw = h * 0.22
        head = self.ellipse(x, yb - h * 0.78, h * 0.2, h * 0.2)
        body = self.poly([(x - hw, yb - h * 0.6), (x + hw, yb - h * 0.6), (x + hw * 0.9, yb - h * 0.2), (x - hw * 0.9, yb - h * 0.2)])
        legs = self.rect(x - hw * 0.8, yb - h * 0.22, x + hw * 0.8, yb)
        self.fill(legs, [c * 0.55 for c in cloth])
        self.fill(body, cloth)
        self.shade(body, (-1, -1), 1.2, 0.7, 1)
        self.fill(head, skin)
        self.shade(head, (-1, -1), 1.15, 0.72, 1)
        if hair is not None:
            hm = self.ellipse(x, yb - h * 0.84, h * 0.2, h * 0.12)
            self.fill(hm, hair)
        self.outline(head | body | legs, k=0.5)
        # eyes
        ey = int(yb - h * 0.78)
        for ex in (int(x - h * 0.07), int(x + h * 0.05)):
            if 0 <= ex < W and 0 <= ey < H:
                self.rgb[ey, ex] = (20, 16, 24)
        return head | body | legs

    # ---------------------------------------------------------------- output
    def image(self):
        rgb = np.clip(self.rgb, 0, 255).astype(np.uint8)
        a = (self.on * 255).astype(np.uint8)
        return Image.fromarray(np.dstack([rgb, a]), "RGBA")

def _periodic(self, pw, ph, seed=0, cell=4, octaves=2):
    """Seamlessly periodic noise with period (pw, ph) pixels, tiled across the canvas. -0.5..0.5"""
    rng = np.random.default_rng(self.seed * 313 + seed)
    out = np.zeros((ph, pw), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        c = max(1, cell // (2 ** o))
        gw, gh = max(1, pw // c), max(1, ph // c)
        g = rng.random((gh, gw)).astype(np.float32)
        yy, xx = np.mgrid[0:ph, 0:pw]
        fx, fy = xx / c, yy / c
        ix, iy = fx.astype(int) % gw, fy.astype(int) % gh
        tx, ty = fx - fx.astype(int), fy - fy.astype(int)
        tx = tx * tx * (3 - 2 * tx); ty = ty * ty * (3 - 2 * ty)
        a = g[iy, ix]; b = g[iy, (ix + 1) % gw]; cc = g[(iy + 1) % gh, ix]; d = g[(iy + 1) % gh, (ix + 1) % gw]
        v = a + (b - a) * tx + (cc - a) * ty + (a - b - cc + d) * tx * ty
        out += (v - 0.5) * amp; total += amp; amp *= 0.5
    out /= total
    reps = (H // ph + 2, W // pw + 2)
    return np.tile(out, reps)[:H, :W]
Canvas.periodic = _periodic

def _pwood(self, seed=0, plank=16, pw=32, horizontal=True, grainamt=0.5):
    """Periodic plank texture (period pw x plank for horizontal planks)."""
    if horizontal:
        g = self.periodic(pw, plank, seed, cell=3) * grainamt
        yy, xx = np.mgrid[0:H, 0:W]
        c = yy
    else:
        g = self.periodic(plank, pw, seed, cell=3) * grainamt
        yy, xx = np.mgrid[0:H, 0:W]
        c = xx
    seam = ((c % plank) == 0) | ((c % plank) == plank - 1)
    g[seam] -= 0.32
    g[(c % plank) == 1] += 0.10
    return g
Canvas.pwood = _pwood
