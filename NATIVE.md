# Native SNES build (65816 + SPC700), 2026-10-28

The cartridge is now built here, with no Studio or Lua in the loop: `make` produces `dist/baby-beatdown.sfc`
(1 MB LoROM/FastROM, 60 Hz). The Studio toy in `toy/` stays as the design reference and the source of the
art and tuning data.

## Toolchain

| tool | from | used for |
|---|---|---|
| ca65 / ld65 | `brew install cc65` | the 65816 game (`src/main.s`, `src/lorom.cfg`) |
| wla-spc700 / wlalink | `brew install wla-dx` | the SPC700 sound driver (`src/spc.s`) |
| Python 3 + numpy + pillow | `.venv/` | data generators in `tools/` |
| Mesen2 2.1.1 (macOS arm64) | `.tools/mesen/` (not in git) | headless verification (`tools/emu_test.py`) |

## Files

| path | what |
|---|---|
| `src/main.s` | boot, video init, NMI (OAM DMA, HUD rows, one 2 KB pose upload per frame), engine (port of `cart/main.lua`), HUD, audio (IPL upload, command send, 60 Hz sequencer, sfx) |
| `src/snes.inc` | register names, width macros, byte-table load macros |
| `src/spc.s` | SPC700 command server: volume / note on / note off per voice; samples at $0300, ADSR table at $0340 |
| `src/lorom.cfg` | bank 0 code+data, banks 1..28 sprite data, bank 29 audio |
| `tools/gen_asm.py` | `gen/data.inc` (moves, boxes, keyframe scripts, per-character tables), `gen/charN.bin` (56 poses x 2 KB, one 64x64 OBJ each), stage tiles/map/palettes, 2bpp HUD font |
| `tools/gen_audio.py` | synthesizes the 15 instruments, BRR-encodes them, converts `toy/sources/songs/*.json` to `[delta frames][cmd][p1][p2][p3]` streams (48 ticks per beat) |
| `tools/emu_test.py` | runs the ROM in Mesen2's test runner with injected pad input; screenshots + zero page + OAM/CGRAM/VRAM/SPC probes come back through the 128 KB save RAM (Mesen's Lua may not write files) |
| `tools/fixsum.py` | header checksum |

## Design (what differs from the Studio cart)

- **Fighters are single 64x64 OBJs** (OBSEL size 2), P1 tiles at OBJ columns 0..7, P2 at 8..15, rows 0..7.
  A pose is 8 x 256-byte DMAs; only one fighter uploads per NMI (two overrun the vertical blank by ~80 bytes).
  Every pose of every character is in ROM (`gp = (char-1)*56 + cell`, bank `$81 + gp/16`, offset
  `$8000 + (gp%16)*2048`), so the keyframe scripts use the real crouch/jump/hit/KO/reaction poses.
- **Mode 1**: BG1 = painted stage (4bpp, palettes 0,3..7, tiles at VRAM $0000, map at $4000), BG3 = HUD
  (2bpp font at $3000, map at $3C00, rows 1..3 DMA'd from a 192-byte shadow each frame, palette 5).
  Backdrop colour stands in for the sky gradient (no HDMA yet).
- **Engine** is the Lua engine line for line, 16-bit parallel arrays indexed by X = 0/2, 60 Hz logic.
  No range contracts exist on hardware: the Lua crash class is gone. Round flow: a KO that has rested 120
  frames scores and resets.
- **Audio**: the SPC700 only executes commands (so there is no SPC-side sequencer to debug); the main CPU
  plays `SONG_BAYOU` at 60 Hz on voices 0..5 and sound effects on 6..7 (hat on every attack, snare on hit,
  tom on block, crash on KO). Instruments are synthesized approximations of the Studio's built-ins.

## Verify

```
make
.venv/bin/python tools/emu_test.py .tools/run/t 100,400 --input 60-120:R --input 150-152:y
```
Writes `.tools/run/t_100.png`, `t_400.png` and prints the fighter state at each frame. Mesen needs port 1
set to a SNES controller (Settings > Input) for injected input to register; its save file lands in
`~/Library/Application Support/Mesen2/Saves/`.

## Not done yet

- title / character select (always Brandon vs CPU Arlo on the bayou), the other seven stages and songs
  (the generators take a stage number; the ROM wires in stage 1 and the bayou song only)
- sky gradient (HDMA), shadows, hit sparks, projectiles / supers (the super input only plays a pose)
- 2-player input, a match-end screen (after two wins the counters reset)
- audio only verified structurally (driver and samples land in SPC RAM, commands are acknowledged); nobody has listened yet
