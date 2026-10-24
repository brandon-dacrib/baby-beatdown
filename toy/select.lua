-- select.lua: Street Fighter II style PLAYER SELECT. Runs last.
--  * background = painted map of the babies' world with the eight stage locations (bg9*.lua, BG palettes 3..7)
--  * a 4x2 grid of 32x32 face icons (OBJ, one 15-colour palette per baby, data in faceN.lua)
--  * the highlighted baby's 96x96 portrait, streamed into BG2 tiles 880..1023 with BG palette 0
--  * yellow "1P" bracket + name, red "CPU" bracket once the opponent is drawn, the chosen stage label lit on the map
--  * the attract-mode demo walks through this screen too (cursor wanders, picks, then the CPU match starts)
STAGES[9] = { name = "SELECT", sky = { {6,6,60}, {26,30,110} }, pal = STAGES[1].pal }
local FACE_TILE = 880
local FACE_CHAR = FACE_TILE * 16
local ICON_TILE = 256
local GRID_X, GRID_Y = 112, 112
local LOC = { {1,10}, {7,7}, {11,3}, {13,9}, {17,6}, {20,11}, {24,5}, {27,10} }   -- map label col,row per stage
local LOCNAME = { "BAYOU", "YARD", "ROOF", "FARM", "POND", "CAVE", "GARDEN", "LEAF" }

local B64 = {}
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
for i = 1, 64 do B64[string.byte(alphabet, i)] = i - 1 end
local function decode(parts, expect, tag)
  -- parts: list of base64 strings, each decoded on its own (padding bits must not leak into the next);
  -- a 0 byte followed by n expands to n zero bytes (zero-run RLE, see tools/faces.py)
  local words = {}
  local sum, lo, have, k = 0, 0, false, 0
  local function put(byte)
    sum = sum + byte
    if have then words[k] = lo | (byte << 8); k = k + 1; have = false else lo = byte; have = true end
  end
  for p = 1, #parts do
    local s = parts[p]
    local acc, bits, zero = 0, 0, false
    for i = 1, string.len(s) do
      local v = B64[string.byte(s, i)]
      if v ~= nil then
        acc = (acc << 6) | v
        bits = bits + 6
        if bits >= 8 then
          bits = bits - 8
          local byte = (acc >> bits) & 255
          acc = acc & ((1 << bits) - 1)
          if zero then
            for _ = 1, byte do put(0) end
            zero = false
          elseif byte == 0 then zero = true
          else put(byte) end
        end
      end
    end
  end
  if sum % 65536 ~= expect then error("bad face data: " .. tag) end
  return words
end

-- bracket corner tile (font tile 49): an L of index-2 pixels, flipped in the tilemap for the other corners
do
  local base = HUD_CHAR + 49 * 16
  for r = 0, 15 do vram[base + r] = 0 end
  vram[base + 0] = 0xFC << 8; vram[base + 1] = 0xFC << 8
  for r = 2, 5 do vram[base + r] = 0xC0 << 8 end
end
local function bracket(col, row, w, h, pal)
  local attr = 49 | (pal << 10) | 0x2000
  vram[HUD_MAP + row * 32 + col] = attr
  vram[HUD_MAP + row * 32 + col + w - 1] = attr | 0x4000
  vram[HUD_MAP + (row + h - 1) * 32 + col] = attr | 0x8000
  vram[HUD_MAP + (row + h - 1) * 32 + col + w - 1] = attr | 0xC000
end

