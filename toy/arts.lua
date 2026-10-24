-- arts.lua: martial arts. Every baby fights a real style with its own move list, and strikes come from
-- both sides of the body. Runs after select.lua.
--  * ~30 new poses (straight, back fist, elbow, double palm, tiger claw, haymaker, side/axe/front/crescent
--    kicks, flying kick and knee, headbutt, belly bump, cartwheel, stomp, lariat, chain punches, bear hug ...)
--  * each strike gets the 7-frame smooth.lua schedule (two wind-ups, over-extension, hit, three recoveries)
--  * organic attacks: the punch and kick buttons cycle through the character's own list, never the same
--    move twice in a row, and a landed hit can be chained into any other move of the style (up to 5 hits)
--  * extras per move: lunge (body travels on the active frames), hop (leaves the ground), spin (the sprite
--    turns around on the wind-up), multi-hit chains, stomp shockwave
--  * Teddy the bear is a wrestler: punch inside hugging range is a BEAR HUG that squeezes three times and tosses
--  * per-character guard stances with the hands up, and a 4-frame idle cycle (weight shift / hand bob)
--  * the select screen shows the style name under the baby's name
local S, OX, OY = 1.8, 3.2, 7.2
local function P(neck, hip, barm, farm, bleg, fleg, extra)
  local p = { neck = neck, hip = hip, barm = barm, farm = farm, bleg = bleg, fleg = fleg }
  if extra ~= nil then for k, v in pairs(extra) do p[k] = v end end
  return p
end
local G_B, G_F = {{10,17},{12,13}}, {{20,16},{22,12}}       -- guard arms (back, front)
local L_B, L_F = {{9,27},{8,31}}, {{19,27},{20,31}}         -- planted legs
local W_B, W_F = {{8,27},{6,31}}, {{21,27},{24,31}}         -- wide stance legs

