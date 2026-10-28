#!/usr/bin/env python3
"""emu_test.py: run dist/baby-beatdown.sfc headless in Mesen2 and get screenshots + engine state back.

Mesen's test runner forbids Lua file I/O, so the script writes half-resolution RGB555 screenshots (128x112)
and the 256-byte zero page into the cartridge's 128 KB save RAM; Mesen writes that to disk on exit.
usage: emu_test.py OUTPREFIX FRAME[,FRAME...] [--input FRAME-FRAME:keys ...] [--rom ROM] [--mesen PATH]
  keys: letters from a b x y l r s(elect) t(start) u d l(eft)->L  r(ight)->R, e.g. 30-60:R  90-92:y
  writes OUTPREFIX_<frame>.png and prints the fighter state at each snapshot."""
import os, subprocess, sys, struct
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
mesen = os.path.join(root, ".tools/mesen/Mesen.app/Contents/MacOS/Mesen")
rom = os.path.join(root, "dist/baby-beatdown.sfc")
srm = os.path.expanduser("~/Library/Application Support/Mesen2/Saves/baby-beatdown.srm")
args = sys.argv[1:]
inputs = []
while "--input" in args:
    i = args.index("--input"); spec = args[i + 1]; del args[i:i + 2]
    rng, keys = spec.split(":"); a, b = rng.split("-"); inputs.append((int(a), int(b), keys))
if "--rom" in args:
    i = args.index("--rom"); rom = args[i + 1]; del args[i:i + 2]
out = args[0]; frames = [int(x) for x in args[1].split(",")][:4]
KEYMAP = {"a": "a", "b": "b", "x": "x", "y": "y", "l": "l", "r": "r", "s": "select", "t": "start",
          "U": "up", "D": "down", "L": "left", "R": "right"}
lua = ["local shots = {" + ", ".join(f"[{f}]={k}" for k, f in enumerate(frames)) + "}",
       "local last = " + str(max(frames)),
       "local inputs = {" + ", ".join("{%d,%d,{%s}}" % (a, b, ", ".join(f"{KEYMAP[c]}=true" for c in keys)) for a, b, keys in inputs) + "}",
       "local f = 0",
       "local function dump(k)",
       "  local base = k * 0x8000",
       "  local px = emu.getScreenBuffer()",
       "  local sz = emu.getScreenSize()",
       "  local w = sz.width",
       "  local o = base",
       "  for y = 0, 111 do",
       "    for x = 0, 127 do",
       "      local c = px[1 + (y * 2) * w + x * 2]",
       "      local r = (c >> 19) & 31",
       "      local g = (c >> 11) & 31",
       "      local b = (c >> 3) & 31",
       "      local v = r | (g << 5) | (b << 10)",
       "      emu.write(o, v & 255, emu.memType.snesSaveRam)",
       "      emu.write(o + 1, v >> 8, emu.memType.snesSaveRam)",
       "      o = o + 2",
       "    end",
       "  end",
       "  for i = 0, 255 do emu.write(base + 0x7000 + i, emu.read(i, emu.memType.snesWorkRam), emu.memType.snesSaveRam) end",
       "  for i = 0, 543 do emu.write(base + 0x7100 + i, emu.read(i, emu.memType.snesSpriteRam), emu.memType.snesSaveRam) end",
       "  for i = 0, 511 do emu.write(base + 0x7400 + i, emu.read(i, emu.memType.snesCgRam), emu.memType.snesSaveRam) end",
       "  for i = 0, 511 do emu.write(base + 0x7600 + i, emu.read(0xC000 + i, emu.memType.snesVideoRam), emu.memType.snesSaveRam) end",
       "  local spct = emu.memType.spcRam or emu.memType.spcMemory",
       "  for i = 0, 31 do emu.write(base + 0x7800 + i, emu.read(0x200 + i, spct), emu.memType.snesSaveRam) end",
       "  for i = 0, 15 do emu.write(base + 0x7820 + i, emu.read(0x300 + i, spct), emu.memType.snesSaveRam) end",
       "  for i = 0, 3 do emu.write(base + 0x7830 + i, emu.read(0xF4 + i, spct), emu.memType.snesSaveRam) end",
       "end",
       "emu.addEventCallback(function()",
       "  for _, inp in ipairs(inputs) do",
       "    if f + 1 >= inp[1] and f + 1 <= inp[2] then emu.setInput(inp[3], 0) end",
       "  end",
       "end, emu.eventType.inputPolled)",
       "emu.addEventCallback(function()",
       "  f = f + 1",
       "  if shots[f] then dump(shots[f]) end",
       "  if f >= last then emu.stop(0) end",
       "end, emu.eventType.endFrame)"]
script = os.path.join(root, ".tools/run/_test.lua")
open(script, "w").write("\n".join(lua) + "\n")
if os.path.exists(srm): os.remove(srm)
r = subprocess.run([mesen, "--testrunner", rom, script], capture_output=True, text=True, timeout=180)
if not os.path.exists(srm):
    print("no save file written; exit", r.returncode); print(r.stdout[-2000:]); sys.exit(1)
d = open(srm, "rb").read()
from PIL import Image
ZP = ["fx", "fy", "fvx", "fvy", "fface", "fchar", "fhp", "fmeter", "fstate", "ftimer", "fmove", "fhitdone", "flast",
      "fflash", "fwins", "fscript", "fkey", "fhold", "fcell", "fshown", "fboxset", "factive"]
for k, fr in enumerate(frames):
    base = k * 0x8000
    img = Image.new("RGB", (128, 112))
    pix = img.load()
    for y in range(112):
        for x in range(128):
            v = struct.unpack_from("<H", d, base + (y * 128 + x) * 2)[0]
            pix[x, y] = ((v & 31) * 8, ((v >> 5) & 31) * 8, ((v >> 10) & 31) * 8)
    img = img.resize((256, 224), Image.NEAREST)
    img.save(f"{out}_{fr}.png")
    zp = d[base + 0x7000: base + 0x7100]
    def w(i): return struct.unpack_from("<h", zp, i)[0]
    print(f"frame {fr}: " + " ".join(f"{n}={w(i*4)}/{w(i*4+2)}" for i, n in enumerate(ZP)))
    oam = d[base + 0x7100: base + 0x7100 + 544]; cg = d[base + 0x7400: base + 0x7600]; vr = d[base + 0x7600: base + 0x7800]
    print("  oam0..1:", oam[:8].hex(), "hi:", oam[512:514].hex(), "| cgram 0..3:", cg[:8].hex(), "slot3:", cg[96:104].hex(), "obj0:", cg[256:264].hex(), "| vram $6000:", vr[:16].hex(), "nonzero:", sum(1 for b in vr if b))
    spc = d[base + 0x7800: base + 0x7840]
    print("  spc $200:", spc[:12].hex(), "$300:", spc[32:40].hex(), "ports:", spc[48:52].hex())
    print(f"  pad={zp[0x7c]|zp[0x7d]<<8:04x} frame_ctr={w(0x80)} clock={w(0x82)} rng={w(0x84)} ai_t={w(0x86)} ai_plan={w(0x88)} spr={w(0x74)&0xffff:04x}/{w(0x76)&0xffff:04x} bank={zp[0x78]:02x}/{zp[0x7a]:02x}")
print("exit", r.returncode)
