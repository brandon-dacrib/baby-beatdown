# How Street Fighter II Turbo (SNES, USA Rev 1) is built — notes for Baby Beatdown

Analysis of the retail ROM done 2026-10-24 with a home-made tracing 65816 disassembler
(`~/Downloads/sf2t-disasm/`, not in git: listing, tracer, tile renders). These are my findings; no
ROM bytes are reproduced here.

## Cartridge
- HiROM, 20 Mbit (2.5 MB, banks $C0–$E7), no SRAM, internal checksum valid.
- Reset `$C0:FFA0` → init at `$C0:0000`; NMI `$C0:0199`; IRQ `$C0:04EE`. Unused vectors share one RTI stub.
- 65816 code: ~71 KB, all in banks $C0 (35 % code) and $C1 (74 %). Everything else is data.

## Bank map
| banks | contents |
|---|---|
| $C0–$C1 | code, jump tables, small ROM HDMA tables, per-stage HDMA tables ($C1:EF5F, 80 B each) |
| $C2 | stage graphics descriptors (two-level pointer table at $C2:0078 → 5-byte DMA entries) |
| $C3 | misc tables (menu/portrait data) |
| $C4 | **per-character, per-frame tile-streaming lists** (12 chars; Ken points at Ryu's) |
| $C5–$CC | packed data (stage graphics/tilemaps; high entropy, not raw 4bpp) |
| $CD | stage palettes + stage tables |
| $CF | **~280 16-colour palettes** ($CF:C000–$CF:F5xx), character stat/velocity tables |
| $D0–$E2 | **raw uncompressed 4bpp sprite tiles**, one contiguous run per character |
| $E3–$E7 | SPC700 driver (2.6 KB to ARAM $02C0), then sample/sequence sets (one 26 KB block) |

## Kernel: coroutine scheduler, not a state machine
- Six task slots in direct page ($30–$8F, 16 B each). Each slot has its **own stack pointer and saved
  PC**; switching is `TCS` + push PC + `RTS`. State 1 = start, 2 = sleeping N frames, 3 = running.
- Main loop: clear frame flag → spin until NMI sets it → bump frame counter → run every task slot →
  run the VRAM request queue → repeat. 60 Hz logic; a lag frame skips OAM/VRAM DMA but keeps IRQs.
- Two fighters are 0x200-byte blocks at $0500 and $0700, accessed with **D = $0500/$0700** so all
  fighter code is 8-bit direct-page addressing (`$D1` = character id, `$00` = state, `$34` bit 6 = facing,
  `$1C` = pointer into the character's frame table, `$2B/$2D/$31/$33` = x/y velocity and accel).
- On character select, a **0x2500-byte character block** (animation scripts, OAM piece lists, boxes)
  is copied from ROM into WRAM through $2180 so the per-frame code reads it from RAM.

## Frame pipeline (the part worth copying)
NMI, in order:
1. Force-blank immediately (A=$80 → $2100) to buy DMA time; brightness restored at the end from a shadow.
2. Optional 1 KB tilemap DMA ($7E:9B00 → VRAM $3800/$4800).
3. OAM DMA: 0x220 B from $1320 (shadow OAM, hi-table at $1520).
4. Optional CGRAM DMA: 0x200 B from $0100 (shadow palette; dirty flag `$A2`).
5. Optional HUD patch: 0xA0 B from $1740 → VRAM $4860 (health bars).
6. Tilemap clears: bitmask `$A3` selects fixed 4 KB/2 KB fills with a constant word.
7. **VRAM DMA queue**: up to 26 eight-byte entries at $0300: `[vmain][vaddr16][len16][src16][bank]`.
8. Inline-data queue at $0400: `[vmain][vaddr16][len8]` + data (small tilemap/text writes).
9. HDMA enable from shadow `$C1`; HDMA tables double-buffered $16D0 → $1680 (0x50 B) with MVN.
10. Scroll shadows $B3–$BE → $210D–$2112. TM from shadow `$BF`.
11. Arm H/V IRQ timers, read pads (new-press = `new & (new ^ old)`), RTI.

Mid-frame IRQ chain during a fight (state machine on `$1844`, table at `$C0:050A`):
- line 21: enable HDMA (the 21-line HUD is drawn **without** HDMA), re-arm at line 22
- line 22: write brightness
- **line 215: HDMA off + force blank.** The bottom 9 lines are sacrificed so vblank is ~40 % longer, and
  OAM DMA runs here when the frame is already finished.

HDMA channels: ch1 → BGMODE per scanline (title: mode 7 logo rows then mode 1), ch2 → CGADSUB
(colour-math region), ch3 → TM (layer enable region), ch4/5 → per-stage scroll tables (floor parallax).
Fixed colour ($2132) is written as RGB triplets for tinting (e.g. $23/$4C/$98) and $E0 for black.

## Sprite tile streaming — the central trick
Fighters are NOT resident in VRAM. Each animation frame has a list of DMA chunks in bank $C4:
`[len/16][src16][srcbank][destpage|last]`. Each frame the fighter task pushes its frame's chunks onto the
$0300 queue; P1's land at VRAM $x000, P2's at $x800 (bit 3 of the page byte). A per-frame budget counter
(`$F3`, 208 units × 16 B ≈ 3.3 KB) stops the queue from overrunning vblank.

| char | frames | avg B/frame | max B/frame | chunks/frame |
|---|---|---|---|---|
| Ryu/Ken | 129 | 1413 | 3040 | 3.5 |
| Honda | 98 | 1866 | 3584 | 1.7 |
| Blanka | 90 | 1957 | 3104 | 3.2 |
| Guile | 129 | 1368 | 3040 | 1.4 |
| Chun-Li | 120 | 1196 | 3040 | 1.9 |
| Zangief | 109 | 2075 | 3840 | 1.6 |
| Dhalsim | 123 | 1375 | 3040 | 1.8 |
| Balrog | 86 | 1437 | 3840 | 1.3 |
| Vega | 72 | 1594 | 3040 | 2.1 |
| Sagat | 84 | 1559 | 3040 | 2.5 |
| Bison | 88 | 1358 | 3040 | 1.0 |

So a fighter is ~90–130 frames, ~1.5 KB of fresh tiles per frame, tiles stored uncompressed so DMA can
read them straight from ROM. The source bank set per character spans two or three 64 KB banks.

## Sound
- Driver uploaded with the stock IPL handshake ($BBAA / $CC) from a 3-byte table at $E3:0000.
- Game → SPC: a 16-entry ring at $1720 (cmd, arg); NMI sends at most **one command per frame** with a
  sequence counter echoed in port 2.

## What this means for the cart version of Baby Beatdown (cf. PORT.md)
1. **Stream, don't make resident.** PORT.md item 2 assumes a 32 KB OBJ window holding two whole
   fighters. SF2T instead keeps one frame per fighter in VRAM and streams ~1.5 KB/frame from
   uncompressed ROM through a budgeted vblank queue. With pre-rendered 4bpp pose sheets that is exactly
   `---@snes vblank` work: per-pose `dma()` of a 1–3 KB chunk into a fixed per-player page.
2. **Steal vblank.** Force blank at NMI entry, and consider blanking the last 8–9 scanlines (SF2T
   blanks from line 215) if the queue cannot drain; HUD rows at the top need no HDMA.
3. **Shadow everything.** OAM, CGRAM, scrolls, TM, HDMA enable all live in WRAM shadows written during
   the frame and flushed in one place. The Studio's `obj[]`/`cgram[]` are already shadows; the cart
   dialect wants the same discipline, not `vram[]` from `frame()`.
4. **Fighters as two fixed 0x200-byte records**, fields by integer offset, facing as one bit, velocities
   from constant tables indexed by move id and sign-flipped by facing. This is the parallel-array layout
   PORT.md item 1 describes.
5. **Per-stage HDMA as constant tables** (80 B each, indexed by stage) — `---@snes hdma-bake`.
6. **Budget numbers to aim at**: ≤ 3.3 KB tiles/frame, ≤ 26 DMA entries/frame, 0x220 B OAM, one sound
   command per frame, 12 KB character block in WRAM per fighter (ours can be far smaller).

---

# Part 2 (2026-10-25): character data, hit boxes, animation scripts, stage packing

All of this was verified by re-rendering from the decoded data: Ryu's idle pose with its boxes
overlaid, Zangief's first frame, Ryu's castle and Guile's air base (`~/Downloads/sf2t-disasm/`:
`sprite2.py`, `stage.py`, `dec.py`, `*.png`).

## Per-fighter pointer set (loaded at fighter init from the character id, 0–11)
| field | from | points at |
|---|---|---|
| frame-stream list | bank $C4 word table | per-frame VRAM DMA chunk lists (Part 1) |
| animation scripts | bank $C3 word table | per-character script table |
| box-set records | bank $C3 word table (+$1A) | 16-byte records, one per "pose box set" |
| box lists | bank $C4 word table (+$1C) | per-character hurt/attack/push box lists |
| OAM piece lists | banks $CE/$CF, copied to WRAM ($7E:5000 P1, $7E:7500 P2) | per-frame sprite assembly |
| palette | bank $CF via a word table | 16 colours, alt palette at +$40 |

Ryu's WRAM block is 7.1 KB; the copy is a flat 9.5 KB (0x2500) regardless of character.

## Animation script = 4-byte keyframes
`[frames to hold][flags: $80 = last][sprite frame id][box-set id]`

Ryu idle: frames 0,1,0,2 held 6,5,6,5 frames, box set 1 throughout. The interpreter decrements the
hold counter each frame; on zero it advances 4 bytes, requests the new frame's tiles (Part 1 streaming),
resolves the OAM piece list, and copies the 16-byte box-set record into the fighter record. Moves are
entered by handing the interpreter a script number, which also drives the per-move velocity tables.

## OAM piece list (one per sprite frame)
`[count]` then `count × [x][y][tile][attr]`, x/y signed bytes relative to the fighter origin, `attr`
bit 0 = 16x16 (else 8x8), bits 6–7 = flips, palette bits OR'd in. Facing is applied by negating x
and subtracting the piece width. Ryu's idle is 13 pieces, mostly 16x16. The tile numbers index the
per-player VRAM window ($7000 P1, $7800 P2 in word addresses), which is why the streamed chunks per
frame are laid out to match the 16-tiles-per-row OAM numbering.

## Boxes
Box-set record (16 bytes): `[hurt0 idx][hurt1 idx][hurt2 idx][hurt3 idx][attack idx][push idx][flags…]`.
Each index selects an entry in that character's box lists: hurt and push boxes are 4 bytes
`[cx][cy][half w][half h]`, attack boxes 12 bytes `[cx][cy][half w][half h][damage][…][hit kind][…][sound][fx]`.
cx is signed and facing-flipped, cy is measured upward from the feet. Ryu standing: head box centre
(−2, 69) ±7, body (3, 45) ±(11, 18), legs (3, 12) ±(11, 14), push box (0, 35) ±(9, 34).

Overlap test (bank $C0, $5C62): world x = fighter.x ± box.cx, then
`|x1 − x2| ≤ w1 + w2` done as `(dx + s) ≤ 2s`, same for y. Push-box separation runs every frame between
the two fighters; attack-vs-hurt runs per hurt slot in order head, body, legs, extra.

## Stage graphics
- **Load lists** (bank $C0, table at $9B43, 7-byte entries `[size16][vram16][src16][bank]`,
  terminator has bit 0 set). A bank byte with bits 6–7 clear means "compressed": the real bank is
  `byte | $C0`, the data is decompressed into bank $7F and DMA'd from there. Per-stage list = $10 + stage;
  per-stage palette set = `$C0:D0B9[stage]`, resolved through a word table at `$C0:F1B3` into
  `[count][src16 in $CF][first colour]` entries.
- **Compressor** (`$C0:0FBC`): output is produced 16 bytes at a time. A block is either
  `$15` + 16 literal bytes, or `[fill byte][mask16]` followed by one literal byte for every set mask bit
  (MSB first); clear bits emit the fill byte. Stage tile sets compress to 70–77 %.
  It is a tile-oriented RLE: cheap to decode, no back-references, decodes in a straight line.
- **Stage map** (bank $CD): three-level metatiles. 16x16 metatile = 4 tilemap words at `$CD:0000+m`;
  32x32 block = 4 metatile offsets at `$CD:B000+b`; 256x32 strip = 8 block offsets at `$CD:9000+idx*16`;
  a 32x32-tile screen = 7 strips (224 px) + flag byte carrying strip index bit 8; a stage = 6 screens,
  48 bytes at `$CD:F800+stage*48`. The builder expands this into bank $7F, from where columns are DMA'd
  as the camera scrolls (BG1 and BG2 are 64x32 tilemaps at $3800 and $4000, char base $0000, Mode 1).
- Bank $C2 holds per-stage **animation DMA lists** (5-byte `[vmain|size][vram16][src16]`) consumed
  through the 64-entry ring with the per-frame budget: crowd and water animation as tilemap patches.

## What to copy into Baby Beatdown
1. **Keyframe scripts as 4-byte records** `[hold][flags][frame][boxset]` in constant integer arrays,
   one script table per character; a 10-line interpreter replaces the layered `update_fighter` chain.
2. **Boxes as indices, not literals.** A box-set record per pose referencing per-character box lists
   keeps the data tiny (Ryu: ~130 box-set records, ~60 hurt boxes, ~40 attack boxes) and makes the
   overlap test a fixed-shape loop over four hurt slots.
3. **Centre/half-extent boxes and the `(dx+s) ≤ 2s` test**: integer only, no multiplies, branch-free
   except the facing flip.
4. **OAM piece lists per frame** (count + 4 bytes/piece) with 16x16 pieces: Ryu is 13 pieces, so two
   fighters fit under the 32-sprites-per-line limit with room for projectiles.
5. **Stage maps as metatile hierarchies** (16 → 32 → 256x32 → screen): a 768 px stage costs under 2 KB
   of map data plus a few KB of compressed tiles, decoded once at round start into a WRAM buffer that
   feeds column DMAs during scroll.
6. **A 16-byte-block fill+mask compressor** is enough for tiles and is trivial to write in the cart
   dialect if VRAM budget ever forces compression; otherwise store tiles raw as SF2T does for sprites.
