-- BABY BEATDOWN CART -- main.lua: engine in the ppu SNES dialect, built on the SF2 Turbo formats
-- (reference/SF2T_SNES_ARCHITECTURE.md). data.lua (generated) holds every table; this file only has code.
-- Units: positions and velocities in 1/16 px. Origin of a fighter = feet centre. Facing: 1 right, -1 left.
mode = 1
brightness = 15

-- ---------------------------------------------------------------- VRAM layout (word addresses)
-- 0x0000 stage tiles | 0x1800 stage map | 0x2000 OBJ: two 48-tile fighter windows (tiles 0..95, streamed
-- per pose through the VBlank window, SF2T style) | OBJ tiles 96.. the font for the sprite HUD
local STAGE = dma("stage", { char = 0x0000, pal = 0 })   -- 16-tile sheet; the map is built in init()
local STAGE_MAP = 0x1800
local OBJ_BASE = 0x2000
local FONT = dma("fontobj", { char = 0x2600, pal = 2 })  -- OBJ tiles 96..144, sprite palette 2
local FONT_TILE = 96
local HUD_OBJ = 48               -- OAM 0..23 P1 pieces, 24..47 P2 pieces, 48.. HUD
FLOOR = 176                 -- screen y of the feet
HP_MAX, METER_MAX = 96, 96
N_PLAYERS = 2

-- ---------------------------------------------------------------- fighter records (parallel arrays, SF2T $0500/$0700)
---@snes array FX 2 -256 4352
FX = { 1024, 2816 }         -- 64 px and 176 px, in 1/16
---@snes array FY 2 -4096 0
FY = { 0, 0 }               -- height above the floor, 1/16, negative = up
---@snes array FVX 2 -256 256
FVX = { 0, 0 }
---@snes array FVY 2 -256 256
FVY = { 0, 0 }
---@snes array FFACE 2 -1 1
FFACE = { 1, -1 }
---@snes array FCHAR 2 1 8
FCHAR = { 1, 2 }
---@snes array FHP 2 0 96
FHP = { 96, 96 }
---@snes array FMETER 2 0 96
FMETER = { 0, 0 }
ST_IDLE, ST_WALK, ST_CROUCH, ST_JUMP, ST_ATTACK, ST_HIT, ST_BLOCK, ST_KO, ST_SUPER, ST_WIN = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
---@snes array FSTATE 2 0 9
FSTATE = { 0, 0 }
---@snes array FTIMER 2 0 255
FTIMER = { 0, 0 }
---@snes array FMOVE 2 0 31
FMOVE = { 0, 0 }
---@snes array FHITDONE 2 0 4
FHITDONE = { 0, 0 }
---@snes array FLAST 2 0 31
FLAST = { 0, 0 }
---@snes array FFLASH 2 0 8
FFLASH = { 0, 0 }
---@snes array FWINS 2 0 2
FWINS = { 0, 0 }
-- script interpreter state (SF2T: $1A script ptr, $17 hold counter, $1E frame, $3A.. box set)
---@snes array FSCRIPT 2 0 63
FSCRIPT = { 0, 0 }
---@snes array FKEY 2 0 255
FKEY = { 0, 0 }             -- absolute keyframe index into SCRIPT_DATA
---@snes array FHOLD 2 0 255
FHOLD = { 0, 0 }
---@snes array FCELL 2 0 63
FCELL = { 0, 0 }            -- sheet cell currently shown
---@snes array FSHOWN 2 -1 63
FSHOWN = { -1, -1 }         -- cell resident in the slot's VRAM window
---@snes array FBOXSET 2 0 15
FBOXSET = { 1, 1 }
---@snes array FACTIVE 2 0 1
FACTIVE = { 0, 0 }          -- keyframe flags bit1: attack box live
-- input (SF2T: held + newly pressed)
---@snes array IN_LEFT 2 0 1
IN_LEFT = { 0, 0 }
---@snes array IN_RIGHT 2 0 1
IN_RIGHT = { 0, 0 }
---@snes array IN_UP 2 0 1
IN_UP = { 0, 0 }
---@snes array IN_DOWN 2 0 1
IN_DOWN = { 0, 0 }
---@snes array IN_PUNCH 2 0 1
IN_PUNCH = { 0, 0 }
---@snes array IN_KICK 2 0 1
IN_KICK = { 0, 0 }
---@snes array IN_SUPER 2 0 1
IN_SUPER = { 0, 0 }
---@snes range PREV_Y 0 1
PREV_Y = 0
---@snes range PREV_X 0 1
PREV_X = 0
---@snes range PREV_B 0 1
PREV_B = 0
---@snes range PREV_A 0 1
PREV_A = 0
---@snes vblank 8192 9727
---@snes range FRAME 0 65535
FRAME = 0
---@snes range CLOCK 0 99
CLOCK = 99
---@snes range RNG 0 65535
RNG = 12345
-- CPU brain
---@snes range AI_T 0 63
AI_T = 0
---@snes range AI_PLAN 0 10
AI_PLAN = 0

