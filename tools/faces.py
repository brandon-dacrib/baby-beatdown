# faces.py: paints the eight baby portraits for the player-select screen.
# Each face is drawn supersampled (4x) on a transparent square, downsampled to a 96x96 big portrait and a
# 32x32 grid icon, quantized to one 15-colour palette per character, and emitted as toy/faceN.lua
# (BG 4bpp tiles for the big portrait, OBJ 4bpp tiles for the icon). python faces.py renders
# render/faces_preview.png as well.
import sys, os, base64, numpy as np
from PIL import Image, ImageDraw, ImageFilter

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
from quantize import kmeans_colors, encode_tile, to555

SIZE, SS = 96, 4
N = SIZE * SS

class Face:
    def __init__(self):
        self.rgb = np.zeros((N, N, 3), np.float32)
        self.on = np.zeros((N, N), bool)
        yy, xx = np.mgrid[0:N, 0:N]
        self.xx = (xx + 0.5) / SS
        self.yy = (yy + 0.5) / SS

    def ell(self, cx, cy, rx, ry, rot=0.0):
        dx, dy = self.xx - cx, self.yy - cy
        if rot:
            c, s = np.cos(rot), np.sin(rot)
            dx, dy = dx * c + dy * s, -dx * s + dy * c
        return (dx / rx) ** 2 + (dy / ry) ** 2 <= 1

    def poly(self, pts):
        im = Image.new("L", (N, N), 0)
        ImageDraw.Draw(im).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
        return np.array(im) > 0

    def stroke(self, pts, w, color, round_=True):
        im = Image.new("L", (N, N), 0)
        d = ImageDraw.Draw(im)
        d.line([(x * SS, y * SS) for x, y in pts], fill=255, width=int(w * SS), joint="curve")
        if round_:
            for x, y in (pts[0], pts[-1]):
                r = w * SS / 2
                d.ellipse([x * SS - r, y * SS - r, x * SS + r, y * SS + r], fill=255)
        m = np.array(im) > 0
        self.put(m, color)
        return m

    def put(self, m, color):
        self.rgb[m] = np.array(color, np.float32)
        self.on[m] = True

    def blob(self, cx, cy, rx, ry, color, shade=0.32, outline=0.5, ow=1.1, rot=0.0, light=(-0.55, -0.7), spec=0.0):
        """Shaded ellipse: brighter toward the light, darker away, dark rim; optional specular highlight."""
        m = self.ell(cx, cy, rx, ry, rot)
        dx, dy = (self.xx - cx) / rx, (self.yy - cy) / ry
        if rot:
            c, s = np.cos(rot), np.sin(rot)
            dx, dy = dx * c + dy * s, -dx * s + dy * c
        r2 = np.clip(dx * dx + dy * dy, 0, 1)
        nz = np.sqrt(1 - r2)
        ndl = -(dx * light[0] + dy * light[1]) * 0.9 + nz * 0.35
        k = 1 + shade * (ndl - 0.3) * 1.6
        col = np.array(color, np.float32)
        img = np.clip(col[None, None, :] * k[..., None], 0, 255)
        if spec:
            sp = np.exp(-(((dx - light[0] * 0.55) ** 2 + (dy - light[1] * 0.55) ** 2)) * 14) * spec
            img = img + (255 - img) * sp[..., None]
        # rim
        inner = self.ell(cx, cy, max(0.5, rx - ow), max(0.5, ry - ow), rot)
        rim = m & ~inner
        img[rim] *= outline
        self.rgb[m] = img[m]
        self.on |= m
        return m

    def eye(self, cx, cy, rx, ry, iris, look=(0.0, 0.0), lid=None, lashes=False):
        white = self.blob(cx, cy, rx, ry, (250, 250, 255), shade=0.12, outline=0.35, ow=1.0)
        ix, iy = cx + look[0] * rx * 0.3, cy + look[1] * ry * 0.25
        ir = min(rx, ry) * 0.62
        self.blob(ix, iy, ir, ir * 1.05, iris, shade=0.45, outline=0.5, ow=0.8)
        self.blob(ix, iy + ir * 0.08, ir * 0.55, ir * 0.58, (18, 14, 20), shade=0.0, outline=1.0, ow=0)
        self.put(self.ell(ix - ir * 0.35, iy - ir * 0.4, ir * 0.3, ir * 0.3), (255, 255, 255))
        self.put(self.ell(ix + ir * 0.3, iy + ir * 0.35, ir * 0.14, ir * 0.14), (255, 255, 255))
        if lid is not None:
            # upper lid: skin coloured cover over the top of the eye
            cover = self.ell(cx, cy - ry * 0.9, rx * 1.1, ry * 0.9) & white
            self.put(cover, lid)
        if lashes:
            self.stroke([(cx - rx * 0.9, cy - ry * 0.55), (cx - rx * 0.7, cy - ry * 1.2)], 1.3, (30, 20, 30))
            self.stroke([(cx + rx * 0.9, cy - ry * 0.55), (cx + rx * 0.7, cy - ry * 1.2)], 1.3, (30, 20, 30))
        return white

    def blush(self, cx, cy, r, color=(240, 140, 160)):
        m = self.ell(cx, cy, r, r * 0.7)
        d = np.clip(1 - (((self.xx - cx) / r) ** 2 + ((self.yy - cy) / (r * 0.7)) ** 2), 0, 1)
        a = (d ** 0.8 * 0.55)[..., None]
        col = np.array(color, np.float32)
        sel = m & self.on
        self.rgb[sel] = self.rgb[sel] * (1 - a[sel]) + col * a[sel]

    def smile(self, cx, cy, w, depth, color=(60, 20, 30), lw=2.2, teeth=None, tongue=None):
        pts = [(cx + w * (t / 10 - 0.5), cy + depth * (1 - (t / 5 - 1) ** 2)) for t in range(11)]
        if teeth is not None or tongue is not None:
            mouth = self.poly(pts + [(cx + w / 2, cy), (cx - w / 2, cy)])
            self.put(mouth, (90, 20, 40))
            if teeth is not None:
                self.put(mouth & (self.yy < cy + teeth), (250, 250, 250))
            if tongue is not None:
                self.put(mouth & self.ell(cx, cy + depth, w * 0.3, depth * 0.55), (230, 110, 130))
            self.stroke(pts, lw * 0.6, color)
            self.stroke([pts[0], pts[-1]], lw * 0.6, color)
        else:
            self.stroke(pts, lw, color)

    def image(self, size, crop=0):
        rgb = np.clip(self.rgb, 0, 255)
        a = self.on.astype(np.float32)
        pre = rgb * a[..., None]
        big = Image.fromarray(np.dstack([pre, a * 255]).astype(np.uint8), "RGBA")
        if crop:
            big = big.crop((crop * SS, crop * SS, N - crop * SS, N - crop * SS))
        sm = np.array(big.resize((size, size), Image.LANCZOS)).astype(np.float32)
        al = sm[..., 3] / 255
        out = np.zeros((size, size, 4), np.uint8)
        ok = al > 0.45
        out[..., :3][ok] = np.clip(sm[..., :3][ok] / al[ok][:, None], 0, 255)
        out[..., 3] = ok * 255
        return Image.fromarray(out, "RGBA")

