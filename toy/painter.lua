-- painter.lua: paints each arena as a full-screen picture (256x224) into unique BG2 tiles (char base 0x0000, up to
-- 1024 tiles) using four 15-colour palettes: SKY (BG pal 3), MID (pal 4), FLOOR (pal 0), PROP (pal 5).
-- Each 8x8 cell takes the palette of the group most of its pixels belong to; stray pixels from another group are
-- mapped to the nearest colour of the chosen palette. Runs last and replaces build_stage / stage_sky.
-- (every helper is called with all its arguments: this Lua does not nil missing ones)
-- NOTE: SKY/MID/FLR/PRP below are LOCAL group ids; the sky gradient lives in the global SKY_KEYS.

local W, H = 256, 224
local PIX = {}
local PALS = {}
local PAL_OF = { [1] = 3, [2] = 4, [3] = 0, [4] = 5 }
local SKY, MID, FLR, PRP = 1, 2, 3, 4

local function lerp3(a, b, t) return { floor(a[1] + (b[1] - a[1]) * t + 0.5), floor(a[2] + (b[2] - a[2]) * t + 0.5), floor(a[3] + (b[3] - a[3]) * t + 0.5) } end
local function ramp(dst, at, c0, c1, n)
  for i = 0, n - 1 do dst[at + i] = lerp3(c0, c1, (n == 1) and 0 or i / (n - 1)) end
end
local function mul(c, k) return { floor(c[1] * k), floor(c[2] * k), floor(c[3] * k) } end

local BAYER = { {0, 2}, {3, 1} }
local function dith(x, y) return (BAYER[y % 2 + 1][x % 2 + 1] + 0.5) / 4 - 0.5 end

local function setp(x, y, g, i)
  x = floor(x); y = floor(y)
  if x < 0 or x >= W or y < 0 or y >= H then return end
  if i < 1 then i = 1 elseif i > 15 then i = 15 end
  PIX[y * W + x] = g * 16 + i
end

local function vgrad(x0, x1, y0, y1, g, i0, i1)
  for y = y0, y1 do
    local t = (y1 == y0) and 0 or (y - y0) / (y1 - y0)
    local v = i0 + (i1 - i0) * t
    for x = x0, x1 do setp(x, y, g, floor(v + dith(x, y) * 0.9 + 0.5)) end
  end
end
local function rectf(x0, y0, x1, y1, g, i) for y = y0, y1 do for x = x0, x1 do setp(x, y, g, i) end end end
local function blob(cx, cy, rx, ry, g, i, shade)
  for y = floor(cy - ry), floor(cy + ry) + 1 do
    for x = floor(cx - rx), floor(cx + rx) + 1 do
      local nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
      local d = nx * nx + ny * ny
      if d <= 1 then
        local v = i
        if shade then
          local l = -(nx * 0.7 + ny * 0.7)
          if l > 0.45 - d * 0.2 then v = i + 1 elseif l < -0.35 or d > 0.8 then v = i - 1 end
        end
        setp(x, y, g, v)
      end
    end
  end
end
local function hills(y1, yb, amp, period, phase, g, i_top, i_bot)
  for x = 0, W - 1 do
    local a = x / W * 6.2832
    local h = yb - amp * (0.6 * sin(a * period + phase) + 0.3 * sin(a * period * 2.3 + phase * 1.7) + 0.1 * sin(a * period * 5.1))
    local top = floor(h)
    for y = top, y1 do
      local t = (y1 == top) and 0 or (y - top) / (y1 - top)
      setp(x, y, g, floor(i_top + (i_bot - i_top) * t + dith(x, y) * 0.8 + 0.5))
    end
  end
end
local function cloud(cx, cy, w, g, i_light, i_shade)
  blob(cx - w * 0.3, cy + 2, w * 0.38, w * 0.2, g, i_shade, false)
  blob(cx + w * 0.3, cy + 2, w * 0.36, w * 0.18, g, i_shade, false)
  blob(cx, cy, w * 0.5, w * 0.24, g, i_shade, false)
  blob(cx - w * 0.28, cy - 1, w * 0.3, w * 0.16, g, i_light, false)
  blob(cx + w * 0.1, cy - 4, w * 0.3, w * 0.18, g, i_light, false)
end
local function glow(cx, cy, r, g, i_in, i_out)
  for y = floor(cy - r), floor(cy + r) do
    for x = floor(cx - r), floor(cx + r) do
      local d = ((x + 0.5 - cx) * (x + 0.5 - cx) + (y + 0.5 - cy) * (y + 0.5 - cy)) / (r * r)
      if d <= 1 then
        local v = i_out + (i_in - i_out) * (1 - d) + dith(x, y) * 0.9
        setp(x, y, g, floor(v + 0.5))
      end
    end
  end
