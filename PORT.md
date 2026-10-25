# Porting Baby Beatdown to a real SNES cartridge

Status 2026-10-24: `snes_check` rejects the toy with ~420 findings. None of them is a line-level fix.
They are symptoms of six design choices the Studio's Lua mode allows and the cart compiler cannot
represent. Fixing them means rebuilding the game as a second toy written in the cart dialect from the
start (docs topic `snes`), reusing the art, songs and tuning numbers, not the Lua.

## What the findings actually say

| Root cause | Findings | Where |
|---|---|---|
| **Layered overrides.** 30 files redefine `update_fighter`, `draw_sprites`, `apply_hit`, `stage_sky`, `render_pose`, ... as `local base_x = x; function x(...) base_x(...) ... end`. The cart needs one definition per name and cannot call a function held in a variable. | 57 "Duplicate function", ~45 "base_* is not a helper", 10 "Duplicate frame definition", ~40 "value-returning helpers need a return representation" | every layer file |
| **Record tables with string state and closures.** Fighters are `{state="idle", atk=nil, inp={}, ...}`; stages, specials, scenes and reactions are tables of closures (`fn`, `st.build`, `sc.paint`, `SONGS[n].play`). The cart has integer/boolean scalars, integer arrays and fixed-shape tables; no nil, no closures, no run-time string keys. | ~40 "no representation (nil, strings, closures)", 12 "Scalar fn has no fields", 10 "run-time string key", 25 "assignment changes scalar type", 25 "ipairs needs a table the program builds" | fight, stages, combat, specials, ambient, arts, react, bg*/face* |
| **Text and data as strings.** HUD text goes through `string.byte`; names are concatenated at run time; the nine painted stages and eight portraits are base64 / RLE strings decoded into tables at boot (8 KB longest literal, 226,013 table entries vs a 32,767 limit). | 9 `string.byte`, 20 run-time `..`, 6 `string.sub`/`len`, the `<strings>` table error | main, hud, flow, select, scenes, arcade, bg*, face* |
| **Procedural sprite rendering at run time.** `render_pose` rasterises capsules, ellipses and triangles into a 64x64 mask with fractional maths, then `encode` packs 4bpp tiles and `set_fighter_vram` uploads them whenever a pose changes. | fractional loop bounds, variable shifts, `min` with 3 args, "VRAM writes reachable from frame() need a budgeted VBlank queue", 3 ramps.lua fixed-point warnings | art, strikes, smooth, cps, faces, terrier |
| **Memory.** 242 KB of generated WRAM state against 24 KB; `PROJ`, `POSES[]`, `ANIM_POSE[]`, `BIRDS`, `ARCADE.order` each a 32-table pool of 4-8 KB. Nine songs plus seven `bank()` instruments overflow the 16.5 KB BRR region. | `<target>` WRAM and SPC errors, 8 `snes.wram` warnings | fight, art, strikes, arts, ambient, arcade, music |
| **Hardware API outside the subset.** `obj` aliased into locals (`local o = obj[i]`), `bg`/`frame`/`pad` shadowed, `hdma` rows computed from run-time values, palette writes in a loop inside a scanline callback, `sfx` with instruments held in a table. | 20 "Hardware field obj is not lowered", 3 reserved-name, 4 hdma/palette, 3 sfx | shadow, select_sprites, ambient, paint, painter, cps, scenes, react |

Each row is independent of the others, and each one on its own blocks export. A cart version cannot be
reached by editing the current files in place: the override chain is the toy's whole structure, and
flattening 30 layers of `update_fighter` by hand gives one 1,500-line function that still holds strings,
closures and nil.

## Shape of a cart version

What survives unchanged: the tuning numbers (STYLES.md), the move lists and hit boxes, the nine songs
(as `score{song=...}` whole-song loops, probably fewer of them), the font sheet, the painted stages and
portraits as PNGs (the `render/` output and `tools/`), the design.

What is rebuilt:

1. **One file per concern, one definition per function, no overrides.** `main.lua` holds `init()` and
   `frame(t, f)`; a flat `update_fighter(i)` with an integer state machine (`ST_IDLE = 0, ST_WALK = 1, ...`),
   fighters as parallel integer arrays (`FX[2], FY[2], FSTATE[2], FTIMER[2], ...`) with
   `---@snes range` on each, not records. Attacks as parallel constant arrays indexed by attack id.