# ---------------------------------------------------------------- the eight faces
def brandon(f):
    skin = (204, 148, 100)
    f.blob(48, 70, 22, 10, (248, 248, 255), shade=0.2)              # onesie collar
    f.blob(48, 52, 31, 33, skin, shade=0.3, spec=0.25)              # head
    f.blob(18, 52, 6, 7, skin, shade=0.3); f.blob(78, 52, 6, 7, skin, shade=0.3)   # ears
    # auburn curls
    rng = np.random.default_rng(4)
    curl = (120, 56, 30); hi = (166, 92, 44)
    for i in range(26):
        a = np.pi * (0.05 + 0.9 * i / 25)
        r = 29 + rng.random() * 4
        cx, cy = 48 + np.cos(a) * r, 46 - np.sin(a) * r * 0.9 + 6
        f.blob(cx, cy, 6 + rng.random() * 3, 6 + rng.random() * 2, curl if i % 3 else hi, shade=0.4, spec=0.15)
    for i in range(7):
        f.blob(30 + i * 6, 26 + (i % 2) * 2, 5.5, 5, hi if i % 2 else curl, shade=0.4, spec=0.15)
    f.blob(48, 54, 26, 24, skin, shade=0.28, outline=1.0, ow=0, spec=0.2)      # face re-fill over curls
    f.eye(37, 52, 7, 7.5, (92, 50, 24), look=(0.1, 0.1)); f.eye(59, 52, 7, 7.5, (92, 50, 24), look=(0.1, 0.1))
    f.stroke([(29, 42), (39, 40)], 2.2, (96, 46, 26)); f.stroke([(57, 40), (67, 42)], 2.2, (96, 46, 26))   # brows
    f.blob(48, 62, 3.5, 2.6, (186, 128, 84), shade=0.3, outline=0.7)                                  # nose
    f.smile(48, 67, 22, 8, (110, 40, 40), teeth=3.0)
    f.blush(31, 63, 6); f.blush(65, 63, 6)