end
local function tree(x, yb, h, g, i_fol, i_wood)
  rectf(x - 2, yb - h * 0.45, x + 2, yb, g, i_wood)
  rectf(x - 1, yb - h * 0.45, x - 1, yb, g, i_wood + 1)
  blob(x, yb - h * 0.62, h * 0.32, h * 0.3, g, i_fol + 1, true)
  blob(x - h * 0.2, yb - h * 0.52, h * 0.24, h * 0.22, g, i_fol + 1, true)
  blob(x + h * 0.2, yb - h * 0.55, h * 0.24, h * 0.22, g, i_fol + 1, true)
  blob(x, yb - h * 0.8, h * 0.22, h * 0.2, g, i_fol + 2, true)
end
local function line(x0, y0, x1, y1, g, i)
  local n = max(abs(x1 - x0), abs(y1 - y0))
  if n == 0 then setp(x0, y0, g, i) return end
  for k = 0, n do setp(floor(x0 + (x1 - x0) * k / n + 0.5), floor(y0 + (y1 - y0) * k / n + 0.5), g, i) end
end
local function floor_plane(y0, g, i_dark, i_light, lines)
  for y = y0, H - 1 do
    local t = (y - y0) / (H - 1 - y0)
    local v = i_light - (i_light - i_dark) * t
    for x = 0, W - 1 do setp(x, y, g, floor(v + dith(x, y) * 0.8 + 0.5)) end
  end
  if lines then
    for k = -6, 6 do line(128 + k * 10, y0, 128 + k * 60, H - 1, g, i_dark) end
    for k = 1, 5 do
      local yy = y0 + floor((k * k) * (H - 1 - y0) / 30)
      for x = 0, W - 1 do if x % 3 ~= 0 then setp(x, yy, g, i_dark) end end
    end
  end
end
local function water(y0, y1, g, i_dark, i_light, t_shift)
  for y = y0, y1 do
    local t = (y - y0) / max(1, y1 - y0)
    local base = i_light - (i_light - i_dark) * t
    for x = 0, W - 1 do
      local s = sin(x / 9 + y * 0.9 + t_shift) + 0.5 * sin(x / 4 - y * 1.7)
      local v = base + ((s > 1.1) and 1.5 or 0) - ((s < -1.1) and 1 or 0)
      setp(x, y, g, floor(v + dith(x, y) * 0.7 + 0.5))
    end
  end
end

-- SKY: 1-6 sky ramp, 7-9 cloud shade->light, 10-12 far hills dark->light, 13 sun core, 14 sun glow, 15 star
-- MID: 1 outline, 2-5 foliage, 6-8 wood, 9-12 wall, 13-14 accent, 15 light
-- FLOOR: 1-6 ground dark->light, 7-11 water dark->light, 12 dark line, 13-14 highlight, 15 glint
-- PROP: 1 outline, 2-4 A, 5-7 B, 8-10 C, 11-13 D, 14 white, 15 yellow
local function make_palettes(p)
  local s, m, f, pr = {}, {}, {}, {}
  ramp(s, 1, p.sky_top, p.sky_hor, 6); ramp(s, 7, p.cloud_shade, p.cloud_light, 3); ramp(s, 10, p.hill_dark, p.hill_light, 3)
  s[13] = p.sun_core; s[14] = p.sun_glow; s[15] = p.star
  m[1] = p.outline; ramp(m, 2, p.fol_dark, p.fol_light, 4); ramp(m, 6, p.wood_dark, p.wood_light, 3); ramp(m, 9, p.wall_dark, p.wall_light, 4)
  m[13] = p.acc_a; m[14] = p.acc_b; m[15] = p.light
  ramp(f, 1, p.ground_dark, p.ground_light, 6); ramp(f, 7, p.water_dark, p.water_light, 5)
  f[12] = p.floor_line; f[13] = p.hi_a; f[14] = p.hi_b; f[15] = p.glint
  pr[1] = p.outline; ramp(pr, 2, mul(p.prop_a, 0.6), p.prop_a, 3); ramp(pr, 5, mul(p.prop_b, 0.6), p.prop_b, 3)
  ramp(pr, 8, mul(p.prop_c, 0.6), p.prop_c, 3); ramp(pr, 11, mul(p.prop_d, 0.6), p.prop_d, 3); pr[14] = { 255, 255, 255 }; pr[15] = { 255, 224, 80 }
  return { s, m, f, pr }
end

