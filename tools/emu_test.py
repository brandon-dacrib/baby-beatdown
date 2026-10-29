#!/usr/bin/env python3
"""emu_test.py: run dist/baby-beatdown.sfc headless in Mesen2 and get screenshots + engine state back.

Mesen's test runner forbids Lua file I/O, so the script writes each screenshot (Mesen's own PNG) and the
256-byte zero page etc. into the cartridge's 128 KB save RAM (32 KB per snapshot); Mesen writes that to disk on exit.
usage: emu_test.py OUTPREFIX FRAME[,FRAME...] [--input FRAME-FRAME:keys ...] [--rom ROM] [--mesen PATH]
  keys: letters from a b x y l r s(elect) t(start) u d l(eft)->L  r(ight)->R, e.g. 30-60:R  90-92:y
  writes OUTPREFIX_<frame>.png and prints the fighter state at each snapshot."""
import os, subprocess, sys, struct
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
mesen = os.path.join(root, ".tools/mesen/Mesen.app/Contents/MacOS/Mesen")
rom = os.path.join(root, "dist/baby-beatdown.sfc")
srm = os.path.expanduser("~/Library/Application Support/Mesen2/Saves/baby-beatdown.srm")
args = [a for a in sys.argv[1:] if a not in ("--bg3", "--oam", "--full")]
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
       "  local png = emu.takeScreenshot()",
       "  local n = #png",
       "  emu.write(base, n & 255, emu.memType.snesSaveRam); emu.write(base + 1, (n >> 8) & 255, emu.memType.snesSaveRam)",
       "  for i = 1, n do emu.write(base + 1 + i, string.byte(png, i), emu.memType.snesSaveRam) end",
       "  for i = 0, 255 do emu.write(base + 0x7000 + i, emu.read(i, emu.memType.snesWorkRam), emu.memType.snesSaveRam) end",
       "  for i = 0, 543 do emu.write(base + 0x7100 + i, emu.read(i, emu.memType.snesSpriteRam), emu.memType.snesSaveRam) end",
       "  for i = 0, 511 do emu.write(base + 0x7400 + i, emu.read(i, emu.memType.snesCgRam), emu.memType.snesSaveRam) end",
       "  for i = 0, 511 do emu.write(base + 0x7600 + i, emu.read(0xC000 + i, emu.memType.snesVideoRam), emu.memType.snesSaveRam) end",
       "  local spct = emu.memType.spcRam or emu.memType.spcMemory",
       "  for i = 0, 31 do emu.write(base + 0x7800 + i, emu.read(0x200 + i, spct), emu.memType.snesSaveRam) end",
       "  for i = 0, 15 do emu.write(base + 0x7820 + i, emu.read(0x300 + i, spct), emu.memType.snesSaveRam) end",
       "  for i = 0, 3 do emu.write(base + 0x7830 + i, emu.read(0xF4 + i, spct), emu.memType.snesSaveRam) end",
       "  for i = 0, 1791 do emu.write(base + 0x7840 + i, emu.read(0x420 + i, emu.memType.snesWorkRam), emu.memType.snesSaveRam) end",
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
    n = d[base] | d[base + 1] << 8
    open(f"{out}_{fr}.png", "wb").write(d[base + 2: base + 2 + n])
    zp = d[base + 0x7000: base + 0x7100]
    def w(i): return struct.unpack_from("<h", zp, i)[0]
    print(f"frame {fr}: " + " ".join(f"{n}={w(i*4)}/{w(i*4+2)}" for i, n in enumerate(ZP)))
    oam = d[base + 0x7100: base + 0x7100 + 544]; cg = d[base + 0x7400: base + 0x7600]; vr = d[base + 0x7600: base + 0x7800]
    print("  oam0..1:", oam[:8].hex(), "hi:", oam[512:514].hex(), "| cgram 0..3:", cg[:8].hex(), "slot3:", cg[96:104].hex(), "obj0:", cg[256:264].hex(), "| vram $6000:", vr[:16].hex(), "nonzero:", sum(1 for b in vr if b))
    spc = d[base + 0x7800: base + 0x7840]
    print("  spc $200:", spc[:12].hex(), "$300:", spc[32:40].hex(), "ports:", spc[48:52].hex())
    bg3 = d[base + 0x7840: base + 0x7840 + 1792]
    if "--bg3" in sys.argv:
        for row in range(28):
            words = struct.unpack_from("<32H", bg3, row * 64)
            if any(words): print(f"  bg3 row {row:2d}: " + " ".join(f"{w & 1023:3d}" for w in words))
    if "--oam" in sys.argv:
        for n in range(16): print(f"  oam {n:2d}: {oam[n*4:n*4+4].hex()}", "hi", f"{(oam[512 + n // 4] >> ((n % 4) * 2)) & 3}")
    print(f"  pad={zp[0x7c]|zp[0x7d]<<8:04x} frame_ctr={w(0x80)} clock={w(0x82)} rng={w(0x84)} ai_t={w(0x86)} ai_plan={w(0x88)} spr={w(0x74)&0xffff:04x}/{w(0x76)&0xffff:04x} bank={zp[0x78]:02x}/{zp[0x7a]:02x}")
print("exit", r.returncode)