function rnd8()
  RNG = (RNG * 75 + 74) & 0xFFFF
  return RNG & 255
end

-- ---------------------------------------------------------------- script interpreter (SF2T $C1:34F7)
function set_script(i, s)
  FSCRIPT[i] = s
  FKEY[i] = SCRIPT_START[s]
  load_key(i)
end

function load_key(i)
  local k = FKEY[i] * 4 - 3
  FHOLD[i] = SCRIPT_DATA[k]
  local flags = SCRIPT_DATA[k + 1]
  FCELL[i] = SCRIPT_DATA[k + 2]
  FBOXSET[i] = SCRIPT_DATA[k + 3]
  if flags >= 128 then flags = flags - 128 end
  FACTIVE[i] = 0
  if flags >= 2 then FACTIVE[i] = 1 end
  -- idle uses the per-character second stance on its middle keyframe
  if FSCRIPT[i] == SC_IDLE and FKEY[i] == SCRIPT_START[SC_IDLE] + 1 then FCELL[i] = CH_IDLE2[FCHAR[i]] end
end

-- returns 1 when the script reached its last keyframe and ran out
function step_script(i)
  if FHOLD[i] > 1 then FHOLD[i] = FHOLD[i] - 1; return 0 end
  local k = FKEY[i] * 4 - 3
  local flags = SCRIPT_DATA[k + 1]
  if flags >= 128 then
    if flags % 2 == 1 then FKEY[i] = SCRIPT_START[FSCRIPT[i]]; load_key(i); return 0 end   -- loop
    return 1
  end
  FKEY[i] = FKEY[i] + 1
  load_key(i)
  return 0
end