POSE_STRAIGHT, POSE_BACKFIST, POSE_ELBOW, POSE_PALM, POSE_CLAW, POSE_HAYMAKER = 48, 49, 50, 51, 52, 53
POSE_SIDEKICK, POSE_AXEKICK, POSE_FRONTKICK, POSE_CRESCENT, POSE_FLYKNEE, POSE_HEADBUTT = 54, 55, 56, 57, 58, 59
POSE_HUG, POSE_BUMP, POSE_COMPASSO, POSE_STOMP, POSE_LARIAT, POSE_CHAIN1, POSE_CHAIN2 = 60, 61, 62, 63, 64, 65, 66
POSE_GUT, POSE_HEADSNAP, POSE_STAGGER = 67, 68, 69
POSE_FLEX, POSE_SIT, POSE_BOW, POSE_STRETCH, POSE_FLAP, POSE_PUMP, POSE_HUGWIN, POSE_SQUEEZE = 70, 71, 72, 73, 74, 75, 76, 77
POSES[48] = P({17,13}, {14,22}, {{11,17},{13,13}}, {{24,14},{31,13}}, W_B, W_F, { expr = "yell" })
POSES[49] = P({16,13}, {14,22}, {{20,13},{29,10}}, {{12,17},{10,14}}, W_B, W_F, { expr = "yell" })
POSES[50] = P({17,13}, {14,22}, {{11,17},{13,14}}, {{25,13},{21,11}}, L_B, W_F, { expr = "yell" })
POSES[51] = P({16,13}, {14,22}, {{22,16},{29,15}}, {{24,15},{30,13}}, W_B, W_F, { expr = "yell" })
POSES[52] = P({16,12}, {14,22}, {{10,17},{12,13}}, {{22,8},{29,11}},  L_B, W_F, { expr = "yell" })
POSES[53] = P({15,13}, {13,22}, {{10,18},{12,14}}, {{20,9},{28,7}},   W_B, W_F, { expr = "yell" })
POSES[54] = P({11,13}, {13,21}, {{6,16},{4,13}},   {{17,16},{15,12}}, L_B, {{22,20},{31,20}}, { expr = "yell" })
POSES[55] = P({13,12}, {14,21}, {{8,16},{6,12}},   {{19,16},{21,12}}, L_B, {{22,8},{30,16}},  { expr = "yell" })
POSES[56] = P({13,13}, {14,21}, {{8,17},{10,13}},  {{19,17},{21,13}}, L_B, {{21,18},{30,19}}, { expr = "yell" })
POSES[57] = P({12,14}, {14,22}, {{7,16},{5,12}},   {{18,16},{16,12}}, L_B, {{21,14},{30,8}},  { expr = "yell" })
POSES[58] = P({14,12}, {14,21}, {{8,16},{10,12}},  {{19,16},{21,11}}, {{10,26},{8,31}}, {{20,17},{18,22}}, { expr = "yell" })
POSES[59] = P({19,15}, {14,22}, {{10,19},{13,22}}, {{22,19},{26,22}}, W_B, W_F, { headoff = {3,1}, expr = "yell" })
POSES[60] = P({15,13}, {14,22}, {{23,14},{27,19}}, {{24,15},{27,20}}, W_B, W_F, { expr = "grit" })
POSES[61] = P({17,13}, {17,22}, {{8,17},{6,20}},   {{10,18},{8,22}},  W_B, W_F, { expr = "yell" })
POSES[62] = P({12,16}, {15,21}, {{10,20},{7,25}},   {{8,22},{5,28}},   {{10,27},{8,31}}, {{22,16},{31,10}}, { expr = "yell" })   -- meia lua de compasso: hand on the floor, leg high
POSES[63] = P({14,12}, {14,21}, {{8,16},{5,13}},   {{20,16},{23,13}}, L_B, {{20,20},{22,24}}, { expr = "yell" })
POSES[64] = P({15,13}, {14,22}, {{8,14},{3,12}},   {{22,13},{31,12}}, W_B, W_F, { expr = "yell" })
POSES[65] = P({16,13}, {14,22}, {{16,16},{18,13}}, {{23,15},{30,14}}, W_B, W_F, { expr = "yell" })
POSES[66] = P({16,13}, {14,22}, {{22,15},{29,14}}, {{16,16},{18,13}}, W_B, W_F, { expr = "yell" })
POSES[67] = P({16,17}, {13,23}, {{10,22},{12,19}}, {{19,22},{21,19}}, {{9,28},{7,31}}, {{19,28},{21,31}}, { headoff = {2,2}, hurt = true, expr = "oof" })
POSES[68] = P({11,13}, {14,22}, {{6,15},{3,11}},   {{20,16},{25,11}}, {{10,27},{8,31}}, {{18,27},{20,31}}, { headoff = {-3,-1}, hurt = true })
POSES[69] = P({13,15}, {13,24}, {{8,21},{6,25}},   {{19,21},{22,25}}, {{7,28},{5,31}}, {{20,27},{24,31}}, { hurt = true, expr = "oof" })
POSES[70] = P({14,13}, {14,22}, {{7,14},{8,8}},    {{21,14},{20,8}},  W_B, W_F, { expr = "happy" })
POSES[71] = P({14,16}, {14,24}, {{9,21},{8,26}},   {{19,21},{20,26}}, {{10,28},{6,31}}, {{18,28},{22,31}}, { expr = "happy" })
POSES[72] = P({18,16}, {14,22}, {{9,20},{8,25}},   {{19,20},{20,25}}, {{12,27},{12,31}}, {{16,27},{16,31}}, { headoff = {3,2}, expr = "blink" })
POSES[73] = P({14,16}, {14,24}, {{9,21},{8,26}},   {{19,17},{17,12}}, {{10,28},{6,31}}, {{18,28},{22,31}}, { expr = "happy" })   -- sitting, paw to the face
POSES[74] = P({14,13}, {14,22}, {{7,12},{3,8}},    {{21,12},{25,8}},  L_B, L_F, { expr = "happy" })
POSES[75] = P({14,13}, {14,22}, {{9,17},{11,14}},  {{21,12},{23,6}},  W_B, W_F, { expr = "happy" })
POSES[76] = P({15,13}, {14,22}, {{8,16},{9,10}},   {{20,16},{19,10}}, W_B, W_F, { expr = "happy" })
POSES[77] = P({16,14}, {14,22}, {{23,15},{26,20}}, {{25,16},{26,21}}, W_B, W_F, { expr = "grit" })
for _, id in ipairs({ 3, 4, 11, 12, 13, 14, 15, 16, 17 }) do POSES[id].expr = "yell" end
POSES[10].expr = "yell"; POSES[9].expr = "ko"; POSES[8].expr = "grit"; POSES[6].expr = "grit"

