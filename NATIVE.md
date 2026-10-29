# Native SNES build (65816 + SPC700), 2026-10-29

The cartridge is built here, with no Studio or Lua in the loop: `make` produces `dist/baby-beatdown.sfc`
(2 MB LoROM/FastROM, 60 Hz). The Studio toy in `toy/` stays as the design reference and the source of the
art and tuning data.

## Toolchain

| tool | from | used for |
|---|---|---|
| ca65 / ld65 | `brew install cc65` | the 65816 game (`src/main.s`, `src/screens.s`, `src/lorom.cfg`) |
| wla-spc700 / wlalink | `brew install wla-dx` | the SPC700 sound driver (`src/spc.s`) |
| Python 3 + numpy + pillow | `.venv/` | data generators in `tools/` |
| Mesen2 2.1.1 (macOS arm64) | `.tools/mesen/` (not in git) | headless verification (`tools/emu_test.py`) |

## Files

| path | what |
|---|---|
| `src/main.s` | boot, video init, NMI (OAM, whole BG3 map, one 2 KB upload per frame, palette requests), engine (port of `cart/main.lua`), HUD, audio (IPL upload, command send, 60 Hz sequencer, sfx) |
| `src/screens.s` | title, player select (1P or 2P), fight flow (rounds, callouts, match end, attract demo), stage loader, fades, HDMA sky + scroll bands, ambient sprites, palette cycle/flicker, shadows, hit sparks, text |
| `src/specials.s` | meter supers (projectile or rush per baby, with the name callout), crouch-punch shots for four babies, the two projectile slots |
| `src/snes.inc` | register names, width macros, byte-table load macros |
| `src/spc.s` | SPC700 command server: volume / note on / note off per voice; samples at $0300, ADSR table at $0340 |
| `src/lorom.cfg` | bank 0 code+data, banks 1..28 sprite data, bank 29 audio + songs, banks 30.. packed stage/screen data |
| `tools/gen_asm.py` | `gen/data.inc` (moves, boxes, keyframe scripts, per-character tables), `gen/charN.bin` (56 poses x 2 KB), 2bpp HUD font (+ bracket corner glyph 49) |
| `tools/gen_screens.py` | the nine paintings (stages 1..8 + the select map) as tiles/maps/palettes, title logo, 96x96 portraits + 32x32 icons, 32x32 effect cells (crowd, birds, butterflies, candles, shadow, sparks), sky gradient HDMA tables, per-stage ambient records, select labels; packs it all into 32 KB banks (`gen/screens.inc`) |
| `tools/gen_audio.py` | synthesizes the 15 instruments, BRR-encodes them, converts all nine `toy/sources/songs/*.json` to `[delta frames][cmd][p1][p2][p3]` streams (48 ticks per beat) |
| `tools/emu_test.py` | runs the ROM in Mesen2's test runner with injected pad input; Mesen's own PNG screenshot + zero page + OAM/CGRAM/VRAM/SPC probes come back through the 128 KB save RAM (Mesen's Lua may not write files). `--bg3` / `--oam` print the text layer and sprite table |
| `tools/fixsum.py` | header checksum |

## Screens

- **Title**: logo on BG2 (priority above the stage), a random stage with its song and a random pair of babies
  posing (jab / kick on a 4 s beat), "PUSH START" blinking. The stage and pair re-roll every 7 s; after 15 s
  without input the attract mode runs: the select screen picks by itself (wandering cursor, random
  opponent), then a CPU-vs-CPU match ("DEMO - PUSH START"); any button returns to the title.
- **Player select**: the painted world map (stage 9) on BG1, the 4x2 icon grid as 32x32 sprites (one palette
  each), the highlighted baby's 96x96 portrait on BG2 (two half uploads through the NMI queue), yellow "1P"
  bracket and lit stage label, red "CPU" bracket once the opponent is drawn, then the match starts on the CPU
  baby's stage with its song.
- **Fight**: "ROUND n" / "FIGHT!" intro (inputs locked, clock stopped), K.O. / TIME UP / DRAW, "NAME WINS" with
  the winner's flex/pump pose, best of three, "WINS THE MATCH" screen back to the title.
- **Two players**: Start on pad 2 at the title joins; on the select screen pad 1 moves the yellow cursor, pad 2
  the red one, any button confirms each; the fight reads pad 2 for P2 instead of the CPU brain.
- **Supers** (A with a full meter): DIAPER DUMP, BINKY BLAST, BUBBLE BURP, TANTRUM TOSS and SPIT-UP SPRAY are
  projectiles (fired at frame 18 of the pose); BOTTLE BASH, RATTLE RAMPAGE (3 hits) and TEETHING CHOMP (hop)
  are rushes that test the rush box every 8 frames. **Crouch shots** (down + punch) for Brandon, Dawn, Isaac
  and Blue (one in flight at a time); the CPU throws them from range. Projectiles hit the body box, are
  blockable, and use the toy's 16x16 art centred in 32x32 cells.

## Design (what differs from the Studio cart)

- **Fighters are single 64x64 OBJs** (OBSEL size 5: 32x32 / 64x64), P1 tiles at OBJ columns 0..7, P2 at
  8..15, rows 0..7. A pose is 8 x 256-byte DMAs; only one upload (pose or portrait half) happens per NMI.
  Rows 8.. hold the 17 effect cells; the select icons borrow the fighter rows.
- **Mode 1**: BG1 = painted stage (4bpp, palettes 0,3..7, tiles at VRAM $0000, map at $4000), BG2 = logo /
  portrait (tiles at $4800.., map at $4400, blank tile 206), BG3 = text (2bpp font at $3000, map at $3C00,
  the whole 1792-byte shadow is DMA'd every frame; palettes 5 yellow, 6 red, 7 white).
- **Sky gradient**: HDMA channels 1 and 3 write the fixed colour (COLDATA) per 8-line step; colour 0 is black
  and the backdrop takes part in colour math, so the gradient shows wherever the painting is transparent.
  (Writing CGRAM by HDMA corrupts other palette entries in Mesen2, so the palette is never touched mid-frame.)
- **Scroll bands**: HDMA channel 2 drives BG1HOFS per scanline from a double-buffered WRAM table rebuilt every
  frame: water shimmer and tree sway (sine), cloud drift. Band definitions live in `tools/gen_screens.py` (AMB).
- **Shadows**: 32x32 sprites in OBJ palette 4 under each fighter; BG1 is on the sub screen and colour math
  (add, half) on OBJ palettes 4..7 makes them translucent.
- **Ambient**: birds/bats flocks, butterflies, cheering crowd babies, flickering candles, one palette colour
  "breathing" per stage (nearest colour to a target picked by the generator), window/candle flicker.
- **Hit sparks**: 3-frame burst on a hit, blue flash on a block, at the attack box centre.
- **Loads happen with NMI and HDMA off** (fade_out turns them off, fade_in back on): both move the PPU address
  registers under the loader's feet otherwise.
- **Engine** is the Lua engine line for line, 16-bit parallel arrays indexed by X = 0/2, 60 Hz logic.
- **Audio**: the SPC700 only executes commands; the main CPU plays the stage's song (nine songs, long-addressed
  from bank 29) on voices 0..5 and sound effects on 6..7 (hat on every attack, snare on hit, tom on block, crash
  on KO, pluck notes on the select screen).

## Verify

```
make
.venv/bin/python tools/emu_test.py .tools/run/t 150,300,700 --input 150-152:t --input 320-322:R --input 360-362:y
```
Writes `t_150.png` (title), `t_300.png` (select), `t_700.png` (fight) and prints the fighter state at each
frame. Mesen needs port 1 set to a SNES controller (Settings > Input) for injected input to register; its save
file lands in `~/Library/Application Support/Mesen2/Saves/`.

## Not done yet

- floor darkening toward the camera, breakable stage objects, voice samples
- audio only verified structurally (driver and samples land in SPC RAM, commands are acknowledged); nobody has listened yet