def arlo(f):
    # a black-and-tan terrier: pricked ears, wiry brows, a scruffy tan beard
    blk = (58, 54, 66); tan = (214, 152, 82); dk = (40, 36, 46)
    f.put(f.poly([(20, 46), (14, 8), (42, 30)]), blk); f.put(f.poly([(76, 46), (82, 8), (54, 30)]), blk)   # pricked ears
    f.put(f.poly([(24, 42), (18, 16), (36, 32)]), tan); f.put(f.poly([(72, 42), (78, 16), (60, 32)]), tan)
    f.blob(48, 58, 30, 29, blk, shade=0.35, spec=0.3)                      # head
    for x in (34, 41, 48, 55, 62):                                           # wiry tufts along the crown
        f.put(f.poly([(x - 4, 32), (x + 1, 24), (x + 5, 33)]), blk)
    f.blob(34, 45, 7, 3.8, tan, shade=0.3, rot=0.2); f.blob(62, 45, 7, 3.8, tan, shade=0.3, rot=-0.2)   # bushy tan brows
    f.blob(48, 71, 17, 12, tan, shade=0.3, spec=0.2)                        # tan muzzle
    for x in (33, 39, 45, 51, 57, 63):                                       # scruffy beard
        f.put(f.poly([(x - 4, 78), (x, 90), (x + 4, 78)]), tan)
    f.eye(36, 55, 7, 7.5, (120, 70, 30)); f.eye(60, 55, 7, 7.5, (120, 70, 30))
    f.blob(48, 64, 6.5, 4.5, (24, 18, 26), shade=0.2, spec=0.5)             # nose
    f.stroke([(48, 68), (48, 74)], 1.6, (60, 30, 30))
    f.smile(48, 74, 18, 6, (60, 30, 30))
    f.blob(48, 82, 5, 5, (236, 110, 140), shade=0.3)                       # tongue
    f.blush(28, 66, 6); f.blush(68, 66, 6)

