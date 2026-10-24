
27. bg9.lua, bg9a.lua, bg9b.lua, bg9c.lua, bg9m.lua   -- player-select map background (stage 9)
28. face1.lua .. face8.lua                             -- select-screen portraits (zero-run RLE + base64; see tools/faces.py)
29. select.lua                                         -- PLAYER SELECT screen; hooks flow.lua's prepare_portraits() and the title's demo timer

Transfer lesson: base64 with long "AAAA…" runs gets miscounted when relayed by hand — the face
data is zero-run RLE'd before base64 for that reason, and every blob is checksummed by its loader.
# Baby Beatdown — restoring the toy

Files run in creation order in the Studio and later files wrap/override earlier ones, so create them in THIS order
(write_file each one; main.lua first):

1. main.lua
2. fx.lua
3. fight.lua
4. flow.lua
5. tuning.lua
6. art.lua
7. stages.lua
8. hud.lua
9. music.lua
10. shadow.lua
11. styles.lua
12. combat.lua
13. screens.lua
14. specials.lua
15. select_sprites.lua
16. ambient.lua
17. layout_fix.lua
18. strikes.lua
19. paint.lua
20. painter.lua   (new scene painter; replaces the tiled stages at runtime)

Sources to re-add before it compiles:
- `font` sheet, 4bpp: grid + palette in sources/font.json (add_image_source kind=sheet bit_depth=4)
- `stage` sheet, 4bpp: sources/stage.json (only needed by stages.lua's dma; keep it)
- songs: sources/songs/*.json via write_song (names: nursery, bayou, backyard, rooftop, farm, pond, cave, garden, leaf)

ppuglobals.lua must have an empty apply_pokes() (a stray obj.char_base poke once broke sprites).
Known Studio Lua quirks: no tonumber/gsub/table lib/rnd; missing call arguments are NOT nil; vram cannot be read.
21. smooth.lua      (smoother strikes, lunge, breathing pose; re-keys pose caches to ci*256+pi)

Restored into the Studio on 2026-10-23 (toy was rebuilt from this folder after a browser refresh lost the tab).
Studio PPU findings that shaped the code:
- OBJ priority 1 is BEHIND BG2 here; ambient sprites must use prio 2.
- Half-add colour math barely darkens; translucent shadows use OBJ on the sub screen at prio 0 with BG2 subtract (shadow.lua).
- painter.lua's SKY/MID/FLR/PRP are local group ids; the sky gradient is the global SKY_KEYS (a local shadowing bug once broke it).
22. cps.lua         (CPS-1 look: coloured outlines, solid cel bands, big fists/feet, muted scenes, camera parallax + floor row scroll, black-and-tan Arlo)

23. bg1.lua .. bg8.lua  (painted stage headers: palettes + checksums; tiles are in bgNa/bgNb/bgNc.lua parts, the map in bgNm.lua)
    EVERY stage is now shipped split: bgN.lua (header, tiles = nil) + bgNa/bgNb/bgNc.lua (~5-8 KB each) + bgNm.lua.
    Write the 8 headers first, then the a/b/c/m parts. The loader also accepts a single `tiles = "..."` string.
24. scenes.lua      (base64 stage loader: BG2 char base 0, map at STAGE_MAP, palette slot 0 = floor rows, backdrop sky gradient,
                     camera parallax + floor row scroll; replaces painter's build_stage/stage_sky when BGDATA[stage] exists)
25. attract.lua     (title attract mode: CPU-vs-CPU demo after 5 s idle, smarter CPU, spark cap)

Regenerating stage art: tools/scenes.py paints render/stageN.png (venv with numpy+pillow), tools/quantize.py N writes the
bgN*.lua files. Base64 strings over ~25 KB get corrupted in transit through the agent, which is why tiles are split into
three ~8 KB parts; the Lua loader checksums every blob and names the bad one.
26. fontfix.lua     (rewrites the HUD font tiles into VRAM with fixed palette indices: 1 outline, 2 top, 3 bottom,
                     4 highlight, 5/6 bar reds, 7/8 meter blues, and sets cgram 17..24 every frame. The image importer
                     had renumbered the font colours so the outline came out yellow and text was unreadable on busy
                     stages; this file supersedes paint.lua's font_colors.)

2026-10-23: signing in to ppu.toys replaced the open toy with a fresh empty one; the game was restored a third time
from this folder (sources, 9 songs, then files 1-26 in this order). Parallel write_file calls in one response landed
in the order sent. One main.lua write arrived with a stray backtick prepended (parse error on line 1) - rewrite it.
30. arts.lua    -- martial-arts styles, new poses/moves, organic combos, bear hug, stances, idle cycle
31. react.lua   -- hit reactions, voices + final-blow sounds, projectile clash, win celebrations
32. faces.lua   -- expressions, sole lines + landing dust, the beach ball (see ../STYLES.md)
33. terrier.lua -- Arlo's terrier head: pricked tan-lined ears, crown tufts, bushy brows, scruffy beard (portrait: tools/faces.py arlo)