SCENES = {}
SCENES[1] = { name = "BAYOU PORCH", floor_y = 160,
  p = { sky_top = {255,120,70}, sky_hor = {255,200,130}, cloud_shade = {230,120,120}, cloud_light = {255,210,180},
        hill_dark = {40,70,70}, hill_light = {110,130,110}, sun_core = {255,250,200}, sun_glow = {255,190,110}, star = {255,255,230},
        outline = {20,18,24}, fol_dark = {20,50,40}, fol_light = {90,150,90}, wood_dark = {50,30,20}, wood_light = {130,90,60},
        wall_dark = {60,50,50}, wall_light = {150,140,130}, acc_a = {150,60,200}, acc_b = {90,210,100}, light = {255,230,150},
        ground_dark = {70,40,22}, ground_light = {190,140,80}, water_dark = {20,60,70}, water_light = {120,190,170},
        floor_line = {40,22,12}, hi_a = {255,220,140}, hi_b = {255,250,220}, glint = {255,245,200},
        prop_a = {150,60,200}, prop_b = {90,210,100}, prop_c = {255,210,60}, prop_d = {200,120,60} },
  paint = function()
    vgrad(0, W - 1, 0, 118, SKY, 1, 6)
    glow(196, 92, 34, SKY, 13, 14)
    hills(118, 100, 10, 2, 0.5, SKY, 11, 10)
    hills(118, 108, 14, 3, 2.1, SKY, 10, 10)
    for i = 0, 6 do tree(12 + i * 40, 118, 42 + (i % 3) * 8, MID, 2, 6) end
    for i = 0, 6 do for k = 0, 3 do line(16 + i * 40 - 6 + k * 4, 92, 16 + i * 40 - 6 + k * 4 + 1, 108 + (k % 2) * 6, MID, 3) end end
    water(119, 159, FLR, 7, 11, 0)
    for x = 0, W - 1 do if (x // 2) % 5 ~= 0 then setp(x, 130 + floor(sin(x / 7) * 1.5), FLR, 15) end end
    for y = 119, 159 do for x = 0, W - 1 do if abs(x - 196) < 10 and (x + y) % 3 == 0 then setp(x, y, FLR, 13) end end end
    floor_plane(160, FLR, 1, 5, true)
    rectf(0, 160, W - 1, 161, FLR, 6); rectf(0, 162, W - 1, 162, FLR, 12)
    for i = 0, 31 do rectf(i * 8 + 7, 163, i * 8 + 7, H - 1, FLR, 12) end
    rectf(0, 108, W - 1, 110, MID, 7); rectf(0, 111, W - 1, 111, MID, 6)
    for x = 0, W - 1, 4 do local c = ((x // 4) % 3 == 0) and 13 or (((x // 4) % 3 == 1) and 14 or 15); setp(x, 100 + floor(sin(x / 20) * 3), MID, c); setp(x + 1, 100 + floor(sin(x / 20) * 3), MID, c) end
  end }
SCENES[2] = { name = "BACKYARD", floor_y = 160,
  p = { sky_top = {80,140,235}, sky_hor = {200,230,250}, cloud_shade = {190,200,225}, cloud_light = {255,255,255},
        hill_dark = {90,150,90}, hill_light = {160,210,130}, sun_core = {255,255,230}, sun_glow = {255,245,180}, star = {255,255,255},
        outline = {30,30,30}, fol_dark = {30,90,40}, fol_light = {130,210,110}, wood_dark = {70,45,25}, wood_light = {170,120,70},
        wall_dark = {190,190,195}, wall_light = {255,255,255}, acc_a = {200,60,50}, acc_b = {240,150,60}, light = {255,255,230},
        ground_dark = {40,100,45}, ground_light = {140,215,110}, water_dark = {80,60,40}, water_light = {170,130,80},
        floor_line = {35,80,40}, hi_a = {230,240,200}, hi_b = {255,255,255}, glint = {255,250,200},
        prop_a = {200,60,50}, prop_b = {170,120,70}, prop_c = {240,150,60}, prop_d = {255,255,255} },
  paint = function()
    vgrad(0, W - 1, 0, 120, SKY, 1, 6)
    glow(40, 28, 22, SKY, 13, 14)
    cloud(60, 40, 44, SKY, 9, 7); cloud(170, 26, 56, SKY, 9, 7); cloud(236, 52, 40, SKY, 9, 7)
    hills(120, 104, 12, 1.5, 1.0, SKY, 12, 10)
    hills(120, 112, 10, 2.5, 3.0, SKY, 11, 10)
    tree(34, 122, 70, MID, 2, 6); tree(228, 122, 54, MID, 2, 6)
    for x = 0, W - 1 do
      if x % 12 < 7 then
        local top = 122 + ((x % 12 == 0 or x % 12 == 6) and 3 or 0)
        for y = top, 158 do setp(x, y, MID, (x % 12 < 2 or x % 12 == 6) and 9 or 11) end
      end
    end
    rectf(0, 132, W - 1, 134, MID, 10); rectf(0, 148, W - 1, 150, MID, 10)
    rectf(198, 134, 232, 158, MID, 7); rectf(200, 136, 230, 137, MID, 8)
    for i = 0, 12 do line(215 - 20 + i * 3, 134 - floor(abs(i - 6) * 0.2), 215 - 20 + i * 3, 122 + abs(i - 6) * 2, MID, 13) end
    blob(215, 150, 6, 8, MID, 1, false)
    floor_plane(160, FLR, 1, 5, false)
    for i = 0, 40 do local x, y = (i * 53) % 256, 164 + (i * 29) % 56; setp(x, y, FLR, 14); setp(x + 1, y, FLR, 14); setp(x, y + 1, FLR, 15) end
    for x = 0, W - 1 do if (x * 7) % 11 < 3 then setp(x, 160, FLR, 6); setp(x, 161, FLR, 6) end end
  end }
SCENES[3] = { name = "ROOFTOP", floor_y = 160,
  p = { sky_top = {8,10,40}, sky_hor = {90,50,120}, cloud_shade = {60,40,90}, cloud_light = {120,100,160},
        hill_dark = {30,28,60}, hill_light = {70,60,110}, sun_core = {255,250,210}, sun_glow = {180,170,120}, star = {255,255,255},
        outline = {15,12,30}, fol_dark = {30,25,60}, fol_light = {80,70,120}, wood_dark = {70,30,30}, wood_light = {160,80,70},
        wall_dark = {40,36,70}, wall_light = {110,100,150}, acc_a = {255,230,120}, acc_b = {255,120,80}, light = {255,250,200},
        ground_dark = {40,36,52}, ground_light = {120,114,140}, water_dark = {20,20,40}, water_light = {80,80,110},
        floor_line = {25,22,36}, hi_a = {200,200,230}, hi_b = {255,255,255}, glint = {255,255,255},
        prop_a = {160,80,70}, prop_b = {110,100,150}, prop_c = {255,230,120}, prop_d = {120,120,140} },
  paint = function()
    vgrad(0, W - 1, 0, 130, SKY, 1, 6)
    for i = 0, 70 do local x, y = (i * 97) % 256, (i * 53) % 110; setp(x, y, SKY, 15); if i % 5 == 0 then setp(x + 1, y, SKY, 15); setp(x, y + 1, SKY, 15) end end
    glow(200, 34, 26, SKY, 14, 6); blob(200, 34, 13, 13, SKY, 13, false); blob(195, 30, 3, 3, SKY, 14, false); blob(204, 38, 2, 2, SKY, 14, false)
    for i = 0, 15 do
      local x0 = i * 17 + (i % 3) * 4
      local h = 30 + (i * 37) % 40
      rectf(x0, 130 - h, x0 + 14, 130, SKY, 10 + (i % 2))
      for wy = 134 - h, 126, 7 do for wx = x0 + 2, x0 + 11, 5 do if (wx * 3 + wy) % 5 < 2 then setp(wx, wy, SKY, 13); setp(wx + 1, wy, SKY, 13) end end end
    end
    for i = 0, 7 do
      local x0 = i * 34 + 6
      local h = 20 + (i * 23) % 30
      rectf(x0, 160 - h, x0 + 24, 160, MID, 9 + (i % 2))
      rectf(x0, 160 - h, x0 + 24, 160 - h, MID, 12)
      for wy = 160 - h + 4, 156, 6 do for wx = x0 + 3, x0 + 20, 5 do if (wx + wy * 3) % 4 == 0 then setp(wx, wy, MID, 13); setp(wx + 1, wy, MID, 13); setp(wx, wy + 1, MID, 14) end end end
    end
    rectf(28, 100, 46, 160, MID, 6); rectf(26, 96, 48, 100, MID, 7)
    for y = 102, 158, 5 do for x = 29, 45 do if (x + y) % 7 == 0 then setp(x, y, MID, 1) end end end
    floor_plane(160, FLR, 1, 4, true)
    for y = 160, H - 1, 8 do for x = 0, W - 1 do if (x + (y // 8) * 4) % 16 == 0 then setp(x, y, FLR, 12) end end rectf(0, y, W - 1, y, FLR, 12) end
    rectf(0, 160, W - 1, 160, FLR, 6)
  end }
SCENES[4] = { name = "MUD FARM", floor_y = 160,
  p = { sky_top = {140,190,240}, sky_hor = {245,235,210}, cloud_shade = {210,200,190}, cloud_light = {255,255,250},
        hill_dark = {120,150,70}, hill_light = {210,210,120}, sun_core = {255,255,240}, sun_glow = {255,240,190}, star = {255,255,255},
        outline = {40,24,20}, fol_dark = {60,100,40}, fol_light = {170,200,90}, wood_dark = {90,55,30}, wood_light = {190,140,80},
        wall_dark = {110,25,25}, wall_light = {215,80,70}, acc_a = {255,255,255}, acc_b = {240,200,80}, light = {255,250,230},
        ground_dark = {55,35,20}, ground_light = {160,115,65}, water_dark = {100,130,170}, water_light = {200,220,235},
        floor_line = {40,25,15}, hi_a = {200,170,110}, hi_b = {235,215,170}, glint = {255,255,255},
        prop_a = {240,200,80}, prop_b = {215,80,70}, prop_c = {190,140,80}, prop_d = {120,150,200} },
  paint = function()
    vgrad(0, W - 1, 0, 118, SKY, 1, 6)
    glow(216, 26, 24, SKY, 13, 14)
    cloud(70, 30, 50, SKY, 9, 7); cloud(160, 48, 36, SKY, 9, 7)
    hills(118, 100, 8, 1.2, 0.3, SKY, 12, 11)
    for y = 104, 118 do for x = 0, W - 1 do if ((x + y * 3) // 6) % 2 == 0 then setp(x, y, SKY, 10) end end end
    rectf(8, 72, 112, 158, MID, 10); rectf(8, 72, 112, 74, MID, 12)
    for y = 76, 158, 6 do rectf(8, y, 112, y, MID, 9) end
    for i = 0, 56 do line(60 - i, 72, 60 - i, 50 + i // 2, MID, 6); line(60 + i, 72, 60 + i, 50 + i // 2, MID, 7) end
    rectf(40, 104, 80, 158, MID, 9); line(40, 104, 80, 158, MID, 13); line(80, 104, 40, 158, MID, 13); rectf(40, 104, 80, 105, MID, 13); rectf(40, 104, 41, 158, MID, 13); rectf(79, 104, 80, 158, MID, 13)
    line(176, 60, 176, 118, MID, 6); for k = 0, 3 do local a = k * 1.5708 + 0.4; line(176, 70, 176 + floor(cos(a) * 24), 70 + floor(sin(a) * 24), MID, 7) end
    tree(222, 120, 60, MID, 2, 6)
    blob(150, 150, 16, 9, MID, 13, true); blob(184, 152, 14, 8, MID, 13, true)
    floor_plane(160, FLR, 1, 5, true)
    for i = 0, 3 do blob(40 + i * 60, 190 + (i % 2) * 14, 18, 4, FLR, 10, false); blob(40 + i * 60 - 4, 189 + (i % 2) * 14, 8, 1.5, FLR, 11, false) end
  end }
SCENES[5] = { name = "DUCK POND", floor_y = 160,
  p = { sky_top = {90,160,240}, sky_hor = {215,240,250}, cloud_shade = {200,215,235}, cloud_light = {255,255,255},
        hill_dark = {50,110,70}, hill_light = {130,190,120}, sun_core = {255,255,240}, sun_glow = {255,250,200}, star = {255,255,255},
        outline = {20,40,40}, fol_dark = {30,90,50}, fol_light = {120,210,110}, wood_dark = {90,60,30}, wood_light = {190,150,80},
        wall_dark = {60,120,60}, wall_light = {150,220,130}, acc_a = {120,70,40}, acc_b = {240,220,120}, light = {255,255,230},
        ground_dark = {40,110,50}, ground_light = {130,210,110}, water_dark = {25,70,140}, water_light = {150,210,245},
        floor_line = {30,80,40}, hi_a = {220,245,255}, hi_b = {255,255,255}, glint = {255,255,255},
        prop_a = {120,70,40}, prop_b = {150,220,130}, prop_c = {240,220,120}, prop_d = {255,255,255} },
  paint = function()
    vgrad(0, W - 1, 0, 128, SKY, 1, 6)
    cloud(40, 36, 46, SKY, 9, 7); cloud(150, 24, 60, SKY, 9, 7); cloud(226, 44, 36, SKY, 9, 7)
    hills(128, 110, 10, 2, 0.8, SKY, 12, 10)
    for i = 0, 11 do tree(10 + i * 24, 130, 26 + (i % 4) * 5, MID, 2, 6) end
    for i = 0, 20 do
      local x = 4 + i * 12 + (i % 3) * 3
      local top = 118 + (i % 4) * 5
      line(x, top, x + 1, 160, MID, (i % 2 == 0) and 4 or 3)
      rectf(x - 1, top - 8, x + 2, top, MID, 13)
    end
    rectf(0, 158, W - 1, 160, FLR, 5)
    water(161, H - 1, FLR, 7, 11, 1.2)
    for i = 0, 7 do blob(24 + i * 32, 178 + (i % 3) * 14, 13, 5, FLR, 4, false); blob(26 + i * 32, 177 + (i % 3) * 14, 7, 2.5, FLR, 5, false); setp(24 + i * 32 + 8, 178 + (i % 3) * 14, FLR, 9) end
    for x = 0, W - 1 do if (x // 3) % 4 ~= 0 then setp(x, 166 + floor(sin(x / 11) * 1.5), FLR, 15) end end
  end }
SCENES[6] = { name = "HONEY CAVE", floor_y = 160,
  p = { sky_top = {18,12,14}, sky_hor = {70,48,40}, cloud_shade = {60,40,36}, cloud_light = {110,80,66}, hill_dark = {40,28,26}, hill_light = {90,66,56},
        sun_core = {255,235,160}, sun_glow = {200,130,50}, star = {255,220,120},
        outline = {12,8,8}, fol_dark = {60,44,40}, fol_light = {150,120,100}, wood_dark = {120,70,20}, wood_light = {255,200,80},
        wall_dark = {50,36,34}, wall_light = {130,100,90}, acc_a = {255,180,60}, acc_b = {255,230,150}, light = {255,250,220},
        ground_dark = {40,30,30}, ground_light = {120,96,88}, water_dark = {170,110,20}, water_light = {255,220,110},
        floor_line = {26,18,18}, hi_a = {255,210,90}, hi_b = {255,240,180}, glint = {255,255,230},
        prop_a = {255,180,60}, prop_b = {130,100,90}, prop_c = {255,230,150}, prop_d = {90,60,50} },
  paint = function()
    vgrad(0, W - 1, 0, 160, SKY, 2, 5)
    for i = 0, 60 do local x, y = (i * 61) % 256, (i * 41) % 160; blob(x, y, 10 + (i % 4) * 4, 7 + (i % 3) * 3, MID, 10 + (i % 3), true) end
    for i = 0, 11 do local x = i * 22 + 6; local h = 14 + (i * 7) % 20; for k = 0, h do line(x - (h - k) // 4, k, x + (h - k) // 4, k, MID, 9) end end
    glow(28, 60, 30, SKY, 13, 3); glow(220, 60, 30, SKY, 13, 3); glow(124, 44, 24, SKY, 13, 3)
    for i = 0, 5 do local x = 30 + i * 40; line(x, 0, x, 24 + (i % 3) * 16, FLR, 9); blob(x, 26 + (i % 3) * 16, 3, 4, FLR, 10, true) end
    floor_plane(160, FLR, 1, 4, true)
    blob(70, 200, 30, 6, FLR, 9, false); blob(64, 199, 14, 2.5, FLR, 11, false)
    blob(190, 186, 22, 5, FLR, 9, false); blob(186, 185, 10, 2, FLR, 11, false)
  end }
SCENES[7] = { name = "CARROT GARDEN", floor_y = 160,
  p = { sky_top = {255,170,190}, sky_hor = {255,240,215}, cloud_shade = {240,190,200}, cloud_light = {255,255,255},
        hill_dark = {120,160,90}, hill_light = {200,225,140}, sun_core = {255,255,235}, sun_glow = {255,220,180}, star = {255,255,255},
        outline = {40,30,30}, fol_dark = {40,110,50}, fol_light = {150,225,110}, wood_dark = {130,120,120}, wood_light = {245,245,250},
        wall_dark = {190,190,200}, wall_light = {255,255,255}, acc_a = {255,120,180}, acc_b = {255,220,80}, light = {255,255,240},
        ground_dark = {70,45,28}, ground_light = {175,130,80}, water_dark = {200,110,30}, water_light = {255,180,70},
        floor_line = {50,32,20}, hi_a = {90,180,70}, hi_b = {160,230,110}, glint = {255,255,255},
        prop_a = {255,120,180}, prop_b = {240,130,30}, prop_c = {90,180,70}, prop_d = {255,255,255} },
  paint = function()
    vgrad(0, W - 1, 0, 118, SKY, 1, 6)
    glow(60, 40, 30, SKY, 13, 14)
    cloud(150, 30, 50, SKY, 9, 7); cloud(230, 60, 34, SKY, 9, 7)
    hills(118, 98, 12, 1.4, 2.0, SKY, 12, 10)
    hills(118, 110, 8, 2.2, 0.4, SKY, 11, 10)
    tree(240, 120, 56, MID, 2, 6)
    for x = 0, W - 1 do
      if x % 10 < 6 then
        local top = 124 + ((x % 10 == 0 or x % 10 == 5) and 3 or 0)
        for y = top, 158 do setp(x, y, MID, (x % 10 < 2 or x % 10 == 5) and 9 or 11) end
      end
    end
    rectf(0, 136, W - 1, 138, MID, 10); rectf(0, 150, W - 1, 152, MID, 10)
    for i = 0, 4 do local x = 24 + i * 50; blob(x, 118, 7, 7, MID, 13, true); blob(x, 118, 3, 3, MID, 14, false); line(x, 125, x, 158, MID, 3) end
    floor_plane(160, FLR, 1, 5, true)
    for r = 0, 3 do
      local yy = 170 + r * 14
      for x = 0, W - 1 do if (x // 2) % 2 == 0 then setp(x, yy, FLR, 1) end end
      for i = 0, 9 do local cx = 10 + i * 26 + r * 6; blob(cx, yy + 4, 3, 5, FLR, 10, true); setp(cx, yy - 3, FLR, 13); setp(cx - 1, yy - 2, FLR, 14); setp(cx + 1, yy - 2, FLR, 14); setp(cx, yy - 1, FLR, 13) end
    end
  end }
SCENES[8] = { name = "BIG LEAF", floor_y = 160,
  p = { sky_top = {210,245,150}, sky_hor = {120,200,90}, cloud_shade = {150,210,120}, cloud_light = {230,250,200},
        hill_dark = {40,110,50}, hill_light = {110,190,90}, sun_core = {255,255,220}, sun_glow = {240,255,180}, star = {255,255,255},
        outline = {20,60,25}, fol_dark = {30,100,45}, fol_light = {140,220,110}, wood_dark = {60,130,60}, wood_light = {160,230,120},
        wall_dark = {50,120,55}, wall_light = {120,200,100}, acc_a = {255,120,170}, acc_b = {255,220,80}, light = {235,255,220},
        ground_dark = {30,90,40}, ground_light = {120,205,100}, water_dark = {90,160,200}, water_light = {210,245,255},
        floor_line = {25,70,30}, hi_a = {180,240,160}, hi_b = {240,255,230}, glint = {255,255,255},
        prop_a = {255,120,170}, prop_b = {255,220,80}, prop_c = {120,190,230}, prop_d = {255,255,255} },
  paint = function()
    vgrad(0, W - 1, 0, 100, SKY, 1, 6)
    blob(60, 30, 26, 26, SKY, 8, false); blob(60, 30, 18, 18, SKY, 9, false); blob(200, 50, 20, 20, SKY, 8, false); blob(200, 50, 13, 13, SKY, 9, false)
    blob(130, 20, 14, 14, SKY, 14, false)
    hills(100, 86, 10, 1.3, 1.1, SKY, 12, 10)
    for y = 100, 159 do for x = 0, W - 1 do setp(x, y, MID, 3 + ((x + y * 2) % 23 == 0 and -1 or 0)) end end
    for k = 0, 6 do local x0 = 128; for s = 0, 80 do local xx = x0 + (k - 3) * s * 0.9; local yy = 100 + s * 0.75; setp(floor(xx), floor(yy), MID, 2); setp(floor(xx) + 1, floor(yy), MID, 2) end end
    for i = 0, 6 do line(0, 104 + i * 8, W - 1, 112 + i * 8, MID, 4) end
    for i = 0, 3 do local cx, cy = 40 + i * 58, 112 + (i % 2) * 22; blob(cx, cy, 8, 8, PRP, 9, true); blob(cx - 2, cy - 2, 3, 3, PRP, 14, false) end
    floor_plane(160, FLR, 2, 6, false)
    for k = 0, 8 do line(128 + (k - 4) * 6, 160, 128 + (k - 4) * 40, H - 1, FLR, 1) end
    for i = 0, 5 do line(0, 166 + i * 10, W - 1, 170 + i * 10, FLR, 1) end
  end }

local PAINT_CHAR = 0x0000
local function nearest(pal, c)
  local best, bd = 1, 1e9
  for i = 1, 15 do
    local p = pal[i]
    local d = (p[1] - c[1]) * (p[1] - c[1]) + (p[2] - c[2]) * (p[2] - c[2]) + (p[3] - c[3]) * (p[3] - c[3])
    if d < bd then bd = d; best = i end
  end
  return best
end

local function encode_painting()
  local remap = {}
  for row = 0, 27 do
    for col = 0, 31 do
      local counts = { 0, 0, 0, 0 }
      for y = 0, 7 do for x = 0, 7 do
        local v = PIX[(row * 8 + y) * W + col * 8 + x]
        if v ~= nil and v ~= 0 then local g = v // 16; counts[g] = counts[g] + 1 end
      end end
      local g = 1
      for k = 2, 4 do if counts[k] > counts[g] then g = k end end
      local tile = row * 32 + col
      local addr = PAINT_CHAR + tile * 16
      for y = 0, 7 do
        local p0, p1, p2, p3 = 0, 0, 0, 0
        for x = 0, 7 do
          local v = PIX[(row * 8 + y) * W + col * 8 + x] or 0
          local idx = 0
          if v ~= 0 then
            local vg, vi = v // 16, v % 16
            if vg == g then idx = vi else
              local key = v * 8 + g
              if remap[key] == nil then remap[key] = nearest(PALS[g], PALS[vg][vi]) end
              idx = remap[key]
            end
          end
          if idx ~= 0 then
            local bit = 1 << (7 - x)
            if idx & 1 ~= 0 then p0 = p0 | bit end
            if idx & 2 ~= 0 then p1 = p1 | bit end
            if idx & 4 ~= 0 then p2 = p2 | bit end
            if idx & 8 ~= 0 then p3 = p3 | bit end
          end
        end
        vram[addr + y] = p0 | (p1 << 8)
        vram[addr + 8 + y] = p2 | (p3 << 8)
      end
      vram[STAGE_MAP + tile] = tile | (PAL_OF[g] << 10)
    end
  end
end

local function write_palettes()
  for g = 1, 4 do
    local base = PAL_OF[g] * 16
    for i = 1, 15 do local c = PALS[g][i]; cgram[base + i] = rgb(min(255, c[1]), min(255, c[2]), min(255, c[3])) end
  end
end

function build_stage(ci)
  local sc = SCENES[ci]
  CURRENT_STAGE = ci
  PALS = make_palettes(sc.p)
  for i = 0, W * H - 1 do PIX[i] = 0 end
  sc.paint()
  bg[2].char_base = PAINT_CHAR
  encode_painting()
  write_palettes()
  SKY_KEYS = { { 0, rgb(sc.p.sky_top[1], sc.p.sky_top[2], sc.p.sky_top[3]) }, { 168, rgb(sc.p.sky_hor[1], sc.p.sky_hor[2], sc.p.sky_hor[3]) } }
  if play_music ~= nil then play_music(ci) end
end

function stage_sky()
  local a = AMBIENT[CURRENT_STAGE]
  local sw, dr = nil, nil
  if a ~= nil then sw = a.sway; dr = a.drift end
  local tt = AMB_T or 0
  local keys = SKY_KEYS
  hdma(0, 159, function(y)
    cgram[0] = ramp_color(keys, y)
    local sx = 0
    if dr ~= nil and y >= dr[1] and y <= dr[2] then sx = floor(tt * dr[3]) % 256 end
    if sw ~= nil and y >= sw[1] and y <= sw[2] then sx = sx + sin(tt * 1.5 + y / sw[4]) * sw[3] end
    bg[2].scroll.x = sx
  end)
  if PALS[FLR] == nil then return end
  local f = PALS[FLR]
  hdma(160, 223, function(y)
    local k = 1.05 - (y - 160) / 64 * 0.42
    for i = 1, 6 do
      local c = f[i]
      cgram[i] = rgb(min(255, floor(c[1] * k)), min(255, floor(c[2] * k)), min(255, floor(c[3] * k)))
    end
    if CURRENT_STAGE == 5 then bg[2].scroll.x = sin(tt * 2.5 + y / 5) * 1.5 end
  end)
  if CURRENT_STAGE == 1 then hdma(119, 159, function(y) bg[2].scroll.x = sin(tt * 2.5 + y / 5) * 1.5 end) end
end

local base_draw_sprites = draw_sprites
function draw_sprites()
  base_draw_sprites()
  if PALS[FLR] ~= nil then
    local tt = AMB_T or 0
    local w4, w5 = PALS[FLR][10], PALS[FLR][11]
    local k = 0.85 + 0.15 * sin(tt * 3)
    cgram[10] = rgb(floor(w4[1] * k), floor(w4[2] * k), floor(w4[3] * k))
    cgram[11] = rgb(min(255, floor(w5[1] * (1.15 - k * 0.15))), min(255, floor(w5[2] * (1.15 - k * 0.15))), min(255, floor(w5[3] * (1.15 - k * 0.15))))
    local s = PALS[SKY][15]
    local tw = 0.6 + 0.4 * sin(tt * 5)
    cgram[3 * 16 + 15] = rgb(floor(s[1] * tw), floor(s[2] * tw), floor(s[3] * tw))
    local g = PALS[SKY][14]
    local gk = 0.92 + 0.08 * sin(tt * 1.7)
    cgram[3 * 16 + 14] = rgb(min(255, floor(g[1] * gk)), min(255, floor(g[2] * gk)), min(255, floor(g[3] * gk)))
  end
end
