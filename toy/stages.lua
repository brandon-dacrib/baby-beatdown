-- stages.lua: one procedurally built arena per character (tiles, palette, map, sky gradient)
-- palette roles: 1 outline, 2 wall dark, 3 wall mid, 4 wall light, 5 floor dark, 6 floor mid, 7 floor light,
-- 8 accent A, 9 accent B, 10 accent C, 11 white, 12 prop dark, 13 prop mid, 14 prop light, 15 extra
-- NOTE: this Lua does not nil missing arguments, so every helper is always called with all its parameters.
-- (painter.lua replaces build_stage/stage_sky at runtime; STAGES names/sky/pal are still referenced elsewhere)

local function T() local t = {} for i = 0, 63 do t[i] = 0 end return t end
local function set(t, x, y, k) if x >= 0 and x < 8 and y >= 0 and y < 8 then t[y * 8 + x] = k end end
local function fill(t, k) for i = 0, 63 do t[i] = k end return t end
local function hash(x, y, s) return (x * 7 + y * 13 + s * 31 + (x * y) * 3 + ((x + s) * (y + 1)) * 5) % 23 end
local function noise(t, k1, k2, pct, seed)
  for y = 0, 7 do for x = 0, 7 do set(t, x, y, (hash(x, y, seed) * 100 // 23 < pct) and k2 or k1) end end
  return t
end
local function hline(t, y, k) for x = 0, 7 do set(t, x, y, k) end return t end
local function planks(d, m, l)
  local t = fill(T(), m); hline(t, 0, l); hline(t, 7, d)
  for y = 1, 3 do set(t, 2, y, d) end
  for y = 4, 6 do set(t, 6, y, d) end
  return t
end
local function bricks(mortar, brick, light)
  local t = fill(T(), brick); hline(t, 3, mortar); hline(t, 7, mortar)
  for y = 0, 2 do set(t, 3, y, mortar) end
  for y = 4, 6 do set(t, 7, y, mortar) end
  for x = 0, 2 do set(t, x, 0, light) end
  for x = 4, 6 do set(t, x, 4, light) end
  return t
end
local function grass(d, m, l, seed)
  local t = noise(T(), m, d, 22, seed)
  for x = 0, 7 do if (x + seed) % 3 == 0 then set(t, x, 0, l); set(t, x, 1, l) end end
  return t
end
local function water(d, m, l, phase)
  local t = fill(T(), m)
  for x = 0, 7 do
    set(t, x, (1 + phase + ((x + 1) // 3) % 2) % 8, l)
    set(t, x, (5 + phase + (x // 3) % 2) % 8, d)
  end
  return t
end
local function soil(d, m, l, seed)
  local t = noise(T(), m, d, 18, seed); hline(t, 2, l); hline(t, 6, d)
  return t
end
local function rock(d, m, l, seed)
  local t = noise(T(), m, l, 14, seed)
  for y = 0, 7 do for x = 0, 7 do if (x * 3 + y * 5 + seed) % 11 == 0 or (x + y * 2 + seed) % 9 == 0 then set(t, x, y, d) end end end
  return t
end
local function stars(k, seed, k2)
  local t = T()
  for i = 0, 2 do set(t, (seed * 3 + i * 5) % 8, (seed * 5 + i * 3) % 8, k) end
  if k2 ~= nil then set(t, (seed * 7) % 8, (seed * 2 + 1) % 8, k2) end
  return t
end
local function pickets(d, l, top)
  local t = T()
  for y = 0, 7 do for x = 0, 7 do if x % 4 < 2 then set(t, x, y, (x % 4 == 0) and l or d) end end end
  if top then for x = 0, 7 do if x % 4 < 2 then set(t, x, 0, 0) end end; set(t, 0, 1, 0); set(t, 5, 1, 0) end
  return t
end
local function rail(d, l) local t = T(); hline(t, 3, l); hline(t, 4, d) return t end
local function bars(d, l)
  local t = T()
  for y = 0, 7 do set(t, 1, y, l); set(t, 2, y, d); set(t, 5, y, l); set(t, 6, y, d) end
  return t
end
local function reeds(d, m, top)
  local t = T()
  for y = 0, 7 do set(t, 2, y, m); set(t, 6, y, d) end
  if top then for y = 0, 3 do set(t, 1, y, 12); set(t, 2, y, 12); set(t, 3, y, 12) end; set(t, 2, 4, 12) end
  return t
end
local function leaf(d, m, l, seed)
  local t = fill(T(), m)
  for i = 0, 7 do set(t, i, (i + seed) % 8, l); set(t, (i + 4) % 8, (i + seed + 2) % 8, d) end
  return t
end
local function shingles(d, m, l)
  local t = fill(T(), m)
  for x = 0, 7 do set(t, x, 3, d); set(t, x, 7, d) end
  for y = 0, 2 do set(t, 3, y, d); set(t, 0, y, l) end
  for y = 4, 6 do set(t, 7, y, d); set(t, 4, y, l) end
  return t
end
local function windows(bg, lit, seed)
  local t = fill(T(), bg)
  set(t, (seed * 3) % 6 + 1, (seed * 5) % 6 + 1, lit); set(t, (seed * 5 + 3) % 7, (seed * 7 + 4) % 7, lit)
  return t
end
local function beads(a, b, c)
  local t = T()
  for x = 0, 7 do
    local y = 3 + ((x < 4) and (x // 2) or ((7 - x) // 2))
    local cols = { a, b, c }
    set(t, x, y, cols[x % 3 + 1])
    set(t, x, y - 1, 1)
  end
  return t
end
local function prop(fn)
  local out = {}
  for ty = 0, 1 do for tx = 0, 1 do
    local t = T()
    for y = 0, 7 do for x = 0, 7 do set(t, x, y, fn(tx * 8 + x, ty * 8 + y)) end end
    out[#out + 1] = t
  end end
  return out
end
local function inside(x, y, cx, cy, rx, ry) local ex, ey = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry return ex * ex + ey * ey <= 1 end
local function outlined(fn)
  return function(x, y)
    local v = fn(x, y)
    if v == 0 then return 0 end
    if fn(x - 1, y) == 0 or fn(x + 1, y) == 0 or fn(x, y - 1) == 0 or fn(x, y + 1) == 0 then return 1 end
    return v
  end
end
local P_DOGHOUSE = prop(outlined(function(x, y)
  if y < 7 then if abs(x - 7.5) <= y + 1.5 then return (y < 2) and 10 or 9 end return 0 end
  if x < 1 or x > 14 then return 0 end
  if abs(x - 7.5) < 2.5 and y >= 9 then return 12 end
  return (y == 7) and 14 or 13
end))
local P_MOON = prop(outlined(function(x, y)
  if not inside(x, y, 8, 8, 7, 7) then return 0 end
  if inside(x, y, 5, 6, 1.6, 1.6) or inside(x, y, 10, 10, 1.4, 1.4) or inside(x, y, 10, 4, 1, 1) then return 13 end
  return 14
end))
local P_HONEYPOT = prop(outlined(function(x, y)
  if y >= 3 and y <= 5 and x >= 3 and x <= 12 then return 12 end
  if y > 5 and inside(x, y, 8, 11, 6.5, 5) then return (y < 9) and 14 or 13 end
  if y == 2 and x >= 6 and x <= 9 then return 14 end
  return 0
end))
local P_CARROT = prop(outlined(function(x, y)
  if y < 5 then if (x == 6 or x == 9 or (x == 7 and y > 1) or (x == 8 and y > 1)) then return 9 end return 0 end
  local half = 4 - (y - 5) * 0.35
  if abs(x - 7.5) <= half then return (x < 7) and 14 or 13 end
  return 0
end))
local P_FLOWER = prop(outlined(function(x, y)
  if inside(x, y, 8, 7, 2.6, 2.6) then return 10 end
  if inside(x, y, 8, 3, 2.6, 2.6) or inside(x, y, 8, 11, 2.6, 2.6) or inside(x, y, 4, 7, 2.6, 2.6) or inside(x, y, 12, 7, 2.6, 2.6) then return 15 end
  if y >= 12 and x >= 7 and x <= 8 then return 9 end
  return 0
end))
local P_HAY = prop(outlined(function(x, y)
  if y < 3 or y > 13 then return 0 end
  if not inside(x, y, 8, 8, 7.5, 5.5) then return 0 end
  if (x + y) % 5 == 0 then return 13 end
  return 14
end))
local P_CYPRESS = prop(outlined(function(x, y)
  if y >= 10 then return (x >= 6 and x <= 9) and 12 or 0 end
  if inside(x, y, 8, 6, 7.5, 6) then return ((x * 3 + y) % 7 == 0) and 4 or 3 end
  return 0
end))
local P_CLOUD = prop(function(x, y)
  if inside(x, y, 5, 10, 5, 3.5) or inside(x, y, 10, 9, 5.5, 4.5) or inside(x, y, 8, 6, 4, 3.5) then return 11 end
  return 0
end)
local P_DEW = prop(outlined(function(x, y)
  if inside(x, y, 8, 8, 5, 5) then return inside(x, y, 6, 6, 1.5, 1.5) and 11 or 14 end
  return 0
end))
local P_BARNX = prop(function(x, y)
  if x == 0 or x == 15 or y == 0 or y == 15 or x == y or x == 15 - y then return 11 end
  return 3
end)
local P_PUDDLE = prop(function(x, y)
  if y >= 5 and y <= 10 and inside(x, y, 8, 8, 7.5, 3) then return ((x + y) % 6 == 0) and 14 or 13 end
  return 0
end)

STAGES = {}
STAGES[1] = { name = "BAYOU PORCH", sky = { {255,150,90}, {120,60,130} },
  pal = { {30,20,30}, {30,60,40}, {50,100,60}, {90,150,80}, {80,50,30}, {130,85,45}, {175,125,70}, {150,60,200}, {80,200,90}, {255,210,60}, {255,245,220}, {40,30,20}, {60,120,120}, {90,170,160}, {20,70,80} },
  tiles = function()
    local t = {}
    t[1] = water(15, 13, 14, 0); t[2] = water(15, 13, 14, 3)
    t[3] = planks(5, 6, 7); t[4] = planks(5, 6, 7); hline(t[4], 0, 11)
    t[5] = beads(8, 9, 10); t[6] = rail(5, 7)
    for i, p in ipairs(P_CYPRESS) do t[6 + i] = p end
    t[11] = bars(5, 7)
    return t
  end,
  build = function(put, rect)
    rect(0, 10, 31, 10, 5)
    for c = 1, 29, 7 do put(c, 11, 7); put(c + 1, 11, 8); put(c, 12, 9); put(c + 1, 12, 10) end
    for c = 0, 31 do put(c, 13, 11) end
    for r = 14, 19 do for c = 0, 31 do put(c, r, ((c + r) % 2 == 0) and 1 or 2) end end
    rect(0, 20, 31, 20, 4); rect(0, 21, 31, 27, 3)
  end }
STAGES[2] = { name = "BACKYARD", sky = { {110,170,255}, {200,235,255} },
  pal = { {40,30,30}, {60,120,40}, {90,170,60}, {140,210,90}, {80,60,30}, {120,95,50}, {170,140,80}, {230,230,235}, {180,180,190}, {200,60,50}, {255,255,255}, {60,40,30}, {150,100,60}, {200,150,90}, {230,100,80} },
  tiles = function()
    local t = {}
    t[1] = pickets(9, 8, true); t[2] = pickets(9, 8, false); t[3] = rail(9, 8)
    t[4] = grass(2, 3, 4, 1); t[5] = grass(2, 3, 4, 4); t[6] = soil(5, 6, 7, 2)
    for i, p in ipairs(P_DOGHOUSE) do t[6 + i] = p end
    for i, p in ipairs(P_CLOUD) do t[10 + i] = p end
    return t
  end,
  build = function(put, rect)
    for _, c in ipairs({ 2, 12, 22 }) do put(c, 3, 11); put(c + 1, 3, 12); put(c, 4, 13); put(c + 1, 4, 14) end
    rect(0, 15, 31, 15, 1); rect(0, 16, 31, 19, 2); rect(0, 17, 31, 17, 3)
    put(25, 18, 7); put(26, 18, 8); put(25, 19, 9); put(26, 19, 10)
    rect(0, 20, 31, 21, 4); rect(0, 22, 31, 22, 5); rect(0, 23, 31, 27, 6)
  end }
STAGES[3] = { name = "ROOFTOP", sky = { {10,10,50}, {80,40,110} },
  pal = { {20,16,36}, {60,50,80}, {90,80,110}, {130,120,150}, {50,45,60}, {80,75,95}, {120,115,135}, {255,230,120}, {40,30,60}, {200,80,120}, {255,255,255}, {90,40,40}, {150,70,60}, {255,250,200}, {230,220,120} },
  tiles = function()
    local t = {}
    t[1] = stars(11, 1, nil); t[2] = stars(14, 2, 11); t[3] = stars(11, 5, nil)
    t[4] = windows(9, 8, 1); t[5] = windows(9, 8, 2); t[6] = fill(T(), 9)
    t[7] = bricks(1, 13, 12); t[8] = shingles(5, 6, 7); t[9] = shingles(5, 6, 7); hline(t[9], 0, 4)
    for i, p in ipairs(P_MOON) do t[9 + i] = p end
    return t
  end,
  build = function(put, rect)
    for r = 0, 12 do for c = 0, 31 do if (c * 5 + r * 3) % 7 == 0 then put(c, r, 1 + (c + r) % 3) end end end
    put(24, 3, 10); put(25, 3, 11); put(24, 4, 12); put(25, 4, 13)
    for c = 0, 31 do
      local h = 2 + (c * 7 % 5)
      for r = 20 - h, 19 do put(c, r, (r == 20 - h) and 6 or (4 + (c + r) % 2)) end
    end
    rect(4, 11, 6, 19, 7); rect(0, 20, 31, 20, 9); rect(0, 21, 31, 27, 8)
  end }
STAGES[4] = { name = "MUD FARM", sky = { {170,210,250}, {235,240,230} },
  pal = { {40,20,20}, {120,30,30}, {170,50,45}, {210,90,80}, {70,45,25}, {110,75,40}, {150,110,60}, {240,200,80}, {255,230,130}, {255,255,255}, {255,255,255}, {120,150,200}, {240,200,80}, {255,230,130}, {60,40,25} },
  tiles = function()
    local t = {}
    t[1] = planks(2, 3, 4); t[2] = fill(T(), 11); t[3] = soil(5, 6, 7, 3); t[4] = soil(5, 6, 7, 6)
    for i, p in ipairs(P_HAY) do t[4 + i] = p end
    for i, p in ipairs(P_BARNX) do t[8 + i] = p end
    for i, p in ipairs(P_PUDDLE) do t[12 + i] = p end
    return t
  end,
  build = function(put, rect)
    rect(1, 9, 13, 19, 1); rect(1, 9, 13, 9, 2); rect(1, 19, 13, 19, 2)
    put(6, 12, 9); put(7, 12, 10); put(6, 13, 11); put(7, 13, 12)
    put(20, 18, 5); put(21, 18, 6); put(20, 19, 7); put(21, 19, 8)
    put(27, 18, 5); put(28, 18, 6); put(27, 19, 7); put(28, 19, 8)
    rect(0, 20, 31, 27, 3)
    for c = 0, 31, 3 do put(c, 22 + c % 5, 4) end
    put(10, 23, 13); put(11, 23, 14); put(10, 24, 15); put(11, 24, 16)
  end }
STAGES[5] = { name = "DUCK POND", sky = { {120,190,255}, {220,245,255} },
  pal = { {20,40,50}, {40,110,60}, {70,160,80}, {120,210,110}, {30,80,140}, {60,130,200}, {120,190,240}, {90,60,30}, {240,220,120}, {255,255,255}, {255,255,255}, {110,70,40}, {60,140,90}, {150,220,140}, {40,100,160} },
  tiles = function()
    local t = {}
    t[1] = reeds(2, 3, true); t[2] = reeds(2, 3, false)
    t[3] = water(5, 6, 7, 0); t[4] = water(5, 6, 7, 2); t[5] = water(5, 6, 7, 5)
    t[6] = fill(T(), 3); for x = 0, 7 do set(t[6], x, 0, 4); set(t[6], x, 7, 2) end; set(t[6], 3, 3, 2); set(t[6], 4, 4, 2)
    for i, p in ipairs(P_CLOUD) do t[6 + i] = p end
    return t
  end,
  build = function(put, rect)
    for _, c in ipairs({ 5, 18, 27 }) do put(c, 2, 7); put(c + 1, 2, 8); put(c, 3, 9); put(c + 1, 3, 10) end
    for c = 0, 31, 2 do if c % 6 ~= 4 then put(c, 14, 1); for r = 15, 19 do put(c, r, 2) end end end
    rect(0, 20, 31, 21, 6)
    for r = 22, 27 do for c = 0, 31 do put(c, r, 3 + (c // 2 + r) % 3) end end
  end }
STAGES[6] = { name = "HONEY CAVE", sky = { {30,20,20}, {60,40,30} },
  pal = { {20,14,12}, {60,45,40}, {95,75,65}, {135,110,95}, {55,45,40}, {85,70,60}, {120,100,85}, {240,170,40}, {255,210,90}, {255,240,160}, {255,255,255}, {120,70,30}, {220,150,40}, {255,200,80}, {40,30,28} },
  tiles = function()
    local t = {}
    t[1] = rock(2, 3, 4, 1); t[2] = rock(2, 3, 4, 5); t[3] = rock(2, 3, 4, 9)
    t[4] = fill(T(), 8); for x = 0, 7 do set(t[4], x, 7, 9); if x % 3 == 0 then set(t[4], x, 6, 8) end end
    t[5] = T(); set(t[5], 3, 0, 8); set(t[5], 3, 1, 8); set(t[5], 3, 2, 8); set(t[5], 2, 3, 9); set(t[5], 3, 3, 9); set(t[5], 4, 3, 9); set(t[5], 3, 4, 9)
    t[6] = rock(5, 6, 7, 2); t[7] = rock(5, 6, 7, 7); hline(t[7], 0, 7)
    for i, p in ipairs(P_HONEYPOT) do t[7 + i] = p end
    return t
  end,
  build = function(put, rect)
    for r = 0, 19 do for c = 0, 31 do put(c, r, 1 + (c * 3 + r * 5) % 3) end end
    for c = 3, 29, 9 do put(c, 2, 4); put(c, 3, 5) end
    put(3, 18, 8); put(4, 18, 9); put(3, 19, 10); put(4, 19, 11)
    put(26, 18, 8); put(27, 18, 9); put(26, 19, 10); put(27, 19, 11)
    rect(0, 20, 31, 20, 7); rect(0, 21, 31, 27, 6)
  end }
STAGES[7] = { name = "CARROT GARDEN", sky = { {255,190,210}, {255,240,220} },
  pal = { {40,30,30}, {60,120,50}, {90,170,70}, {150,220,110}, {80,55,35}, {120,85,50}, {170,130,80}, {240,240,245}, {80,160,60}, {255,220,80}, {255,255,255}, {190,190,200}, {240,130,30}, {255,170,60}, {255,120,180} },
  tiles = function()
    local t = {}
    t[1] = pickets(12, 8, true); t[2] = pickets(12, 8, false); t[3] = rail(12, 8)
    t[4] = grass(2, 3, 4, 2); t[5] = soil(5, 6, 7, 1); t[6] = soil(5, 6, 7, 4)
    for i, p in ipairs(P_CARROT) do t[6 + i] = p end
    for i, p in ipairs(P_FLOWER) do t[10 + i] = p end
    return t
  end,
  build = function(put, rect)
    rect(0, 14, 31, 14, 1); rect(0, 15, 31, 17, 2); rect(0, 16, 31, 16, 3)
    for c = 2, 29, 5 do put(c, 18, 7); put(c + 1, 18, 8); put(c, 19, 9); put(c + 1, 19, 10) end
    for _, c in ipairs({ 6, 24 }) do put(c, 18, 11); put(c + 1, 18, 12); put(c, 19, 13); put(c + 1, 19, 14) end
    rect(0, 20, 31, 20, 4); rect(0, 21, 31, 27, 5)
    for c = 0, 31, 2 do put(c, 23, 6); put(c + 1, 26, 6) end
  end }
STAGES[8] = { name = "BIG LEAF", sky = { {200,240,120}, {120,200,90} },
  pal = { {20,50,20}, {40,110,50}, {70,160,70}, {120,210,100}, {40,100,45}, {70,150,65}, {110,200,95}, {255,120,170}, {60,140,60}, {255,220,80}, {255,255,255}, {60,110,140}, {120,190,230}, {190,240,255}, {255,120,170} },
  tiles = function()
    local t = {}
    t[1] = leaf(2, 3, 4, 0); t[2] = leaf(2, 3, 4, 3); t[3] = leaf(2, 3, 4, 6)
    t[4] = fill(T(), 6); hline(t[4], 0, 7); t[5] = leaf(5, 6, 7, 1); t[6] = leaf(5, 6, 7, 5)
    for i, p in ipairs(P_FLOWER) do t[6 + i] = p end
    for i, p in ipairs(P_DEW) do t[10 + i] = p end
    return t
  end,
  build = function(put, rect)
    for r = 8, 19 do for c = 0, 31 do put(c, r, 1 + (c + r * 2) % 3) end end
    for _, c in ipairs({ 3, 15, 26 }) do put(c, 18, 7); put(c + 1, 18, 8); put(c, 19, 9); put(c + 1, 19, 10) end
    put(9, 11, 11); put(10, 11, 12); put(9, 12, 13); put(10, 12, 14)
    put(21, 5, 11); put(22, 5, 12); put(21, 6, 13); put(22, 6, 14)
    rect(0, 20, 31, 20, 4)
    for r = 21, 27 do for c = 0, 31 do put(c, r, 5 + (c + r) % 2) end end
  end }

local function write_tile(index, t)
  local base = STAGE_CHAR + index * 16
  for row = 0, 7 do
    local p0, p1, p2, p3 = 0, 0, 0, 0
    for col = 0, 7 do
      local v = t[row * 8 + col]
      if v ~= 0 then
        local bit = 1 << (7 - col)
        if v & 1 ~= 0 then p0 = p0 | bit end
        if v & 2 ~= 0 then p1 = p1 | bit end
        if v & 4 ~= 0 then p2 = p2 | bit end
        if v & 8 ~= 0 then p3 = p3 | bit end
      end
    end
    vram[base + row] = p0 | (p1 << 8)
    vram[base + 8 + row] = p2 | (p3 << 8)
  end
end

SKY = { {0, 0}, {160, 0} }
CURRENT_STAGE = 0
function build_stage(ci)
  local st = STAGES[ci]
  CURRENT_STAGE = ci
  for i = 1, 15 do cgram[i] = rgb(st.pal[i][1], st.pal[i][2], st.pal[i][3]) end
  for i = 0, 511 do vram[STAGE_CHAR + i] = 0 end
  local tiles = st.tiles()
  for i = 1, 31 do if tiles[i] ~= nil then write_tile(i, tiles[i]) end end
  for i = 0, 1023 do vram[STAGE_MAP + i] = 0 end
  local function put(c, r, tile) vram[STAGE_MAP + r * 32 + c] = tile end
  local function rect(c0, r0, c1, r1, tile) for r = r0, r1 do for c = c0, c1 do put(c, r, tile) end end end
  st.build(put, rect)
  SKY = { { 0, rgb(st.sky[1][1], st.sky[1][2], st.sky[1][3]) }, { 168, rgb(st.sky[2][1], st.sky[2][2], st.sky[2][3]) } }
end

function stage_sky()
  local keys = SKY
  hdma(0, 175, function(y) cgram[0] = ramp_color(keys, y) end)
end

local base_draw_sprites = draw_sprites
function draw_sprites()
  base_draw_sprites()
  stage_sky()
end