def dawn(f):
    grey = (170, 170, 200); pink = (240, 150, 180)
    f.poly([(18, 44), (14, 12), (40, 32)]); f.put(f.poly([(18, 44), (14, 12), (40, 32)]), grey)   # ears
    f.put(f.poly([(78, 44), (82, 12), (56, 32)]), grey)
    f.put(f.poly([(22, 40), (18, 18), (36, 33)]), pink); f.put(f.poly([(74, 40), (78, 18), (60, 33)]), pink)
    f.blob(48, 58, 31, 28, grey, shade=0.32, spec=0.25)
    f.blob(48, 68, 15, 10, (232, 232, 246), shade=0.2, outline=0.8)        # white muzzle
    f.eye(35, 54, 8, 9, (92, 170, 110), look=(0.1, 0.0), lashes=True); f.eye(61, 54, 8, 9, (92, 170, 110), look=(0.1, 0.0), lashes=True)
    f.blob(48, 64, 3.6, 2.6, pink, shade=0.3)                                # nose
    f.stroke([(48, 66), (48, 70)], 1.4, (70, 50, 70))
    f.smile(44, 70, 9, 3, (70, 50, 70), lw=1.6); f.smile(52, 70, 9, 3, (70, 50, 70), lw=1.6)
    for s in (-1, 1):
        for k in range(3):
            f.stroke([(48 + s * 18, 64 + k * 4), (48 + s * 34, 60 + k * 6)], 1.1, (80, 80, 110))
    f.blush(28, 66, 6); f.blush(68, 66, 6)
    # pink bow by the right ear
    f.blob(70, 24, 8, 6, (250, 110, 150), shade=0.35, rot=0.4); f.blob(84, 22, 7, 5.5, (250, 110, 150), shade=0.35, rot=-0.4)
    f.blob(77, 24, 3.5, 3.5, (255, 190, 210), shade=0.3)

def chris(f):
    pink = (246, 166, 188); dark = (210, 110, 150)
    f.blob(20, 42, 12, 15, pink, shade=0.35, rot=0.6); f.blob(76, 42, 12, 15, pink, shade=0.35, rot=-0.6)   # ears
    f.blob(20, 42, 7, 9, (236, 130, 160), shade=0.3, rot=0.6); f.blob(76, 42, 7, 9, (236, 130, 160), shade=0.3, rot=-0.6)
    f.blob(48, 58, 32, 30, pink, shade=0.3, spec=0.25)
    f.eye(34, 50, 6.5, 7, (70, 50, 60)); f.eye(62, 50, 6.5, 7, (70, 50, 60))
    f.blob(48, 68, 16, 11, (252, 190, 206), shade=0.3, spec=0.2)            # snout
    f.blob(42, 68, 3.2, 4, dark, shade=0.2, outline=0.8); f.blob(54, 68, 3.2, 4, dark, shade=0.2, outline=0.8)   # nostrils
    f.smile(48, 80, 18, 4, (150, 60, 90), lw=1.8)
    f.blush(27, 64, 6, (240, 110, 150)); f.blush(69, 64, 6, (240, 110, 150))

def isaac(f):
    yel = (250, 216, 70); orange = (240, 132, 40)
    f.blob(48, 56, 31, 29, yel, shade=0.3, spec=0.3)                        # head
    for i, (x, y, r) in enumerate([(40, 24, 6), (48, 20, 7), (57, 24, 6)]):   # tuft
        f.blob(x, y, r, r * 1.3, yel, shade=0.35, rot=(i - 1) * 0.3)
    f.blob(48, 56, 30, 27, yel, shade=0.3, outline=1.0, ow=0, spec=0.3)
    f.eye(36, 50, 8, 9, (40, 30, 40), look=(0.1, 0.1)); f.eye(60, 50, 8, 9, (40, 30, 40), look=(0.1, 0.1))
    f.blob(48, 71, 22, 9, orange, shade=0.35, spec=0.2)                      # upper bill
    f.blob(48, 78, 17, 5.5, (222, 110, 36), shade=0.3)                        # lower bill
    f.stroke([(28, 72), (68, 72)], 1.4, (150, 60, 20))
    f.blob(40, 68, 1.8, 1.6, (150, 60, 20), shade=0); f.blob(56, 68, 1.8, 1.6, (150, 60, 20), shade=0)
    f.blush(26, 62, 6); f.blush(70, 62, 6)