-- guard stances: hands up by the chin, feet set. (arms = {back, front}, body = {neck, hip}, legs = {back, front})
STANCE = {
  { barm = {{10,17},{11,12}}, farm = {{21,16},{23,11}} },                                            -- Brandon: boxing guard
  { barm = {{9,18},{7,14}},   farm = {{21,18},{25,14}}, neck = {15,14}, hip = {13,23}, bleg = {{8,27},{5,31}}, fleg = {{20,27},{24,31}} },  -- Arlo: ginga, arms loose
  { barm = {{11,17},{14,13}}, farm = {{20,15},{24,11}}, neck = {14,14}, hip = {14,22} },             -- Dawn: wing chun, hands on the centre line
  { barm = {{7,19},{5,15}},   farm = {{21,19},{23,15}}, neck = {15,13}, hip = {15,23}, bleg = {{6,27},{4,31}}, fleg = {{23,27},{26,31}} },  -- Chris: sumo, feet planted wide
  { barm = {{8,17},{6,12}},   farm = {{20,16},{23,11}}, neck = {13,13}, hip = {14,22}, bleg = {{10,27},{9,31}}, fleg = {{19,26},{22,30}} }, -- Isaac: taekwondo, light on the front foot
  { barm = {{9,19},{10,14}},  farm = {{21,18},{25,13}}, neck = {14,14}, hip = {14,22}, bleg = {{7,27},{5,31}}, fleg = {{21,27},{24,31}} },  -- Teddy: wrestler, arms open
  { barm = {{10,18},{12,12}}, farm = {{19,17},{20,11}}, neck = {14,14}, hip = {14,23}, bleg = {{9,28},{7,31}}, fleg = {{19,27},{21,30}} },  -- Pip: muay thai, tall guard
  { barm = {{9,18},{7,15}},   farm = {{21,17},{26,14}}, neck = {14,15}, hip = {14,23}, bleg = {{8,28},{5,31}}, fleg = {{20,28},{23,31}} },  -- Blue: karate, long front hand
}
-- idle cycle: a second stance frame per baby (hands bob, weight shifts) and the lerp between them
local function merged_idle(ci)
  local m = {}
  for k, v in pairs(POSES[0]) do m[k] = v end
  for k, v in pairs(STANCE[ci]) do m[k] = v end
  return m
end
local function shift(pt, dx, dy) return { pt[1] + dx, pt[2] + dy } end
IDLE2 = {}
for ci = 1, 8 do
  local m = merged_idle(ci)
  local p = {}
  for k, v in pairs(m) do p[k] = v end
  p.barm = { shift(m.barm[1], 1, -1), shift(m.barm[2], 1, -1) }
  p.farm = { shift(m.farm[1], -1, 1), shift(m.farm[2], -1, 1) }
  p.neck = shift(m.neck, (ci == 2) and 2 or 1, 0)
  p.hip = shift(m.hip, (ci == 2) and 1 or 0, 0)
  POSES[80 + ci] = p
  IDLE2[ci] = 80 + ci
end

local next_id = 90
local function anim_id(a, b, t, extra)
  local id = next_id
  next_id = next_id + 1
  ANIM_POSE[id] = { a = a, b = b, t = t }
  if extra ~= nil then for k, v in pairs(extra) do ANIM_POSE[id][k] = v end end
  return id
end
IDLE_MID = {}
for ci = 1, 8 do IDLE_MID[ci] = anim_id(0, 80 + ci, 0.5, nil) end
BLINK_POSE = anim_id(0, 0, 0, { expr = "blink" })

-- ---------------------------------------------------------------- the moves
local function ATK(pose, s, a, r, dmg, stun, x0, x1, y0, y1, extra)
  local t = { startup = s, active = a, recover = r, dmg = dmg, stun = stun, pose = pose, x0 = x0, x1 = x1, y0 = y0, y1 = y1 }
  if extra ~= nil then for k, v in pairs(extra) do t[k] = v end end
  return t
