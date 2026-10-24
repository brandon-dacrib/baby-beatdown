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
