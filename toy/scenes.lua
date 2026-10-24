-- scenes.lua: painted stages. Each bgN.lua holds a 256x224 painting rendered offline (tools/scenes.py) and
-- quantized to six 15-colour palettes (tools/quantize.py): 4bpp tiles + a 28x32 tilemap, base64 with checksums.
-- Palette slot 0 is reserved for the floor rows (y >= 160) so the floor can be darkened per scanline toward
-- the camera; slots 3..7 hold the rest (1 and 2 belong to the HUD font). Sky pixels are index 0 (transparent),
-- so the per-scanline backdrop gradient paints the sky. Runs after cps.lua and replaces build_stage/stage_sky
-- whenever BGDATA[stage] exists (painter.lua remains the fallback).
BGDATA = BGDATA or {}
local B64 = {}
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
for i = 1, 64 do B64[string.byte(alphabet, i)] = i - 1 end

local function decode_words(s, base, expect_sum, tag)
  local n = string.len(s)
  local acc, bits, sum = 0, 0, 0
  local lo, have = 0, false
  local addr = base
  for i = 1, n do
    local v = B64[string.byte(s, i)]
    if v ~= nil then
      acc = (acc << 6) | v
      bits = bits + 6
      if bits >= 8 then
        bits = bits - 8
        local byte = (acc >> bits) & 255
        acc = acc & ((1 << bits) - 1)
        sum = sum + byte
        if have then
          vram[addr] = lo | (byte << 8)
          addr = addr + 1
          have = false
        else
          lo = byte
          have = true
        end
      end
    end
  end
  if sum % 65536 ~= expect_sum then error("bad stage data: " .. tag) end
  return addr - base
end

PAL_SLOTS = { 0, 3, 4, 5, 6, 7 }
FLOOR_RGB = {}
WATER_ROWS = { [1] = { 120, 159 }, [5] = { 161, 223 } }

local base_build_stage = build_stage
function build_stage(ci)
  local d = BGDATA[ci]
  if d == nil then base_build_stage(ci) return end
  CURRENT_STAGE = ci
  bg[2].char_base = 0
  local tiles = d.tiles
  if tiles == nil then tiles = d.t1 .. d.t2 .. d.t3 end
  decode_words(tiles, 0, d.tsum, "tiles " .. ci)
  decode_words(d.map, STAGE_MAP, d.msum, "map " .. ci)
  for k = 1, 6 do
    local base = PAL_SLOTS[k] * 16
    for i = 1, 15 do
      local w = d.pal[k][i]
      local r, g, b = (w & 31) * 8 + 4, ((w >> 5) & 31) * 8 + 4, ((w >> 10) & 31) * 8 + 4
      cgram[base + i] = rgb(r, g, b)
      if k == 1 then FLOOR_RGB[i] = { r, g, b } end
    end
  end
  SKY_KEYS = { { 0, rgb(d.sky[1][1], d.sky[1][2], d.sky[1][3]) }, { 168, rgb(d.sky[2][1], d.sky[2][2], d.sky[2][3]) } }
  STAGES[ci].sky = d.sky
  if play_music ~= nil then play_music(ci) end
end

local base_stage_sky = stage_sky
function stage_sky()
  local ci = CURRENT_STAGE
  if BGDATA[ci] == nil then base_stage_sky() return end
  local a = AMBIENT[ci]
  local sw, dr = nil, nil
  if a ~= nil then sw = a.sway; dr = a.drift end
  local tt = AMB_T or 0
  local keys = SKY_KEYS
  local cam = CAM or 0
  local wat = WATER_ROWS[ci]
  hdma(0, 159, function(y)
    cgram[0] = ramp_color(keys, y)
    local sx = 0
    if dr ~= nil and y >= dr[1] and y <= dr[2] then sx = floor(tt * dr[3]) % 256 end
    if sw ~= nil and y >= sw[1] and y <= sw[2] then sx = sx + sin(tt * 1.5 + y / sw[4]) * sw[3] end
    if y >= 100 then sx = sx - cam * 0.10 elseif y >= 60 then sx = sx - cam * 0.04 end
    if wat ~= nil and y >= wat[1] and y <= wat[2] then sx = sx + sin(tt * 2.5 + y / 5) * 1.5 end
    bg[2].scroll.x = sx
  end)
  hdma(160, 223, function(y)
    local k = 1.04 - (y - 160) / 64 * 0.40
    for i = 1, 15 do
      local c = FLOOR_RGB[i]
      cgram[i] = rgb(min(255, floor(c[1] * k)), min(255, floor(c[2] * k)), min(255, floor(c[3] * k)))
    end
    local sx = -cam * (0.12 + 0.24 * (y - 160) / 64)
    if wat ~= nil and y >= wat[1] and y <= wat[2] then sx = sx + sin(tt * 2.5 + y / 5) * 1.5 end
    bg[2].scroll.x = sx
  end)
end
