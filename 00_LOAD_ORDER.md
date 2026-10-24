# Baby Beatdown — restoring the toy into the ppu.toys Studio

Files run in creation order in the Studio and later files wrap/override earlier ones, so create them in THIS
order with `write_file` (main.lua first). Every file in `toy/` is the authoritative copy of what runs in the
Studio; the Studio and this folder must stay identical.

## 0. Before any Lua file compiles

- Sources (`add_image_source`, kind=sheet, bit_depth=4): `font` from `toy/sources/font.json`,
  `stage` from `toy/sources/stage.json` (only stages.lua's dma needs it; keep it).
- Songs (`write_song(name, json)`) from `toy/sources/songs/*.json`:
  nursery, bayou, backyard, rooftop, farm, pond, cave, garden, leaf.
- `ppuglobals.lua` (the Studio's own file) must have an empty `apply_pokes()`; a stray obj.char_base poke once
  broke sprites.

## 1. File order

| #  | file | what it adds |
|----|------|--------------|
| 1  | main.lua | registers, VRAM layout, character palettes table, frame() |
| 2  | fx.lua | projectile / spark tiles |
| 3  | fight.lua | fighter physics, hit boxes, states |
| 4  | flow.lua | title, intro, round, matchend flow; portraits |
| 5  | tuning.lua | numbers |
| 6  | art.lua | procedural fighter renderer (POSES, CHARS, species bodies) |
| 7  | stages.lua | original tiled stages |
| 8  | hud.lua | SF2-style HUD |
| 9  | music.lua | per-stage song switching |
| 10 | shadow.lua | translucent character-shaped shadows (OBJ on sub screen, BG2 subtract) |
| 11 | styles.lua | first per-character stances |
| 12 | combat.lua | knockback, combos, barrel, thump/smack sounds, air attacks |
| 13 | screens.lua | real title screen + first character select |
| 14 | specials.lua | supers and projectiles |
| 15 | select_sprites.lua | select-screen sprite icons |
| 16 | ambient.lua | wind, candles, birds, spectators (OBJ prio 2) |
| 17 | layout_fix.lua | layout corrections |
| 18 | strikes.lua | multiple punches/kicks, extended strikes, dynamic logo colour |
| 19 | paint.lua | painterly pass, depth shading |
| 20 | smooth.lua | smoother strike anims, lunge, breathing; pose caches keyed ci*256+pi |
| 21 | painter.lua | scene painter (replaces tiled stages at runtime) |
| 22 | cps.lua | CPS-1 look: coloured outlines, cel bands, species hands/feet, parallax, Arlo colours |
| 23 | bg1.lua .. bg8.lua | painted stage headers (palettes + checksums, tiles = nil) |
| 23b | bg1a/b/c/m .. bg8a/b/c/m | tile parts (a/b/c, ~5-8 KB each) and the map (m). Headers first, then parts |
| 24 | scenes.lua | base64 stage loader (BG2 char base 0, map at STAGE_MAP, palette 0 = floor rows, sky gradient) |
| 25 | attract.lua | title attract mode: CPU-vs-CPU demo after 5 s idle, smarter CPU |
| 26 | fontfix.lua | rewrites HUD font tiles with fixed palette indices (readable text on busy stages) |
| 27 | bg9.lua, bg9a/b/c/m | player-select map background (stage 9, BG palettes 3-7) |
| 28 | face1.lua .. face8.lua | select-screen portraits (zero-run RLE + base64; tools/faces.py) |
| 29 | select.lua | PLAYER SELECT screen; also runs in demo mode |
| 30 | arts.lua | martial-arts styles, new poses/moves, organic combos, bear hug, stances, idle cycle |
| 31 | react.lua | hit reactions, voices + final-blow sounds, projectile clash, win celebrations |
| 32 | faces.lua | expressions, sole lines + landing dust, the beach ball |
| 33 | terrier.lua | Arlo's terrier head |
| 34 | arcade.lua | 7-fight arcade ladder + per-character ending sequence (ENDING table) |

After the last file: `check` for 40 s (50 times out) must report no Lua errors and no sprite overflow
beyond the 0-6 frame baseline.

## 2. Lessons that shaped the code

- Studio Lua: no tonumber/gsub/find/table lib; `rnd()` is math.random; vram cannot be read back;
  **missing call arguments are NOT nil**; runtime errors are not shown by press/screenshot (use `check`).
- `press` only advances `frames`; the Studio pauses after a press; `screenshot(t)` and `check` replay from t=0.
- OBJ priority 1 is BEHIND BG2 here; ambient sprites use prio 2. Half-add colour math barely darkens, so
  shadows are OBJ on the sub screen with BG2 subtract (shadow.lua).
- Feet scanlines (rows ~165-176) carry 32 of 34 sprite slivers: dust/stomp sparks sit at FLOOR_Y+72, the ball
  rests at FLOOR_Y+38, or `check` reports overflow.
- Pose ids must stay below 256 (caches keyed ci*256+pi). Used: 0-17 base, 20-46 strikes, 48-77 arts,
  81-88 IDLE2, 90-193 arts anims, 194-195 react, 200-236 smooth.
- Base64 with long "AAAA…" runs gets miscounted when relayed by hand: binary blobs are zero-run RLE'd, split
  into <=1.5 KB parts decoded separately, and checksummed by their loader (which names the bad blob).
  Stage tiles over ~25 KB are split into three parts for the same reason.
- Parallel write_file calls in one response land in the order sent. One main.lua write once arrived with a
  stray backtick prepended (parse error line 1): rewrite it.
- Melodic samples cap near B5; drums (bank 0x0800) go higher. Voice phrases use voice 4; `koff(v)` stops loops.

## 3. Regenerating art

- `tools/scenes.py` paints `render/stageN.png` (venv with numpy + pillow), `tools/quantize.py N` writes bgN*.lua.
- `tools/select_bg.py` paints and quantizes the select background (stage 9).
- `tools/faces.py` paints the 8 portraits and writes face1..8.lua.
- `legacy/` holds the first-generation sprite generators (gen*.py, char1..8.lua); nothing uses them now.

## 4. History

- 2026-10-23: a browser refresh lost the tab; restored from this folder. Signing in to ppu.toys replaced the open
  toy with a fresh empty one; restored again (sources, 9 songs, then the files in this order).
- 2026-10-24: rooftop song rewritten hip hop (92 BPM, swing); arcade ladder + endings; repo pushed to GitHub.