end
ATTACKS.straight  = ATK(POSE_STRAIGHT,  4, 5, 9,  8,  15, 38, 66, 18, 32, { punch = true, lunge = 1 })
ATTACKS.backfist  = ATK(POSE_BACKFIST,  7, 5, 12, 10, 18, 36, 66, 8,  26, { punch = true, spin = true })
ATTACKS.elbow     = ATK(POSE_ELBOW,     5, 5, 10, 9,  16, 36, 58, 14, 30, { punch = true })
ATTACKS.palm      = ATK(POSE_PALM,      5, 6, 12, 11, 18, 38, 68, 16, 34, { punch = true, lunge = 1.5 })
ATTACKS.claw      = ATK(POSE_CLAW,      6, 6, 12, 10, 18, 36, 64, 6,  30, { punch = true, high = true })
ATTACKS.haymaker  = ATK(POSE_HAYMAKER,  9, 6, 16, 14, 24, 34, 66, 4,  30, { punch = true, high = true })
ATTACKS.sidekick  = ATK(POSE_SIDEKICK,  7, 7, 13, 12, 18, 40, 70, 20, 38, {})
ATTACKS.axekick   = ATK(POSE_AXEKICK,   9, 6, 16, 14, 22, 38, 66, 2,  30, { high = true })
ATTACKS.frontkick = ATK(POSE_FRONTKICK, 5, 6, 11, 9,  16, 38, 68, 22, 40, {})
ATTACKS.crescent  = ATK(POSE_CRESCENT,  8, 7, 14, 13, 20, 38, 68, 4,  28, { high = true, spin = true })
ATTACKS.flykick   = ATK(POSE_SIDEKICK,  6, 10, 10, 13, 22, 40, 70, 14, 40, { hop = -4.5, lunge = 2.5 })
ATTACKS.flyknee   = ATK(POSE_FLYKNEE,   5, 10, 10, 12, 20, 36, 58, 14, 40, { hop = -5, lunge = 2.2 })
ATTACKS.headbutt  = ATK(POSE_HEADBUTT,  6, 5, 12, 10, 18, 34, 58, 4,  24, { lunge = 1.5 })
ATTACKS.bump      = ATK(POSE_BUMP,      6, 8, 14, 12, 22, 30, 60, 10, 50, { lunge = 2.5 })
ATTACKS.cartwheel = ATK(POSE_COMPASSO,  8, 8, 14, 13, 22, 32, 70, 0,  34, { lunge = 2, spin = true, high = true })
ATTACKS.stomp     = ATK(POSE_STOMP,     7, 4, 14, 10, 18, 36, 60, 44, 64, { low = true, shock = true })
ATTACKS.lariat    = ATK(POSE_LARIAT,    7, 6, 14, 13, 22, 40, 72, 10, 28, { punch = true, lunge = 2 })
ATTACKS.blast     = ATK(POSE_CHAIN1,    4, 12, 10, 5, 10, 38, 64, 16, 32, { punch = true, hits = 3, rehit = 4, alt = POSE_CHAIN2, lunge = 1 })
ATTACKS.hug       = ATK(POSE_HUG,       6, 4, 16, 4,  0,  34, 62, 10, 50, { grab = true })
for _, name in ipairs({ "straight", "backfist", "elbow", "palm", "claw", "haymaker", "sidekick", "axekick", "frontkick",
                        "crescent", "flykick", "flyknee", "headbutt", "bump", "cartwheel", "stomp", "lariat", "blast", "hug" }) do
  local a = ATTACKS[name]
  local from = a.low and 5 or 0
  a.w1 = anim_id(from, a.pose, 0.28, nil)
  a.w2 = anim_id(from, a.pose, 0.68, nil)
  a.over = anim_id(from, a.pose, 1.12, nil)
  a.r1 = a.w2
  a.r2 = anim_id(from, a.pose, 0.42, nil)
  a.r3 = anim_id(from, a.pose, 0.16, nil)
  a.windup = a.w1; a.recov = a.r2
end
ATTACKS.blast.w1 = ATTACKS.blast.w2

