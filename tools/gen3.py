import sys
sys.argv=['x']
from gen import FX, KINDS as FKINDS
from gen2 import tiles_of, hexcol
# fx palette slot: 1 outline,5 white,7 brown,8 pink,9 blue,a red,b orange,c green,d lightgreen,e cyan,f yellow, 2 grey,3 dark grey,4 light grey, 6 purple
FX_PAL=['#201830','#8080a0','#404060','#d0d0e0','#ffffff','#9050c0','#8a5a2a','#ff9ad0','#5aa0ff','#e03030','#ff9030','#70d040','#c0f090','#b0f0ff','#ffe040']
MAP={ # c,d,e per projectile
 'human':('5','7','4'), 'puppy':('5','9','4'), 'kitten':('a','f','5'), 'piglet':('9','8','5'),
 'duck':('e','5','5'), 'bear':('b','f','5'), 'bunny':('5','8','4'), 'bug':('c','d','5')}
SPARK=[ # hit spark
"................",
".......f........",
".......f........",
"...f..fff..f....",
"....f.f5f.f.....",
".....ff5ff......",
"..ffff555ffff...",
"..ff5555555ff...",
".....ff5ff......",
"....f.f5f.f.....",
"...f..fff..f....",
".......f........",
".......f........",
"................",
"................",
"................"]
BLOCK=[
"................",
"......9999......",
".....9eeee9.....",
"....9ee99ee9....",
"....9e9ee9e9....",
"....9e9ee9e9....",
"....9ee99ee9....",
".....9eeee9.....",
"......9999......",
"................",
"................",
"................",
"................",
"................",
"................",
"................"]
CURSOR=[ # P1 marker hand/arrow down
"................",
"......ffff......",
".....f5555f.....",
".....f5555f.....",
"......ffff......",
"......1ff1......",
".....1ffff1.....",
"....1ffffff1....",
"...1ffffffff1...",
"..111ffffff111..",
".....1ffff1.....",
"......1ff1......",
".......11.......",
"................",
"................",
"................"]
STAR=[ # dizzy star
"................",
"................",
".......f........",
"......fff.......",
"....fff5fff.....",
".....f555f......",
"......f5f.......",
".....ff.ff......",
"....f.....f.....",
"................",
"................",
"................",
"................",
"................",
"................",
"................"]
cells=[]
for k in FKINDS:
    cm,dm,em=MAP[k]
    cells.append([[('.' if ch=='.' else {'c':cm,'d':dm,'e':em}.get(ch,ch)) for ch in r] for r in FX[k]])
for g in (SPARK,BLOCK,CURSOR,STAR): cells.append([list(r) for r in g])
# encode: cell n -> tiles base + (n%8)*2 + (n//8)*32 ; base tile 384 (word 0x7800)
import gen2
out={}
for n,c in enumerate(cells):
    # pad canvas to 32x32 for tiles_of (expects c[y][x] indexable)
    big=[['.']*32 for _ in range(32)]
    for y in range(16):
        for x in range(16): big[y][x]=c[y][x]
    for ty in range(2):
        for tx in range(2):
            w=tiles_of(big,tx*8,ty*8)
            if any(w):
                tile=384+(n%8)*2+(n//8)*32+ty*16+tx
                out[tile]=''.join('%04x'%v for v in w)
lines=["-- FX: projectiles (cells 0..7 per character), 8 hit spark, 9 block spark, 10 cursor, 11 star"]
lines.append("FX_PAL = { "+', '.join('{%d,%d,%d}'%hexcol(h) for h in FX_PAL)+" }")
lines.append("FX_TILES = {")
for t in sorted(out): lines.append(f"  [{t}] = \"{out[t]}\",")
lines.append("}")
open('fx.lua','w').write('\n'.join(lines)+'\n')
print(len(out),'fx tiles')