def teddy(f):
    brn = (168, 112, 64); lite = (214, 164, 110)
    f.blob(20, 30, 11, 11, brn, shade=0.35); f.blob(76, 30, 11, 11, brn, shade=0.35)          # ears
    f.blob(20, 31, 6, 6, lite, shade=0.3); f.blob(76, 31, 6, 6, lite, shade=0.3)
    f.blob(48, 58, 32, 30, brn, shade=0.32, spec=0.25)
    f.blob(48, 70, 16, 12, lite, shade=0.3, spec=0.2)                          # muzzle
    f.eye(35, 52, 6.5, 7, (70, 44, 30)); f.eye(61, 52, 6.5, 7, (70, 44, 30))
    f.blob(48, 66, 6, 4.5, (40, 26, 22), shade=0.2, spec=0.5)                   # nose
    f.stroke([(48, 70), (48, 75)], 1.5, (70, 40, 30))
    f.smile(43, 75, 10, 3, (70, 40, 30), lw=1.6); f.smile(53, 75, 10, 3, (70, 40, 30), lw=1.6)
    f.blush(28, 66, 6); f.blush(68, 66, 6)

def pip(f):
    wht = (240, 240, 248); pink = (250, 170, 200)
    f.blob(33, 22, 9, 24, wht, shade=0.3, rot=0.18); f.blob(63, 22, 9, 24, wht, shade=0.3, rot=-0.18)   # ears
    f.blob(33, 24, 4.5, 17, pink, shade=0.25, rot=0.18); f.blob(63, 24, 4.5, 17, pink, shade=0.25, rot=-0.18)
    f.blob(48, 62, 30, 27, wht, shade=0.3, spec=0.2)
    f.eye(36, 58, 7, 8, (200, 70, 110)); f.eye(60, 58, 7, 8, (200, 70, 110))
    f.blob(48, 69, 3.6, 2.6, (240, 120, 160), shade=0.3)                        # nose
    f.stroke([(48, 71), (48, 75)], 1.4, (120, 80, 100))
    f.smile(43, 75, 10, 3, (120, 80, 100), lw=1.6); f.smile(53, 75, 10, 3, (120, 80, 100), lw=1.6)
    f.put(f.poly([(43, 76), (53, 76), (53, 83), (48.5, 84), (48, 83), (43, 83)]), (252, 252, 252))      # buck teeth
    f.stroke([(43, 76), (43, 83), (53, 83), (53, 76)], 0.9, (120, 80, 100)); f.stroke([(48, 76), (48, 83)], 0.9, (120, 80, 100))
    f.blush(28, 70, 6); f.blush(68, 70, 6)

def blue(f):
    blu = (64, 112, 232); lite = (130, 180, 255); dk = (26, 44, 120)
    for s in (-1, 1):                                                           # antennae
        f.stroke([(48 + s * 10, 34), (48 + s * 22, 12)], 2.2, dk)
        f.blob(48 + s * 24, 10, 5, 5, (255, 224, 102), shade=0.35, spec=0.3)
    f.blob(48, 58, 31, 29, blu, shade=0.35, spec=0.35)
    f.blob(48, 44, 24, 11, lite, shade=0.2, outline=1.0, ow=0)                   # forehead highlight band
    f.blob(48, 58, 31, 29, blu, shade=0.35, outline=0.5, ow=1.1, spec=0.0) if False else None
    f.eye(34, 54, 10, 11, (30, 24, 40), look=(0.0, 0.0)); f.eye(62, 54, 10, 11, (30, 24, 40), look=(0.0, 0.0))
    f.smile(48, 72, 20, 6, dk, lw=2.0)
    f.blob(39, 77, 3, 4, (240, 240, 250), shade=0.2, outline=0.8); f.blob(57, 77, 3, 4, (240, 240, 250), shade=0.2, outline=0.8)  # mandible teeth
    f.blush(27, 66, 6, (200, 120, 200)); f.blush(69, 66, 6, (200, 120, 200))