MOVENAME = {
  jab = "JAB", cross = "CROSS", hook = "HOOK", upper = "UPPERCUT", straight = "STRAIGHT", backfist = "BACK FIST", elbow = "ELBOW",
  palm = "PALM THRUST", claw = "TIGER CLAW", haymaker = "HAYMAKER", kick = "KICK", highkick = "HIGH KICK", roundhouse = "ROUNDHOUSE",
  knee = "KNEE", sweep = "SWEEP", sidekick = "SIDE KICK", axekick = "AXE KICK", frontkick = "FRONT KICK", crescent = "CRESCENT KICK",
  flykick = "FLYING KICK", flyknee = "FLYING KNEE", headbutt = "HEADBUTT", bump = "BELLY BUMP", cartwheel = "MEIA LUA KICK",
  stomp = "STOMP", lariat = "LARIAT", blast = "CHAIN PUNCH", hug = "BEAR HUG",
}
ART = {
  { style = "BOXING-JKD", punches = { "jab", "cross", "hook", "straight", "upper" }, kicks = { "sidekick", "kick", "frontkick" },
    fwdP = "blast", fwdK = "sidekick", lowK = "sweep", lowP = "upper" },
  { style = "CAPOEIRA", punches = { "backfist", "elbow", "palm" }, kicks = { "crescent", "cartwheel", "frontkick", "highkick" },
    fwdP = "elbow", fwdK = "cartwheel", lowK = "sweep", lowP = "backfist" },
  { style = "KUNG FU", punches = { "blast", "claw", "backfist", "straight" }, kicks = { "crescent", "frontkick", "sidekick" },
    fwdP = "claw", fwdK = "flykick", lowK = "sweep", lowP = "claw" },
  { style = "SUMO", punches = { "palm", "haymaker", "bump" }, kicks = { "stomp", "knee", "frontkick" },
    fwdP = "bump", fwdK = "stomp", lowK = "stomp", lowP = "palm" },
  { style = "TAEKWONDO", punches = { "jab", "backfist" }, kicks = { "axekick", "sidekick", "crescent", "frontkick", "roundhouse" },
    fwdP = "backfist", fwdK = "flykick", lowK = "sweep", lowP = "jab" },
  { style = "WRESTLING", punches = { "haymaker", "lariat", "headbutt" }, kicks = { "knee", "stomp", "kick" },
    fwdP = "lariat", fwdK = "knee", lowK = "stomp", lowP = "haymaker" },
  { style = "MUAY THAI", punches = { "elbow", "jab", "upper" }, kicks = { "knee", "flyknee", "frontkick", "roundhouse" },
    fwdP = "elbow", fwdK = "flyknee", lowK = "sweep", lowP = "upper" },
  { style = "KARATE", punches = { "straight", "backfist", "claw" }, kicks = { "frontkick", "sidekick", "roundhouse" },
    fwdP = "straight", fwdK = "sidekick", lowK = "sweep", lowP = "straight" },
}

local function pick_from(f, pool)
  local n = #pool
  if n == 1 then return pool[1] end
  local cur = f.lastmove
  local idx = 1 + floor(rnd() * n)
  if pool[idx] == cur then idx = idx % n + 1 end
  return pool[idx]
end

function begin_move(f, name, step)
  local a = ATTACKS[name]
  f.state = "attack"; f.atk = a; f.timer = 1; f.hitdone = 0; f.mhits = 1; f.combo = step
  f.pose = a.w1 or a.pose
  f.vx = 0
  f.crouch = (a.low == true)
  f.lastmove = name
  f.lasthit = 0
  if a.hop ~= nil then f.vy = a.hop end
  sfx(SND_WHIFF, 7, (a.hop ~= nil or a.spin == true) and "E5" or "C5")
end

-- ---------------------------------------------------------------- bear hug (Teddy)
local function start_hug(f, opp)
  f.state = "hug"; f.timer = 0; f.grabbed = false; f.pose = ATTACKS.hug.w1; f.vx = 0; f.crouch = false
  f.lastmove = "hug"
  sfx(SND_WHIFF, 7, "G4")