-- ---------------------------------------------------------------- boxes (SF2T: centre/half-extent, (dx+s) <= 2s)
---@snes range BX 0 4352
BX = 0
---@snes range BY 0 1000
BY = 0
---@snes range BW 0 64
BW = 0
---@snes range BH 0 64
BH = 0
function world_box(i, cx, cy, hw, hh)
  BX = FX[i] // 16 + cx * FFACE[i]
  BY = (0 - FY[i] // 16) + cy
  BW = hw
  BH = hh
end
---@snes range OX 0 4352
OX = 0
---@snes range OY 0 1000
OY = 0
---@snes range OW 0 64
OW = 0
---@snes range OH 0 64
OH = 0
function overlap_bo()
  local dx = BX - OX
  if dx < 0 then dx = 0 - dx end
  if dx > BW + OW then return 0 end
  local dy = BY - OY
  if dy < 0 then dy = 0 - dy end
  if dy > BH + OH then return 0 end
  return 1
end

-- attacker i's live attack box against defender j's hurt slots; returns hurt slot hit (1 head 2 body 3 legs) or 0
function hit_test(i, j)
  local b = M_BOX[FMOVE[i]]
  if b == 0 then return 0 end
  world_box(i, ABOX_CX[b], ABOX_CY[b], ABOX_HW[b], ABOX_HH[b])
  local bs = FBOXSET[j]
  for slot = 1, 3 do
    local h = BS_HEAD[bs]
    if slot == 2 then h = BS_BODY[bs] elseif slot == 3 then h = BS_LEGS[bs] end
    if h > 0 then
      OX = FX[j] // 16 + HBOX_CX[h] * FFACE[j]
      OY = (0 - FY[j] // 16) + HBOX_CY[h]
      OW = HBOX_HW[h]
      OH = HBOX_HH[h]
      if overlap_bo() == 1 then return slot end
    end
  end
  return 0
end

-- push boxes keep the fighters apart (SF2T $C0:6312)
function separate()
  if FSTATE[1] == ST_KO or FSTATE[2] == ST_KO then return end
  local p1 = BS_PUSH[FBOXSET[1]]
  local p2 = BS_PUSH[FBOXSET[2]]
  if p1 == 0 or p2 == 0 then return end
  local dx = FX[2] - FX[1]
  local ax = dx
  if ax < 0 then ax = 0 - ax end
  local s = (PBOX_HW[p1] + PBOX_HW[p2]) * 16
  local dy = FY[2] - FY[1]
  if dy < 0 then dy = 0 - dy end
  if dy > (PBOX_HH[p1] + PBOX_HH[p2]) * 16 then return end
  if ax < s then
    local push = (s - ax) // 2
    if dx >= 0 then FX[1] = FX[1] - push; FX[2] = FX[2] + push
    else FX[1] = FX[1] + push; FX[2] = FX[2] - push end
  end
  for i = 1, 2 do
    if FX[i] < 256 then FX[i] = 256 end
    if FX[i] > 3840 then FX[i] = 3840 end
  end
end

-- ---------------------------------------------------------------- fighter logic
function start_move(i, m)
  FSTATE[i] = ST_ATTACK
  FMOVE[i] = m
  FTIMER[i] = 0
  FHITDONE[i] = 0
  FLAST[i] = m
  FVX[i] = 0
  if M_HOP[m] < 0 then FVY[i] = M_HOP[m] end
  set_script(i, M_SCRIPT[m])
end

function pick_move(i, kind)
  local c = FCHAR[i]
  local n = CH_NPUNCHES[c]
  if kind == 2 then n = CH_NKICKS[c] end
  local k = rnd8() % n + 1
  local m = 0
  if kind == 1 then m = CH_PUNCHES[(c - 1) * 5 + k] else m = CH_KICKS[(c - 1) * 5 + k] end
  if m == FLAST[i] then
    k = k % n + 1
    if kind == 1 then m = CH_PUNCHES[(c - 1) * 5 + k] else m = CH_KICKS[(c - 1) * 5 + k] end
  end
  return m
end

function holding_back(i)
  if FFACE[i] == 1 then return IN_LEFT[i] end
  return IN_RIGHT[i]
end

function take_hit(att, def, dmg, stun, slot, low, high)
  local grounded = (FSTATE[def] == ST_IDLE or FSTATE[def] == ST_WALK or FSTATE[def] == ST_CROUCH)
  local crouching = (FSTATE[def] == ST_CROUCH)
  local can_block = grounded and holding_back(def) == 1
  if can_block and low == 1 and not crouching then can_block = false end
  if can_block and high == 1 and crouching then can_block = false end
  if can_block then
    FSTATE[def] = ST_BLOCK; FTIMER[def] = 12
    FVX[def] = 0 - FFACE[def] * 32
    if FMETER[def] < METER_MAX - 3 then FMETER[def] = FMETER[def] + 3 else FMETER[def] = METER_MAX end
    set_script(def, SC_BLOCK)
    return 0
  end
  if FHP[def] > dmg then FHP[def] = FHP[def] - dmg else FHP[def] = 0 end
  FSTATE[def] = ST_HIT; FTIMER[def] = stun
  FVX[def] = 0 - FFACE[def] * 40
  if FY[def] < 0 then FVY[def] = -48 end
  FFLASH[def] = 6
  if FMETER[att] < METER_MAX - 12 then FMETER[att] = FMETER[att] + 12 else FMETER[att] = METER_MAX end
  if FMETER[def] < METER_MAX - 6 then FMETER[def] = FMETER[def] + 6 else FMETER[def] = METER_MAX end
  if slot == 1 then set_script(def, SC_HEADSNAP) elseif slot == 3 then set_script(def, SC_STAGGER) else set_script(def, SC_GUT) end
  if FHP[def] == 0 then
    FSTATE[def] = ST_KO; FTIMER[def] = 0; FVY[def] = -80; FVX[def] = 0 - FFACE[def] * 48
    set_script(def, SC_KO)
  end
  return 1
end

function physics(i)
  FX[i] = FX[i] + FVX[i]
  if FY[i] < 0 or FVY[i] ~= 0 then
    FVY[i] = FVY[i] + CH_GRAV[FCHAR[i]]
    if FVY[i] > 255 then FVY[i] = 255 end
    FY[i] = FY[i] + FVY[i]
    if FY[i] >= 0 then
      FY[i] = 0; FVY[i] = 0
      if FSTATE[i] == ST_JUMP or (FSTATE[i] == ST_ATTACK and M_FLAGS[FMOVE[i]] % 8 >= 4) then
        FSTATE[i] = ST_IDLE; FVX[i] = 0; set_script(i, SC_IDLE)
      end
    end
  end
  if FX[i] < 256 then FX[i] = 256 end
  if FX[i] > 3840 then FX[i] = 3840 end
end

function update_fighter(i, j)
  local st = FSTATE[i]
  if FFLASH[i] > 0 then FFLASH[i] = FFLASH[i] - 1 end
  step_script(i)
  if st == ST_KO then
    physics(i)
    if FY[i] >= 0 then FVX[i] = FVX[i] * 13 // 16 end
    return
  end
  if st == ST_WIN then return end
  if st == ST_HIT or st == ST_BLOCK then
    if FTIMER[i] > 0 then FTIMER[i] = FTIMER[i] - 1 end
    physics(i)
    FVX[i] = FVX[i] * 13 // 16
    if FTIMER[i] == 0 and FY[i] >= 0 then FSTATE[i] = ST_IDLE; FVX[i] = 0; set_script(i, SC_IDLE) end
    return
  end
  if st == ST_ATTACK then
    local m = FMOVE[i]
    FTIMER[i] = FTIMER[i] + 1
    if M_LUNGE[m] > 0 and FTIMER[i] <= M_STARTUP[m] + M_ACTIVE[m] then FVX[i] = FFACE[i] * M_LUNGE[m] else FVX[i] = 0 end
    if M_FLAGS[m] % 8 >= 4 then FVX[i] = FFACE[i] * 36 end
    physics(i)
    if FACTIVE[i] == 1 and FHITDONE[i] < M_HITS[m] and FSTATE[j] ~= ST_KO then
      local slot = hit_test(i, j)
      if slot > 0 then
        FHITDONE[i] = FHITDONE[i] + 1
        local dmg = M_DMG[m]
        if M_FLAGS[m] % 32 >= 16 then dmg = dmg * CH_PMUL[FCHAR[i]] // 16 else dmg = dmg * CH_KMUL[FCHAR[i]] // 16 end
        local low = M_FLAGS[m] % 2
        local high = (M_FLAGS[m] // 2) % 2
        take_hit(i, j, dmg, M_STUN[m], slot, low, high)
        FACTIVE[i] = 0
      end
    end
    if FSTATE[i] == ST_ATTACK and M_FLAGS[m] % 8 < 4 and FTIMER[i] >= M_STARTUP[m] + M_ACTIVE[m] + M_RECOVER[m] then
      FSTATE[i] = ST_IDLE; FVX[i] = 0; set_script(i, SC_IDLE)
    end
    return
  end
  if st == ST_JUMP then
    physics(i)
    if IN_PUNCH[i] == 1 then start_move(i, MV_JPUNCH) elseif IN_KICK[i] == 1 then start_move(i, MV_JKICK) end
    return
  end
  -- grounded: face the opponent, read the pad
  if FX[j] > FX[i] then FFACE[i] = 1 else FFACE[i] = -1 end
  FVX[i] = 0
  local c = FCHAR[i]
  local fwd = IN_RIGHT[i]
  if FFACE[i] == -1 then fwd = IN_LEFT[i] end
  if IN_SUPER[i] == 1 and FMETER[i] >= METER_MAX then
    FMETER[i] = 0; FSTATE[i] = ST_SUPER; FTIMER[i] = 0; FHITDONE[i] = 0; set_script(i, SC_SUPER)
  elseif IN_KICK[i] == 1 and IN_DOWN[i] == 1 then start_move(i, CH_LOWK[c])
  elseif IN_PUNCH[i] == 1 and IN_DOWN[i] == 1 then start_move(i, CH_LOWP[c])
  elseif IN_PUNCH[i] == 1 and fwd == 1 then start_move(i, CH_FWDP[c])
  elseif IN_KICK[i] == 1 and fwd == 1 then start_move(i, CH_FWDK[c])
  elseif IN_PUNCH[i] == 1 then start_move(i, pick_move(i, 1))
  elseif IN_KICK[i] == 1 then start_move(i, pick_move(i, 2))
  elseif IN_UP[i] == 1 then
    FSTATE[i] = ST_JUMP; FVY[i] = CH_JUMP[c]
    if IN_LEFT[i] == 1 then FVX[i] = -38 elseif IN_RIGHT[i] == 1 then FVX[i] = 38 end
    set_script(i, SC_JUMP)
    physics(i)
  elseif IN_DOWN[i] == 1 then
    if st ~= ST_CROUCH then set_script(i, SC_CROUCH) end
    FSTATE[i] = ST_CROUCH
  elseif IN_LEFT[i] == 1 or IN_RIGHT[i] == 1 then
    if st ~= ST_WALK then set_script(i, SC_WALK) end
    FSTATE[i] = ST_WALK
    local dir = 1
    if IN_LEFT[i] == 1 then dir = -1 end
    if dir == FFACE[i] then FVX[i] = dir * CH_WALK[c] else FVX[i] = dir * CH_WALKBACK[c] end
    physics(i)
  else
    if st ~= ST_IDLE then set_script(i, SC_IDLE) end
    FSTATE[i] = ST_IDLE
  end
end

-- ---------------------------------------------------------------- input
function read_pads()
  IN_LEFT[1] = 0; IN_RIGHT[1] = 0; IN_UP[1] = 0; IN_DOWN[1] = 0; IN_PUNCH[1] = 0; IN_KICK[1] = 0; IN_SUPER[1] = 0
  if pad.left then IN_LEFT[1] = 1 end
  if pad.right then IN_RIGHT[1] = 1 end
  if pad.up then IN_UP[1] = 1 end
  if pad.down then IN_DOWN[1] = 1 end
  local y, x, b, a = 0, 0, 0, 0
  if pad.y then y = 1 end
  if pad.x then x = 1 end
  if pad.b then b = 1 end
  if pad.a then a = 1 end
  if (y == 1 and PREV_Y == 0) or (x == 1 and PREV_X == 0) then IN_PUNCH[1] = 1 end
  if b == 1 and PREV_B == 0 then IN_KICK[1] = 1 end
  if a == 1 and PREV_A == 0 then IN_SUPER[1] = 1 end
  PREV_Y = y; PREV_X = x; PREV_B = b; PREV_A = a
end

function cpu_input(i, j)
  IN_LEFT[i] = 0; IN_RIGHT[i] = 0; IN_UP[i] = 0; IN_DOWN[i] = 0; IN_PUNCH[i] = 0; IN_KICK[i] = 0; IN_SUPER[i] = 0
  local d = FX[j] - FX[i]
  if d < 0 then d = 0 - d end
  d = d // 16
  if AI_T > 0 then AI_T = AI_T - 1 end
  if AI_T == 0 then
    local r = rnd8()
    if FMETER[i] >= METER_MAX and d < 150 and r < 100 then AI_PLAN = 8; AI_T = 4
    elseif FSTATE[j] == ST_ATTACK and d < 60 and r < 100 then AI_PLAN = 2; AI_T = 18
    elseif d > 44 then
      if r < 160 then AI_PLAN = 1; AI_T = 10 + rnd8() % 16
      elseif r < 190 and d > 90 then AI_PLAN = 5; AI_T = 10
      elseif r < 220 then AI_PLAN = 7; AI_T = 12
      else AI_PLAN = 0; AI_T = 10 end
    else
      if r < 80 then AI_PLAN = 3; AI_T = 8
      elseif r < 150 then AI_PLAN = 4; AI_T = 10
      elseif r < 180 then AI_PLAN = 6; AI_T = 10
      elseif r < 210 then AI_PLAN = 2; AI_T = 14
      elseif r < 230 then AI_PLAN = 9; AI_T = 12
      else AI_PLAN = 0; AI_T = 8 end
    end
  end
  local fwd_right = (FX[j] > FX[i])
  local p = AI_PLAN
  if p == 1 then if fwd_right then IN_RIGHT[i] = 1 else IN_LEFT[i] = 1 end
  elseif p == 2 or p == 9 then if fwd_right then IN_LEFT[i] = 1 else IN_RIGHT[i] = 1 end
  elseif p == 5 then IN_UP[i] = 1; if fwd_right then IN_RIGHT[i] = 1 else IN_LEFT[i] = 1 end; AI_PLAN = 10
  elseif p == 10 then if FY[i] < -320 and d < 60 then IN_KICK[i] = 1 end
  elseif p == 3 then if AI_T == 7 then IN_PUNCH[i] = 1 end
  elseif p == 4 then if AI_T == 9 then IN_KICK[i] = 1 end
  elseif p == 6 then IN_DOWN[i] = 1; if AI_T == 9 then IN_KICK[i] = 1 end
  elseif p == 7 then IN_DOWN[i] = 1
  elseif p == 8 then if AI_T == 3 then IN_SUPER[i] = 1 end end
end

-- ---------------------------------------------------------------- drawing
-- Each slot owns a 64x64 window of 64 tiles (8x8 tiles, 16 per row => tiles base, base+1.. base+7, base+16..).
-- stream_cell copies one 64x64 cell (2 KB) of the character sheet into the window; see sprites.lua.
-- ---------------------------------------------------------------- sprites (SF2T: per-pose tile window + piece list)
-- Fighter i owns window columns 8*(i-1)..8*(i-1)+7 of OBJ tile rows 0..5. upload_window copies the pose's
-- 768 words when the shown cell changes; only that update pays for it.
function upload_window(i)
  local k = FCELL[i]
  local col0 = (i - 1) * 8
  for r = 0, SPR_ROWS - 1 do
    for c = 0, SPR_COLS - 1 do
      local dst = OBJ_BASE + (r * 16 + col0 + c) * 16
      local src = (r * SPR_COLS + c) * 16
      for w = 0, 15 do
        vram[dst + w] = pose_word(i, k, src + w + 1)
      end
    end
  end
end

function draw_fighters()
  for i = 1, 2 do
    if FSHOWN[i] ~= FCELL[i] then upload_window(i); FSHOWN[i] = FCELL[i] end
    local idx = (i - 1) * NCELL + FCELL[i] + 1
    local p0 = PC_START[idx]
    local n = PC_N[idx]
    local ox = FX[i] // 16 - 32
    local oy = FLOOR + FY[i] // 16 - 64
    local hidden = (FFLASH[i] > 0 and FFLASH[i] % 2 == 1)
    for j = 0, 23 do
      local o = (i - 1) * 24 + j
      if j < n then
        local p = p0 + j
        local size = 8
        if PC_BIG[p] == 1 then size = 16 end
        local px = PC_X[p]
        if FFACE[i] == -1 then px = 64 - px - size end
        obj[o].x = ox + px
        obj[o].y = oy + PC_Y[p]
        obj[o].tile = PC_TILE[p] + (i - 1) * 8
        obj[o].large = (size == 16)
        obj[o].flip_x = (FFACE[i] == -1)
        obj[o].pal = i - 1
        obj[o].prio = 2
        obj[o].on = not hidden
      else
        obj[o].on = false
      end
    end
  end
end

-- ---------------------------------------------------------------- HUD as sprites (font glyphs: A=1..Z=26, 0-9 = 27..36)
function hud_obj(o, x, y, g)
  obj[o].x = x
  obj[o].y = y
  obj[o].tile = FONT_TILE + g
  obj[o].pal = 2
  obj[o].prio = 3
  obj[o].large = false
  obj[o].on = (g > 0)
end
function setup_hud()
  for i = 1, 8 do
    hud_obj(HUD_OBJ + i - 1, 8 + i * 8, 16, CH_NAME[(FCHAR[1] - 1) * 8 + i])
    hud_obj(HUD_OBJ + 7 + i, 184 + i * 8, 16, CH_NAME[(FCHAR[2] - 1) * 8 + i])
  end
end
function draw_hud()
  local h1 = (FHP[1] + 7) // 8
  local h2 = (FHP[2] + 7) // 8
  for i = 0, 11 do
    local g1 = 44
    if i < h1 then g1 = 43 end
    local g2 = 44
    if i < h2 then g2 = 43 end
    hud_obj(HUD_OBJ + 16 + i, 96 - i * 8, 8, g1)
    hud_obj(HUD_OBJ + 28 + i, 152 + i * 8, 8, g2)
  end
  local m1 = FMETER[1] // 16
  local m2 = FMETER[2] // 16
  for i = 0, 5 do
    local g1 = 46
    if i < m1 then g1 = 45 end
    local g2 = 46
    if i < m2 then g2 = 45 end
    hud_obj(HUD_OBJ + 40 + i, 96 - i * 8, 24, g1)
    hud_obj(HUD_OBJ + 46 + i, 152 + i * 8, 24, g2)
  end
  hud_obj(HUD_OBJ + 52, 120, 16, 27 + CLOCK // 10)
  hud_obj(HUD_OBJ + 53, 128, 16, 27 + CLOCK % 10)
end

function init()
  bg[1].char_base = STAGE.char
  bg[1].map_base = STAGE_MAP
  -- sky rows 0..21 tile 1, ground line row 22 tile 2, floor rows 23..27 tile 3 (stage sheet tiles 0..15)
  for row = 0, 27 do
    for col = 0, 31 do
      local tile = 1
      if row == 22 then tile = 2 elseif row > 22 then tile = 3 end
      vram[STAGE_MAP + row * 32 + col] = tile
    end
  end
  screen.main.bg1 = true
  screen.main.obj = true
  obj.char_base = OBJ_BASE
  obj.size_sel = 0             -- small 8x8, large 16x16
  for i = 1, 15 do
    cgram[128 + i] = SPR_PAL_1[i]
    cgram[144 + i] = SPR_PAL_2[i]
  end
  upload_window(1)
  upload_window(2)
  FSHOWN[1] = FCELL[1]
  FSHOWN[2] = FCELL[2]
  set_script(1, SC_IDLE)
  set_script(2, SC_IDLE)
  setup_hud()
end

function frame(t, f)
  FRAME = FRAME + 1
  read_pads()
  cpu_input(2, 1)
  update_fighter(1, 2)
  update_fighter(2, 1)
  separate()
  if FRAME % 60 == 0 and CLOCK > 0 then CLOCK = CLOCK - 1 end
  draw_fighters()
  draw_hud()
end
