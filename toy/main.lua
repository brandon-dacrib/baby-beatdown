-- BABY BEATDOWN -- main.lua: shared tables, VRAM layout, fx upload, HUD text
-- art.lua renders the fighters, stages.lua builds the arenas, fight.lua / flow.lua run the game
CHAR_PAL = {}
CHAR_NAME = {}
FX_PAL = {}
FX_TILES = {}
FX_SUM = 24850

-- super move per character: kind "proj" or "rush" (dy is in 64x64 sprite pixels)
SUPER = {
  { name = "DIAPER DUMP",    kind = "proj", speed = 2.5, dy = 16, dmg = 16 },
  { name = "BOTTLE BASH",    kind = "rush", pose = 3, speed = 4.5, dmg = 15, hits = 1 },
  { name = "RATTLE RAMPAGE", kind = "rush", pose = 3, speed = 3.5, dmg = 6,  hits = 3 },
  { name = "BINKY BLAST",    kind = "proj", speed = 3.5, dy = 20, dmg = 14 },
  { name = "BUBBLE BURP",    kind = "proj", speed = 1.2, dy = 12, dmg = 18, wobble = true },
  { name = "TANTRUM TOSS",   kind = "proj", speed = 3,   dy = 46, dmg = 15, ground = true },
  { name = "TEETHING CHOMP", kind = "rush", pose = 4, speed = 4.5, dmg = 15, hits = 1, hop = true },
  { name = "SPIT-UP SPRAY",  kind = "proj", speed = 4,   dy = 16, dmg = 12, short = 70 },
}

-- VRAM layout (word addresses)
OBJ_BASE = 0x6000          -- sprite window: fighters at tiles 0..127 (two 64x64 cells), fx at 384+
FX_TILE = 384
STAGE_CHAR, STAGE_MAP = 0x4000, 0x4400
HUD_CHAR, HUD_MAP = 0x5000, 0x4800

FONT_SRC = dma("font", { char = HUD_CHAR, pal = 16 })
TUNE = score{ song = "nursery", loop = true }
SND_HIT = bank("snare", { vol = 110 })
SND_THUD = bank("kick", { vol = 120 })
SND_WHIFF = bank("hat", { vol = 60 })
SND_BLOCK = bank("tom", { vol = 90 })
SND_KO = bank("crash", { vol = 110 })
SND_SUPER = bank("bell", { vol = 100 })
SND_SEL = bank("pluck", { vol = 90 })

POSE_IDLE, POSE_WALK1, POSE_WALK2, POSE_PUNCH, POSE_KICK, POSE_CROUCH = 0, 1, 2, 3, 4, 5
POSE_JUMP, POSE_HIT, POSE_BLOCK, POSE_KO, POSE_SUPER, POSE_CKICK = 6, 7, 8, 9, 10, 11

FLOOR_Y = 112            -- sprite top when standing (64 tall, feet at 176)
HP_MAX, METER_MAX = 96, 96
GRAVITY = 0.32

function fx_tile(cell) return FX_TILE + (cell % 8) * 2 + (cell // 8) * 32 end

-- ---------------------------------------------------------------- fx data upload (hex strings)
local function decode_tile(hex, tag)
  local words = {}
  local n, acc, count = 0, 0, 0
  for i = 1, string.len(hex) do
    local b = string.byte(hex, i)
    local v = -1
    if b >= 48 and b <= 57 then v = b - 48
    elseif b >= 97 and b <= 102 then v = b - 87
    elseif b >= 65 and b <= 70 then v = b - 55 end
    if v >= 0 then
      acc = acc * 16 + v
      count = count + 1
      if count == 4 then words[n] = acc; n = n + 1; acc, count = 0, 0 end
    end
  end
  if n ~= 16 or count ~= 0 then error("bad tile data in " .. tag) end
  return words
end

function upload_tiles(tiles, expect_sum, tag)
  local sum = 0
  for tile, hex in pairs(tiles) do
    local words = decode_tile(hex, tag .. " tile " .. tile)
    local base = OBJ_BASE + tile * 16
    for w = 0, 15 do
      vram[base + w] = words[w]
      sum = (sum + words[w] + tile) % 65536
    end
  end
  if expect_sum and sum ~= expect_sum then
    error("checksum mismatch for " .. tag .. ": got " .. sum .. " expected " .. expect_sum)
  end
end

function load_char_palette(slot, c, tint)
  local pal = CHAR_PAL[c]
  for i = 1, 15 do
    local r, g, b = pal[i][1], pal[i][2], pal[i][3]
    if tint and i >= 2 and i <= 4 then r, g, b = floor(b * 0.6 + 40), floor(g * 0.7 + 20), floor(r * 0.6 + 60) end
    cgram[128 + slot * 16 + i] = rgb(min(255, r), min(255, g), min(255, b))
  end
end

function load_fighter(slot, c, tint)
  prerender(c)
  VRAM_POSE[slot] = -1
  load_char_palette(slot - 1, c, tint)
end

-- ---------------------------------------------------------------- HUD text
local function glyph(b)
  if b >= 65 and b <= 90 then return b - 64 end
  if b >= 48 and b <= 57 then return b - 48 + 27 end
  if b == 33 then return 37 end
  if b == 46 then return 38 end
  if b == 45 then return 39 end
  if b == 58 then return 40 end
  if b == 62 then return 41 end
  if b == 60 then return 42 end
  return 0
end
HUD_ATTR = (1 << 10) | 0x2000   -- palette 1, high priority
function text(col, row, s)
  local base = HUD_MAP + row * 32 + col
  for i = 1, string.len(s) do
    vram[base + i - 1] = glyph(string.byte(s, i)) | HUD_ATTR
  end
end
function text_center(row, s) text((32 - string.len(s)) // 2, row, s) end
function clear_row(row)
  for c = 0, 31 do vram[HUD_MAP + row * 32 + c] = 0 end
end
function hud_tile(col, row, tile) vram[HUD_MAP + row * 32 + col] = tile | HUD_ATTR end
function clear_hud() for r = 0, 27 do clear_row(r) end end
