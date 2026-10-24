# Baby Beatdown (ppu.toys Studio toy)

The game lives in the ppu.toys Studio toy "Baby Beatdown" (files main.lua, fight.lua,
flow.lua, tuning.lua, fx.lua, char1..8.lua; sources: font, stage; song: nursery).

`tools/` holds the Python generators for the sprite data:
- gen2.py  — draws the 8 fighters (12 poses, 32x32) procedurally and writes charN.lua
             (SNES 4bpp tile words as hex + per-character palette)
- gen3.py  — projectiles / sparks -> fx.lua (run with `python3 -I -c "import sys; sys.path.insert(0,'.'); exec(open('gen3.py').read())"` inside tools/)
- gen.py   — font + stage pixel grids (pasted into add_image_source) and the FX ascii art

After regenerating, paste the charN.lua / fx.lua contents into the Studio with write_file and
update CHAR_SUM / FX_SUM in main.lua (checksum = sum of (word + tile index) mod 65536).