local icon_tile = {}
for ci = 1, 8 do icon_tile[ci] = ICON_TILE + ((ci - 1) % 4) * 4 + ((ci - 1) // 4) * 64 end
local function upload_icons()
  for ci = 1, 8 do
    local d = FACE[ci]
    local w = decode({ d.small }, d.ssum, "icon " .. ci)
    for k = 0, 15 do
      local addr = OBJ_BASE + (icon_tile[ci] + (k // 4) * 16 + (k % 4)) * 16
      for i = 0, 15 do vram[addr + i] = w[k * 16 + i] end
    end
    for i = 1, 15 do
      local v = d.pal[i]
      cgram[128 + (ci - 1) * 16 + i] = rgb((v & 31) * 8 + 4, ((v >> 5) & 31) * 8 + 4, ((v >> 10) & 31) * 8 + 4)
    end
  end
end

local face_shown = 0
local function show_face(ci)
  if face_shown == ci then return end
  face_shown = ci
  local d = FACE[ci]
  local w = decode({ d.b1, d.b2, d.b3, d.b4 }, d.bsum, "portrait " .. ci)
  for i = 0, 144 * 16 - 1 do vram[FACE_CHAR + i] = w[i] end
  for i = 1, 15 do
    local v = d.pal[i]
    cgram[i] = rgb((v & 31) * 8 + 4, ((v >> 5) & 31) * 8 + 4, ((v >> 10) & 31) * 8 + 4)
  end
  for ty = 0, 11 do
    for tx = 0, 11 do vram[STAGE_MAP + (15 + ty) * 32 + 1 + tx] = FACE_TILE + ty * 12 + tx end
  end
end

-- ---------------------------------------------------------------- entering / leaving
local function enter_select(demo)
  ROUND.state = "select"; ROUND.timer = 0
  SEL.cursor = demo and (1 + floor(rnd() * 8)) or 1
  SEL.cpu = 0; SEL.timer = 0; SEL.demo = demo; SEL.demo_t = 0; SEL.demo_moves = 3 + floor(rnd() * 5)
  P2 = nil
  P1 = new_fighter(1, SEL.cursor, 8, 1, false)
  obj.size_sel = 5
  for i = 0, 31 do obj[i].on = false end
  clear_hud()
  face_shown = 0
  build_stage(9)
  upload_icons()
  show_face(SEL.cursor)
end

-- flow.lua's go_select() ends by calling prepare_portraits(): that is our hook into the select screen
function prepare_portraits() enter_select(false) end

local function pick_pair()
  local a = 1 + floor(rnd() * 8)
  local b = 1 + floor(rnd() * 7)
  if b >= a then b = b + 1 end
  return a, b
end

local function to_title()
  DEMO = false
  ROUND.state = "title"; ROUND.timer = 0
  obj.size_sel = 4
  clear_hud()
  if restore_fx_palette ~= nil then restore_fx_palette() end
  local a, b = pick_pair()
  P1 = new_fighter(1, a, 36, 1, false)
  P2 = new_fighter(2, b, 156, -1, false)
  load_fighter(1, a, false); load_fighter(2, b, false)
  TITLE.t = 0
  build_stage(1 + floor(rnd() * 8))
  PROJ = {}; SPARKS = {}
end

local function start_match(c1, c2, cpu1)
  obj.size_sel = 4
  for i = 0, 31 do obj[i].on = false end
  P1 = new_fighter(1, c1, 32, 1, cpu1)
  P2 = new_fighter(2, c2, 160, -1, true)
  load_fighter(1, c1, false)
  load_fighter(2, c2, c1 == c2)
  if restore_fx_palette ~= nil then restore_fx_palette() end
  build_stage(c2)
  ROUND.num = 1
  PROJ = {}; SPARKS = {}
  ROUND.clock = 99
  ROUND.state = "intro"; ROUND.timer = 0
  ROUND.callout_t = 0
  clear_hud()
end

local function any_button()
  return pressed("start") or pressed("a") or pressed("b") or pressed("y") or pressed("x")
end

local function move_cursor(dx, dy)
  local c = SEL.cursor
  if dx ~= 0 then
    local col = (c - 1) % 4
    col = (col + dx) % 4
    c = (c - 1) - ((c - 1) % 4) + col + 1
  end
  if dy ~= 0 then if c > 4 then c = c - 4 else c = c + 4 end end
  if c ~= SEL.cursor then
    SEL.cursor = c
    P1.char = c
    sfx(SND_SEL, 6, "E5")
  end
end

local function pick()
  SEL.cpu = 1 + floor(rnd() * 8)
  SEL.timer = 0
  sfx(SND_SEL, 6, "G5")
end

-- ---------------------------------------------------------------- per-frame
local function font_colors()
  cgram[17] = rgb(14, 10, 18); cgram[18] = rgb(255, 224, 64); cgram[19] = rgb(255, 144, 32); cgram[20] = rgb(255, 255, 255)
  cgram[33] = rgb(24, 8, 16); cgram[34] = rgb(240, 64, 56); cgram[35] = rgb(176, 28, 40); cgram[36] = rgb(255, 230, 220)
end

local function pad_name(s, n)
  while string.len(s) < n do s = s .. " " end
  return s
end

local function update_select(f)
  ROUND.timer = ROUND.timer + 1
  if ROUND.timer < 12 then return end   -- input lockout: the press that opened this screen must not pick
  if SEL.demo then
    if any_button() then to_title(); sfx(SND_SEL, 6, "C5") return end
    SEL.demo_t = SEL.demo_t + 1
    if SEL.cpu == 0 then
      if SEL.demo_moves > 0 then
        if SEL.demo_t % 22 == 0 then
          local r = rnd()
          if r < 0.6 then move_cursor((rnd() < 0.5) and -1 or 1, 0) else move_cursor(0, 1) end
          SEL.demo_moves = SEL.demo_moves - 1
        end
      elseif SEL.demo_t % 22 == 0 and SEL.demo_t > 40 then
        pick()
      end
    end
  elseif SEL.cpu == 0 then
    if pressed("left") then move_cursor(-1, 0) end
    if pressed("right") then move_cursor(1, 0) end
    if pressed("up") or pressed("down") then move_cursor(0, 1) end
    if any_button() then pick() end
  end
  if SEL.cpu ~= 0 then
    SEL.timer = SEL.timer + 1
    if SEL.timer > 110 then start_match(SEL.cursor, SEL.cpu, SEL.demo == true) return end
  end
  show_face(SEL.cursor)
  -- HUD layer
  clear_hud()
  text_center(1, "PLAYER SELECT")
  local c = SEL.cursor
  local ccol, crow = (GRID_X + ((c - 1) % 4) * 32) // 8, (GRID_Y + ((c - 1) // 4) * 32) // 8
  bracket(ccol, crow, 4, 4, 1)
  if (f // 16) % 2 == 0 or SEL.cpu ~= 0 then text(ccol + 1, crow - 1, "1P") end
  text(1, 13, "1P")
  text(1, 14, pad_name(CHAR_NAME[c], 12))
  local lc = LOC[c]
  text(lc[1], lc[2], LOCNAME[c])
  if SEL.cpu ~= 0 then
    local k = SEL.cpu
    local kcol, krow = (GRID_X + ((k - 1) % 4) * 32) // 8, (GRID_Y + ((k - 1) // 4) * 32) // 8
    bracket(kcol, krow, 4, 4, 2)
    text_pal(kcol, krow - 1, "CPU", 2)
    local lk = LOC[k]
    text_pal(lk[1], lk[2], LOCNAME[k], 2)
    text_pal(14, 23, "VS CPU " .. CHAR_NAME[k], 2)
    text(14, 24, "STAGE " .. STAGES[k].name)
    if k == c then text(ccol + 1, crow - 1, "1P") end
  end
  if SEL.demo and f % 60 < 36 then text_center(26, "DEMO - PUSH START") end
end

local function draw_select_icons(f)
  for i = 0, 31 do obj[i].on = false end
  for ci = 1, 8 do
    local o = obj[3 + ci]
    o.tile = icon_tile[ci]; o.pal = ci - 1; o.large = false
    o.x = GRID_X + ((ci - 1) % 4) * 32
    o.y = GRID_Y + ((ci - 1) // 4) * 32
    if ci == SEL.cursor and SEL.cpu == 0 then o.y = o.y - ((f // 8) % 2) end
    o.prio = 2; o.flip_x = false; o.flip_y = false; o.on = true
  end
end

-- ---------------------------------------------------------------- hooks
local base_stage_sky = stage_sky
function stage_sky()
  if CURRENT_STAGE ~= 9 then base_stage_sky() return end
  local keys = SKY_KEYS
  hdma(0, 223, function(y) cgram[0] = ramp_color(keys, y) end)
end

local base_play_music = play_music
function play_music(i)
  if i ~= 9 then base_play_music(i) return end
  if MUSIC_NOW == 9 then return end
  for j = 1, 8 do SONGS[j].stop() end
  TUNE.play()
  MUSIC_NOW = 9
end

local base_frame = frame
function frame(t, f)
  AMB_T = t; AMB_F = f
  if not DEMO and ROUND.state == "title" and TITLE.t >= 300 and not any_button() then
    DEMO = true
    enter_select(true)
  end
  if ROUND.state == "select" then
    brightness = 15
    font_colors()
    update_select(f)
    if ROUND.state == "select" then
      draw_sprites()
      draw_select_icons(f)
    else
      draw_sprites()
    end
    remember_pad()
    return
  end
  base_frame(t, f)
end
