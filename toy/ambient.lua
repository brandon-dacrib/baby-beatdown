-- ambient.lua: living backgrounds (clouds, sway, twinkle, flicker, water shimmer, birds, butterflies, crowds) and hit-freeze.
-- Ambient sprites use OBJ priority 2: priority 1 sits behind BG2 in this PPU, which hid the crowd and birds.
local tiles_ready = false
local function inside(x, y, cx, cy, rx, ry) local ex, ey = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry return ex * ex + ey * ey <= 1 end
local function cell_pixels(cell, fn)
  for ty = 0, 1 do
    for tx = 0, 1 do
      local tile = fx_tile(cell) + ty * 16 + tx
      local addr = OBJ_BASE + tile * 16
      for row = 0, 7 do
        local p0, p1, p2, p3 = 0, 0, 0, 0
        for col = 0, 7 do
          local v = fn(tx * 8 + col, ty * 8 + row)
          if v ~= 0 then
            local bit = 1 << (7 - col)
            if v & 1 ~= 0 then p0 = p0 | bit end
            if v & 2 ~= 0 then p1 = p1 | bit end
            if v & 4 ~= 0 then p2 = p2 | bit end
            if v & 8 ~= 0 then p3 = p3 | bit end
          end
        end
        vram[addr + row] = p0 | (p1 << 8)
        vram[addr + 8 + row] = p2 | (p3 << 8)
      end
    end
  end
end
local function outlined(fn)
  return function(x, y)
    local v = fn(x, y)
    if v == 0 then return 0 end
    if fn(x - 1, y) == 0 or fn(x + 1, y) == 0 or fn(x, y - 1) == 0 or fn(x, y + 1) == 0 then return 1 end
    return v
  end
end
local function crowd_baby(bob, skin, shirt)
  return outlined(function(x, y)
    local hy = 5 - bob
    if inside(x, y, 8, hy, 4.6, 4.3) then
      if (x == 6 or x == 9) and (y == hy or y == hy - 1) then return 1 end
      if y == hy + 2 and x >= 7 and x <= 8 then return 8 end
      return skin
    end
    if y >= hy + 4 and y <= 15 and abs(x - 7.5) <= 3.5 then
      if y >= 13 then return 5 end
      return shirt
    end
    if y >= hy + 5 and y <= hy + 8 and (abs(x - 3.5) <= 0.6 or abs(x - 11.5) <= 0.6) then return skin end
    return 0
  end)
