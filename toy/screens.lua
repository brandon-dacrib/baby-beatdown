-- screens.lua: title logo (big outlined BG tiles) and character-select portraits (32x32 sprites)
local GL = {
  B = { "1111.", "1...1", "1...1", "1111.", "1...1", "1...1", "1111." },
  A = { ".111.", "1...1", "1...1", "11111", "1...1", "1...1", "1...1" },
  Y = { "1...1", "1...1", ".1.1.", "..1..", "..1..", "..1..", "..1.." },
  E = { "11111", "1....", "1....", "1111.", "1....", "1....", "11111" },
  T = { "11111", "..1..", "..1..", "..1..", "..1..", "..1..", "..1.." },
  D = { "1111.", "1...1", "1...1", "1...1", "1...1", "1...1", "1111." },
  O = { ".111.", "1...1", "1...1", "1...1", "1...1", "1...1", ".111." },
  W = { "1...1", "1...1", "1...1", "1.1.1", "1.1.1", "1.1.1", ".1.1." },
  N = { "1...1", "11..1", "1.1.1", "1..11", "1...1", "1...1", "1...1" },
}
LOGO_TILE = 64
LOGO_W, LOGO_H = 208, 24
local logo_ready = false

local function build_logo()
  local buf = {}
  for i = 0, LOGO_W * LOGO_H - 1 do buf[i] = 0 end
  local function put(x, y, v) if x >= 0 and x < LOGO_W and y >= 0 and y < LOGO_H then buf[y * LOGO_W + x] = v end end
  local word = "BABY BEATDOWN"
  for i = 1, string.len(word) do
    local ch = string.sub(word, i, i)
    local g = GL[ch]
    if g ~= nil then
      local ox = (i - 1) * 16 + 1
      for gy = 0, 6 do
        for gx = 0, 4 do
          if string.sub(g[gy + 1], gx + 1, gx + 1) == "1" then
            for dy = 0, 2 do for dx = 0, 2 do
              local y = 1 + gy * 3 + dy
              local col = 2
              if y > 12 then col = 3 end
              if y == 2 then col = 4 end
              put(ox + gx * 3 + dx, y, col)
            end end
          end
        end
      end
    end
  end
  local out = {}
  for y = 0, LOGO_H - 1 do
    for x = 0, LOGO_W - 1 do
      if buf[y * LOGO_W + x] == 0 then
        local near = false
        for dy = -1, 1 do for dx = -1, 1 do
          local nx, ny = x + dx, y + dy
          if nx >= 0 and nx < LOGO_W and ny >= 0 and ny < LOGO_H and buf[ny * LOGO_W + nx] ~= 0 and buf[ny * LOGO_W + nx] ~= 1 then near = true end
        end end
        if near then out[#out + 1] = y * LOGO_W + x end
      end
    end
  end
  for _, k in ipairs(out) do buf[k] = 1 end
  for ty = 0, 2 do
    for tx = 0, 25 do
      local tile = LOGO_TILE + ty * 26 + tx
      local addr = HUD_CHAR + tile * 16
      for row = 0, 7 do
        local p0, p1, p2, p3 = 0, 0, 0, 0
        for col = 0, 7 do
          local v = buf[(ty * 8 + row) * LOGO_W + tx * 8 + col]
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
  logo_ready = true
end

function draw_logo(row, col)
  if not logo_ready then build_logo() end
  for ty = 0, 2 do
    for tx = 0, 25 do
      vram[HUD_MAP + (row + ty) * 32 + col + tx] = (LOGO_TILE + ty * 26 + tx) | HUD_ATTR
    end
  end
end

PORTRAIT_TILE = 256
local portraits_ready = false

local function encode_portrait(ci)
  local c = render_pose(ci, 0)
  local base = PORTRAIT_TILE + ((ci - 1) % 4) * 4 + ((ci - 1) // 4) * 64
  local cx0, cy0 = 12, 2
  for ty = 0, 3 do
    for tx = 0, 3 do
      local addr = OBJ_BASE + (base + ty * 16 + tx) * 16
      for row = 0, 7 do
        local p0, p1, p2, p3 = 0, 0, 0, 0
        for col = 0, 7 do
          local x, y = cx0 + tx * 8 + col, cy0 + ty * 8 + row
          local v = 0
          if x >= 0 and x < 64 and y >= 0 and y < 64 then v = c[y * 64 + x] end
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

function prepare_portraits()
  if not portraits_ready then
    for ci = 1, 8 do encode_portrait(ci) end
    portraits_ready = true
  end
  for ci = 1, 8 do load_char_palette(ci - 1, ci, false) end
end

function draw_portrait(ci, n, x, y)
  local o = obj[n]
  o.tile = PORTRAIT_TILE + ((ci - 1) % 4) * 4 + ((ci - 1) // 4) * 64
  o.pal = ci - 1; o.large = true; o.x = x; o.y = y; o.prio = 3; o.flip_x = false; o.flip_y = false; o.on = true
end

function restore_fx_palette()
  for i = 1, 15 do cgram[128 + 2 * 16 + i] = rgb(FX_PAL[i][1], FX_PAL[i][2], FX_PAL[i][3]) end
end