end
local function hug_update(f, opp)
  f.timer = f.timer + 1
  local t = f.timer
  if not f.grabbed then
    if t <= 3 then f.pose = ATTACKS.hug.w1 elseif t <= 6 then f.pose = ATTACKS.hug.w2 else f.pose = POSE_HUG end
    if t == 7 then
      local d = abs(opp.x - f.x)
      local ok = d < 46 and opp.state ~= "ko" and opp.state ~= "hug" and opp.y >= FLOOR_Y - 10 and abs(opp.y - f.y) < 20
      if ok then
        f.grabbed = true
        opp.state = "held"; opp.timer = 0; opp.pose = POSE_HEADSNAP; opp.crouch = false; opp.vx = 0; opp.vy = 0; opp.y = FLOOR_Y
        opp.face = -f.face
        ROUND.callout = "BEAR HUG!"; ROUND.callout_t = 40
        if play_voice ~= nil then play_voice(f, "special") end
      end
    end
    if t >= 24 then f.state = "idle"; f.pose = POSE_IDLE; f.timer = 0 end
    return
  end
  -- squeezing: the victim is pinned in front of the bear
  opp.x = f.x + f.face * 30
  if opp.x < -8 then opp.x = -8; f.x = opp.x - f.face * 30 elseif opp.x > 200 then opp.x = 200; f.x = opp.x - f.face * 30 end
  local k = t - 7
  if k % 14 == 0 and k <= 42 then
    f.pose = POSE_SQUEEZE
    opp.hp = max(0, opp.hp - 5)
    opp.flash = 6
    f.meter = min(METER_MAX, f.meter + 6)
    spawn_spark(opp.x + 32, opp.y + 28, 8)
    sfx(SND_DEEP, 7, "C2"); sfx(SND_CRACK, 6, "E3")
    HITSTOP = 3
    if play_voice ~= nil and rnd() < 0.5 then play_voice(opp, "hit") end
    if opp.hp <= 0 then
      opp.state = "ko"; opp.timer = 0; opp.pose = POSE_KO; opp.vy = -5; opp.vx = opp.face * -3.5
      if ko_sound ~= nil then ko_sound(opp) end
      f.state = "idle"; f.pose = POSE_IDLE; f.timer = 0
      return
    end
  elseif k % 14 == 7 then
    f.pose = POSE_HUG
  end
  if k >= 50 then
    -- the toss
    opp.state = "hit"; opp.timer = 26; opp.pose = POSE_HIT; opp.vx = -opp.face * 6; opp.vy = -6; opp.y = FLOOR_Y - 1
    opp.react = nil
    f.state = "idle"; f.pose = POSE_IDLE; f.timer = 0
    sfx(SND_KO, 4, "G4")
  end
end

local function grounded(f) return f.state == "idle" or f.state == "walk" or f.state == "crouch" end
local function in_hug(f) return f.state == "hug" or f.state == "held" end