FACES = [brandon, arlo, dawn, chris, isaac, teddy, pip, blue]
NAMES = ["BRANDON", "ARLO", "DAWN", "CHRIS", "ISAAC", "TEDDY", "PIP", "BLUE"]

def quantize_face(big, small):
    a = np.array(big); s = np.array(small)
    on = a[..., 3] > 0; son = s[..., 3] > 0
    pix = to555(a[..., :3].astype(np.int32))[on]
    pal = kmeans_colors(pix, 15, iters=16, seed=3)
    def index(img, mask):
        rgb = to555(img[..., :3].astype(np.int32))
        idx = np.zeros(mask.shape, np.int32)
        d = ((rgb[mask][:, None, :] - pal[None, :, :]) ** 2).sum(2)
        idx[mask] = d.argmin(1) + 1
        return idx
    return pal, index(a, on), index(s, son)

def rle(b):
    """Zero-run RLE: 0x00 <n> stands for n zero bytes (1..255). Keeps base64 free of long 'AAAA' runs,
    which get miscounted when the data is relayed by hand."""
    out = bytearray(); i = 0
    while i < len(b):
        if b[i] == 0:
            n = 1
            while i + n < len(b) and b[i + n] == 0 and n < 255: n += 1
            out += bytes((0, n)); i += n
        else:
            out.append(b[i]); i += 1
    return bytes(out)

def emit(n, pal, bidx, sidx, outdir):
    big = b"".join(encode_tile(bidx[ty*8:ty*8+8, tx*8:tx*8+8]) for ty in range(12) for tx in range(12))
    small = b"".join(encode_tile(sidx[ty*8:ty*8+8, tx*8:tx*8+8]) for ty in range(4) for tx in range(4))
    words = [int(c[0] | (c[1] << 5) | (c[2] << 10)) for c in pal]
    parts = [big[i*1152:(i+1)*1152] for i in range(4)]   # 36 tiles each
    lua = [f"-- face{n}.lua: player-select portrait {n} (generated by tools/faces.py; zero-run RLE then base64)", "FACE = FACE or {}",
           f"FACE[{n}] = {{ bsum = {sum(big) % 65536}, ssum = {sum(small) % 65536}, psum = {{{','.join(str(sum(p) % 65536) for p in parts)}}},",
           "  pal = {" + ",".join(str(w) for w in words) + "},",
           f'  small = "{base64.b64encode(rle(small)).decode()}",']
    for i, p in enumerate(parts):
        lua.append(f'  b{i+1} = "{base64.b64encode(rle(p)).decode()}",')
    lua.append("}")
    lua.append("")
    open(os.path.join(outdir, f"face{n}.lua"), "w").write("\n".join(lua))

def preview_tile(pal, idx):
    out = np.zeros(idx.shape + (3,), np.uint8)
    out[...] = (24, 24, 96)
    m = idx > 0
    out[m] = pal[idx[m] - 1] * 8 + 4
    return out

if __name__ == "__main__":
    outdir = os.path.join(here, "..", "toy")
    sheet = Image.new("RGB", (8 * 100, 100 + 40), (24, 24, 96))
    for i, fn in enumerate(FACES):
        f = Face(); fn(f)
        big = f.image(96); small = f.image(32, crop=7)
        pal, bidx, sidx = quantize_face(big, small)
        emit(i + 1, pal, bidx, sidx, outdir)
        sheet.paste(Image.fromarray(preview_tile(pal, bidx)), (i * 100 + 2, 2))
        sheet.paste(Image.fromarray(preview_tile(pal, sidx)), (i * 100 + 2, 104))
        print(NAMES[i], "ok")
    sheet.resize((sheet.width * 2, sheet.height * 2), 0).save(os.path.join(here, "..", "render", "faces_preview.png"))