2. **Pre-rendered sprites.** Run `render_pose` offline (a Python port of art.lua + cps/smooth/faces, or
   dump the Studio's VRAM per pose) into one sprite sheet PNG per character, placed with `dma()` at build
   time. The cart then only changes `obj[i].tile`; no VRAM writes from `frame()`. Sixty-odd poses per
   character at 64x64 4bpp is 8 KB each, so a 32 KB OBJ window holds two fighters with a budgeted
   `---@snes vblank` swap when the pair changes, or use a 32x32 + 32x64 body split to halve it.
3. **Stages and portraits as image sources**, not base64 strings: `add_image_source` the PNGs that
   `tools/scenes.py` and `tools/faces.py` already produce, `dma()` them to BG2/BG1 at constant addresses.
   This removes the `<strings>` error and most of the 242 KB of WRAM at once.
4. **Text as tile tables.** Fighter names, move names and "ROUND 1 / FIGHT / K.O." as constant integer
   arrays of glyph indices built by a small script; digits drawn from the integer (`DIGIT_TILE + n % 10`).
   `string.sub(s, i, i)` with a `GLYPH[...]` table is allowed but costs a compare per glyph per frame.
5. **Memory budget.** Two fighters, eight projectiles max (`---@snes cap`), eight ambient sprites,
   no per-frame tables. Target well under 24 KB; the fix-its name the rest once the other errors are gone.
6. **Audio budget.** One song resident at a time is not possible (the SPC program holds the whole score
   set), so pick the songs that fit 16.5 KB of BRR with the instruments, or shorten patterns.
7. **Scanline work baked.** Sky gradients as `---@snes hdma-bake` tables over a stage index; palette
   writes unrolled.
8. **Annotate as you go**: `---@snes fixed 10`, ranges on every persistent integer, `---@snes frames 2`
   for a 30 Hz target first; measure with `snes_check` after every file, not at the end.

## Order of work

1. Offline tools: pose sheet exporter (Python port of the renderer), glyph-table generator. Verify a
   sheet matches a Studio screenshot of the same pose.
2. New toy `baby-beatdown-cart`: font + two pose sheets + one stage via `dma()`, two fighters walking,
   `snes_check` clean, `export_rom`, run it in an emulator. This is the gate: if two fighters and a stage
   do not fit the frame budget nothing else matters.
3. Fight state machine, hits, blocks, HUD. Playtest with `press`.
4. Specials and projectiles, CPU player (`---@snes spread` if it searches).
5. Title, select, arcade ladder. Eight stages and portraits as sources, checking VRAM and ROM each time.
6. Audio last, within the BRR budget.

The Studio toy stays as is: it is the design reference and the demo, and the port's screenshots are
compared against it.

## Status 2026-10-25: the cart exists

`cart/` is the second toy, written in the cart dialect from the start and built on the SF2 Turbo formats
documented in `reference/SF2T_SNES_ARCHITECTURE.md`:

- `cart/data.lua` is generated by `tools/cartdata.py` from `cart/gamedata.json` (dumped from the Studio toy by
  `tools/dump_data.lua`): 31 moves as parallel arrays, 31 attack boxes and the hurt/push boxes as
  centre/half-extent records, 5 box sets of indices, 43 animation scripts as 4-byte keyframes
  `[hold][flags][cell][boxset]`, per-character move lists, walk/jump/gravity in 1/16 px.
- `cart/main.lua` is the engine: two fighters as parallel integer arrays, a 10-line keyframe interpreter,
  the `(dx+s) <= 2s` overlap test over four hurt slots, push-box separation, pad reading with press edges,
  the CPU brain, HUD through a 256-word VBlank window. `tools/run_cart.lua` runs it under plain Lua.
- Sprites: `tools/pose_sheets.py --core` turns the pose dumps into 64x64 OBJ sheets. **The OBJ region holds
  512 tiles = 8 cells of 64x64 for both fighters together**, so v1 shows 4 poses each (idle, walk, punch,
  kick); every other pose falls back onto those. SF2T-style per-frame streaming needs ROM-resident tile data
  fed through the 1,536-word VBlank window, which the compiler does not expose yet (arrays are WRAM).
- In the Studio (toy "baby-beatdown-cart", one merged `main.lua` because files run in creation order):
  Lua mode plays Brandon vs CPU Arlo with HUD; `snes_check` reports **0 errors**, one warning: the slowest
  path takes ~1.4 video frames (~43 updates/s). `tools/studio.py` drives the Studio over plain HTTP
  (the MCP endpoint is per Studio tab; `snes_check` over HTTP hits the 100 s gateway timeout, read the
  SNES panel instead).

Next: Export to ROM and run it in an emulator; reduce the slow path; a block/crouch/jump pose budget
(16x16 piece lists to trim empty tiles); stages as `bg` sources; audio.
