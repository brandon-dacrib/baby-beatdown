-- shadow.lua: character-shaped, translucent ground shadows.
-- The pose silhouette is flattened to a quarter height into the TOP 16 rows of a 64x64 cell per fighter; the sprite
-- sits low so the tall cell only overlaps the fighters near their feet (34-sliver scanline budget).
-- Translucency: the shadow sprite is drawn at OBJ priority 0, which sits BEHIND BG2 on the main screen, and OBJ is
-- also put on the SUB screen. Colour math is enabled for BG2 in subtract mode, so wherever the shadow lies under
-- the floor the visible pixel becomes floor - shadow colour: a real darkening of whatever is painted there.
-- (Half-add with the Studio's blend barely darkens anything, which is why the shadows used to be invisible.)
SHADOW_TILES = { 128, 136 }
SHADOW_PAL = 4
SHADOW_CACHE = {}
local shadow_vram = { -1, -1 }

local function setup_math()
  screen.sub.bg2 = false
  screen.sub.obj = true
  CGWSEL = 0x02
  CGADSUB = 0x82
  COLDATA = 0
  cgram[128 + SHADOW_PAL * 16 + 1] = rgb(96, 86, 116)
  cgram[128 + SHADOW_PAL * 16 + 3] = rgb(56, 50, 76)
end

local function shadow_words(ci, pi)
  local key = ci * 256 + pi
  if SHADOW_CACHE[key] ~= nil then return SHADOW_CACHE[key] end
  local c = render_pose(ci, pi)
  local s = {}
  for i = 0, 4095 do s[i] = 0 end
  for y = 0, 63 do
    for x = 0, 63 do
      if c[y * 64 + x] ~= 0 then s[(y // 4) * 64 + x] = 3 end
    end
  end
  for y = 0, 15 do
    for x = 1, 62 do
      if s[y * 64 + x] == 3 and s[y * 64 + x - 1] ~= 0 and s[y * 64 + x + 1] ~= 0 and (y == 0 or s[(y - 1) * 64 + x] ~= 0) then
        s[y * 64 + x] = 1
      end
    end
  end
  local words = {}
  local n = 0
  for ty = 0, 7 do
    for tx = 0, 7 do
      for row = 0, 7 do
        local p0, p1 = 0, 0
        local base = (ty * 8 + row) * 64 + tx * 8
        for col = 0, 7 do
          local v = s[base + col]
          if v ~= 0 then
            local bit = 1 << (7 - col)
            p0 = p0 | bit
            if v == 3 then p1 = p1 | bit end
          end
        end
        words[n + row] = p0 | (p1 << 8)
        words[n + 8 + row] = 0
      end
      n = n + 16
    end
  end
  SHADOW_CACHE[key] = words
  return words
end

local function set_shadow_vram(slot, ci, pi)
  local key = ci * 256 + pi
  if shadow_vram[slot] == key then return end
  shadow_vram[slot] = key
  local w = shadow_words(ci, pi)
  local n = 0
  for ty = 0, 7 do
    for tx = 0, 7 do
      local addr = OBJ_BASE + (SHADOW_TILES[slot] + ty * 16 + tx) * 16
      for i = 0, 15 do vram[addr + i] = w[n + i] end
      n = n + 16
    end
  end
end

local function draw_shadow(f, n)
  set_shadow_vram(f.slot, f.char, f.pose)
  local o = obj[n]
  o.tile = SHADOW_TILES[f.slot]; o.pal = SHADOW_PAL; o.large = true
  local lift = (FLOOR_Y - f.y) // 6
  o.x = floor(f.x) + lift; o.y = FLOOR_Y + 56
  o.prio = 0; o.flip_x = (f.face == -1); o.flip_y = false; o.on = true
end

local base_draw_sprites = draw_sprites
function draw_sprites()
  base_draw_sprites()
  if ROUND.state ~= "select" then
    setup_math()
    if P1 ~= nil then draw_shadow(P1, 14) end
    if P2 ~= nil then draw_shadow(P2, 15) end
  end
end