local base_update_fighter = update_fighter
function update_fighter(f, opp, allow_input)
  local m = ART[f.char]
  if f.state == "held" then
    if f.flash > 0 then f.flash = f.flash - 1 end
    f.anim = f.anim + 1
    if opp.state ~= "hug" then f.state = "idle"; f.timer = 0 end
    return
  end
  if f.state == "hug" then
    if f.flash > 0 then f.flash = f.flash - 1 end
    f.anim = f.anim + 1
    hug_update(f, opp)
    return
  end
  if allow_input and m ~= nil then
    local inp = f.inp
    local fwd = (f.face == 1) and inp.right or inp.left
    local back = (f.face == 1) and inp.left or inp.right
    local d = abs(opp.x - f.x)
    if grounded(f) then
      if inp.super and f.meter >= METER_MAX then
        -- the super is handled by fight.lua
      elseif inp.punch and inp.down and SPECIAL ~= nil and SPECIAL[f.char] ~= nil then
        -- projectile special, handled by specials.lua
      elseif f.char == 6 and inp.punch and d < 48 and opp.state ~= "ko" and opp.y >= FLOOR_Y - 10 and not in_hug(opp) then
        start_hug(f, opp); inp.punch = false; inp.kick = false
        return
      elseif inp.kick and inp.down then begin_move(f, m.lowK, 1); inp.kick = false
      elseif inp.punch and inp.down then begin_move(f, m.lowP, 1); inp.punch = false
      elseif inp.punch and fwd then begin_move(f, m.fwdP, 1); inp.punch = false
      elseif inp.kick and fwd then begin_move(f, m.fwdK, 1); inp.kick = false
      elseif inp.kick and back then begin_move(f, m.lowK, 1); inp.kick = false
      elseif inp.punch then begin_move(f, pick_from(f, m.punches), 1); inp.punch = false
      elseif inp.kick then begin_move(f, pick_from(f, m.kicks), 1); inp.kick = false
      end
    elseif f.state == "attack" and f.atk ~= nil and f.atk.air == nil and f.atk.shoot == nil then
      if (inp.punch or inp.kick) and f.hitdone >= 1 and f.timer >= f.atk.startup + 1 and (f.combo or 1) < 5 and f.y >= FLOOR_Y then
        local pool = inp.punch and m.punches or m.kicks
        -- organic: a combo drifts between punches and kicks on its own
        if rnd() < 0.3 then pool = inp.punch and m.kicks or m.punches end
        begin_move(f, pick_from(f, pool), (f.combo or 1) + 1)
      end
      inp.punch = false; inp.kick = false
    end
  end
  local was_y = f.y
  base_update_fighter(f, opp, allow_input)
  local a = f.atk
  if f.state == "attack" and a ~= nil and a.w1 ~= nil and ATTACKS[f.lastmove or ""] == a then
    local s, e = a.startup, a.startup + a.active
    if a.lunge ~= nil and f.timer > s // 2 and f.timer <= e then
      local nx = f.x + a.lunge * f.face
      if abs(opp.x - nx) >= 26 or opp.state == "ko" then f.x = nx end   -- travel, but never into the opponent
      if f.x < -8 then f.x = -8 elseif f.x > 200 then f.x = 200 end
    end
    if a.hits ~= nil then
      if f.hitdone >= 1 and f.mhits < a.hits and f.timer <= e and f.timer - (f.lasthit or 0) >= a.rehit then
        f.hitdone = 0; f.mhits = f.mhits + 1
      end
      if f.timer > s and f.timer <= e then
        f.pose = (((f.timer - s) // a.rehit) % 2 == 0) and a.pose or a.alt
      end
    end
    if a.shock == true and f.timer == s + 1 then
      spawn_spark(f.x + 32 + f.face * 14, FLOOR_Y + 72, 11)
      sfx(SND_DEEP, 7, "C2")
    end
  end
  -- a hop that ends in recovery: fall back to the floor (fight.lua runs no physics while idle)
  if (f.state == "idle" or f.state == "crouch") and (f.y < FLOOR_Y or f.vy ~= 0) then
    f.vy = f.vy + GRAVITY
    f.y = f.y + f.vy
    if f.y >= FLOOR_Y then f.y = FLOOR_Y; f.vy = 0 end
  end
  -- idle cycle + blink
  if f.state == "idle" and (f.pose == POSE_IDLE or f.pose == BREATH_POSE) then
    local ph = (f.anim // 14) % 4
    if ph == 1 or ph == 3 then f.pose = IDLE_MID[f.char] elseif ph == 2 then f.pose = IDLE2[f.char] end
    if f.anim % 150 < 5 then f.pose = BLINK_POSE end
  end
end

-- no separation shove while a bear hug is on
local base_separate = separate
function separate(a, b)
  if in_hug(a) or in_hug(b) then return end
  base_separate(a, b)
end

-- the striking hand lands multi-hit timing; the CPU hugs too
local base_apply_hit = apply_hit
function apply_hit(att, def, dmg, stun, low, high, hx, hy, pushback)
  local a = att.atk
  if att.state == "attack" and a ~= nil and a.punch == true then
    local st = STYLE[att.char]
    dmg = floor(dmg * st.pmul / st.kmul + 0.5)   -- combat.lua treats non-jab poses as kicks; undo its multiplier
  end
  local landed = base_apply_hit(att, def, dmg, stun, low, high, hx, hy, pushback)
  if att.state == "attack" then att.lasthit = att.timer end
  return landed
end

-- spinning moves turn the sprite around on the wind-up; shadows follow f.pose on their own
local base_draw_sprites = draw_sprites
function draw_sprites()
  base_draw_sprites()
  if ROUND.state == "select" or ROUND.state == "title" then return end
  for i, f in ipairs({ P1, P2 }) do
    if f ~= nil and f.state == "attack" and f.atk ~= nil and f.atk.spin == true then
      local a = f.atk
      if f.timer <= a.startup // 2 + 1 then obj[i - 1].flip_x = not obj[i - 1].flip_x end
    end
  end
end

-- style name on the select screen
local base_frame = frame
function frame(t, f)
  base_frame(t, f)
  if ROUND.state == "select" and SEL ~= nil and SEL.cursor ~= nil then
    text(14, 22, ART[SEL.cursor].style)
  end
end