end
local function bird(up)
  return function(x, y)
    local d = up and -1 or 1
    for i = 0, 5 do
      local wy = 8 + d * (i // 2)
      if (x == 7 - i or x == 8 + i) and y == wy then return 1 end
    end
    if (x == 7 or x == 8) and y == 8 then return 1 end
    return 0
  end
end
local function candle(frame)
  return outlined(function(x, y)
    if y >= 8 and y <= 15 and x >= 6 and x <= 9 then return 5 end
    local fh = (frame == 0) and 5 or 4
    local fx = (frame == 0) and 7.5 or 8
    if y >= 8 - fh and y < 8 and abs(x + 0.5 - fx) <= (y - (8 - fh)) * 0.5 + 0.6 then
      return (y > 5) and 11 or 15
    end
    return 0
  end)
end
local function butterfly(open)
  return outlined(function(x, y)
    if x == 7 or x == 8 then if y >= 4 and y <= 11 then return 1 end end
    local w = open and 3.2 or 1.6
    local lw = inside(x, y, 7 - w, 6, w, 2.6) or inside(x, y, 7 - w * 0.8, 9.5, w * 0.8, 2.0)
    local rw = inside(x, y, 9 + w, 6, w, 2.6) or inside(x, y, 9 + w * 0.8, 9.5, w * 0.8, 2.0)
    if lw or rw then
      if (x % 4 == 1 and y % 3 == 1) then return 1 end
      return (y < 8) and 15 or 11
    end
    return 0
  end)
end
local function upload_extra_tiles()
  cell_pixels(20, crowd_baby(0, 11, 9)); cell_pixels(21, crowd_baby(1, 11, 9))
  cell_pixels(28, crowd_baby(0, 7, 12)); cell_pixels(29, crowd_baby(1, 7, 12))
  cell_pixels(30, crowd_baby(0, 8, 10)); cell_pixels(31, crowd_baby(1, 8, 10))
  cell_pixels(22, bird(true)); cell_pixels(23, bird(false))
  cell_pixels(24, candle(0)); cell_pixels(25, candle(1))
  cell_pixels(26, butterfly(true)); cell_pixels(27, butterfly(false))
  tiles_ready = true
end
local CROWD_CELLS = { 20, 28, 30 }

AMBIENT = {
  { birds = true, candles = { {44, 94}, {196, 94} }, sway = { 88, 104, 1, 40 }, cycle = { 14, 90, 170, 160, 30, 2.0 } },
  { birds = true, drift = { 0, 60, 6 }, crowd = { {56, 104}, {96, 104}, {148, 104}, {192, 104} }, butterflies = 1 },
  { cycle = { 11, 255, 255, 255, 90, 3.0 }, flicker = { 8, 255, 230, 120 }, bats = true },
  { birds = true, crowd = { {168, 128}, {196, 128}, {222, 128} }, cycle = { 14, 170, 200, 230, 20, 1.5 } },
  { birds = true, drift = { 0, 40, 4 }, sway = { 112, 160, 2, 24 }, cycle = { 7, 120, 190, 240, 40, 2.5 } },
  { candles = { {28, 56}, {220, 56}, {124, 40} }, cycle = { 9, 255, 210, 90, 50, 4.0 }, flicker = { 8, 240, 170, 40 } },
  { birds = true, butterflies = 2, crowd = { {40, 96}, {120, 96}, {200, 96} }, sway = { 136, 160, 1, 30 } },
  { butterflies = 2, sway = { 64, 160, 2, 60 }, cycle = { 14, 190, 240, 255, 60, 3.0 } },
}

BIRDS = {}
BUTTERS = {}
local function reset_ambient()
  BIRDS = {}
  BUTTERS = {}
  local a = AMBIENT[CURRENT_STAGE]
  if a ~= nil and a.butterflies ~= nil then
    for i = 1, a.butterflies do BUTTERS[i] = { x = 40 + i * 70, y = 80 + i * 20, t = i * 37 } end
  end
end

local last_stage = -1
local function update_ambient(t, f)
  local a = AMBIENT[CURRENT_STAGE]
  if CURRENT_STAGE ~= last_stage then reset_ambient(); last_stage = CURRENT_STAGE end
  for i = 20, 31 do obj[i].on = false end
  if a == nil then return end
  local n = 20
  if a.birds == true or a.bats == true then
    if #BIRDS == 0 and rnd() < 0.004 then
      local dir = (rnd() < 0.5) and 1 or -1
      local y0 = 20 + rnd() * 50
      for i = 1, 3 do
        BIRDS[i] = { x = (dir == 1) and (-20 - i * 18) or (276 + i * 18), y = y0 + (i % 2) * 8, vx = dir * (0.8 + rnd() * 0.4), ph = i * 7 }
      end
    end
    local keep = {}
    for _, b in ipairs(BIRDS) do
      b.x = b.x + b.vx
      if b.x > -24 and b.x < 280 then
        keep[#keep + 1] = b
        local o = obj[n]; n = n + 1
        o.tile = fx_tile(22 + ((f + b.ph) // 8) % 2); o.pal = 2; o.large = false
        o.x = floor(b.x); o.y = floor(b.y + sin((f + b.ph) / 10) * 2); o.prio = 2; o.flip_x = b.vx < 0; o.on = true
      end
    end
    BIRDS = keep
  end
  for _, bf in ipairs(BUTTERS) do
    bf.t = bf.t + 1
    bf.x = bf.x + sin(bf.t / 40) * 0.8
    bf.y = bf.y + cos(bf.t / 23) * 0.5
    if bf.x < 8 then bf.x = 8 elseif bf.x > 232 then bf.x = 232 end
    if bf.y < 50 then bf.y = 50 elseif bf.y > 150 then bf.y = 150 end
    local o = obj[n]; n = n + 1
    o.tile = fx_tile(26 + (bf.t // 6) % 2); o.pal = 2; o.large = false
    o.x = floor(bf.x); o.y = floor(bf.y); o.prio = 2; o.flip_x = sin(bf.t / 40) < 0; o.on = true
  end
  if a.crowd ~= nil then
    for i, c in ipairs(a.crowd) do
      local o = obj[n]; n = n + 1
      local bob = ((f // 12 + i * 3) % 4 == 0) and 1 or 0
      o.tile = fx_tile(CROWD_CELLS[(i - 1) % 3 + 1] + bob); o.pal = 2; o.large = false
      o.x = c[1]; o.y = c[2]; o.prio = 2; o.flip_x = (i % 2 == 0); o.on = true
    end
  end
  if a.candles ~= nil then
    for i, c in ipairs(a.candles) do
      local o = obj[n]; n = n + 1
      o.tile = fx_tile(24 + ((f // 5 + i * 2) % 3 == 0 and 1 or 0)); o.pal = 2; o.large = false
      o.x = c[1]; o.y = c[2]; o.prio = 2; o.flip_x = false; o.on = true
    end
  end
  if a.cycle ~= nil then
    local cy = a.cycle
    local k = (sin(t * cy[6]) + 1) * 0.5 * cy[5]
    cgram[cy[1]] = rgb(max(0, min(255, floor(cy[2] - cy[5] + k))), max(0, min(255, floor(cy[3] - cy[5] + k))), max(0, min(255, floor(cy[4] - cy[5] + k))))
  end
  if a.flicker ~= nil then
    local fl = a.flicker
    local d = (rnd() < 0.08) and 70 or 0
    cgram[fl[1]] = rgb(max(0, fl[2] - d), max(0, fl[3] - d), max(0, fl[4] - d))
  end
end

function stage_sky()
  local keys = SKY
  local a = AMBIENT[CURRENT_STAGE]
  local sw = nil
  local dr = nil
  if a ~= nil then sw = a.sway; dr = a.drift end
  local tt = AMB_T or 0
  hdma(0, 175, function(y)
    cgram[0] = ramp_color(keys, y)
    local sx = 0
    if dr ~= nil and y >= dr[1] and y <= dr[2] then sx = floor(tt * dr[3]) % 256 end
    if sw ~= nil and y >= sw[1] and y <= sw[2] then sx = sx + sin(tt * 1.5 + y / sw[4]) * sw[3] end
    bg[2].scroll.x = sx
  end)
end

HITSTOP = 0
local base_apply_hit = apply_hit
function apply_hit(att, def, dmg, stun, low, high, hx, hy, pushback)
  local landed = base_apply_hit(att, def, dmg, stun, low, high, hx, hy, pushback)
  if landed then HITSTOP = 5 else HITSTOP = 2 end
  return landed
end
local base_update_fighter = update_fighter
function update_fighter(f, opp, allow_input)
  if HITSTOP > 0 then
    if f == P2 then HITSTOP = HITSTOP - 1 end
    if f.flash > 0 then f.flash = f.flash - 1 end
    return
  end
  base_update_fighter(f, opp, allow_input)
end

local base_draw_sprites = draw_sprites
function draw_sprites()
  if not tiles_ready then upload_extra_tiles() end
  base_draw_sprites()
  if ROUND.state ~= "select" then update_ambient(AMB_T or 0, AMB_F or 0) end
end

local base_frame = frame
function frame(t, f)
  AMB_T = t; AMB_F = f
  base_frame(t, f)
end
