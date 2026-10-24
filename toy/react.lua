-- react.lua: reactions and voices. Runs after arts.lua.
--  * three hit reactions chosen by where the blow lands (head snap, gut fold, leg buckle), each a two-frame recoil
--  * every baby has a voice: a short phrase on special moves, sometimes when hit, a wail on the final blow
--    (with its own impact sound), and a cheer when the round is won
--  * projectiles that meet mid-air cancel each other in a burst ("CLASH!")
--  * win celebrations per baby: fist pumps, sits and wags, flaps, sumo stomps, hops, flexes, a karate bow
local VOX_V = 4
VOX = {
  flute = bank("flute", { adsr = { a = 14, d = 3, s = 6, r = 20 }, vol = 100 }),
  lead  = bank("lead",  { adsr = { a = 15, d = 4, s = 5, r = 20 }, vol = 80 }),
  bass  = bank("bass",  { adsr = { a = 13, d = 3, s = 6, r = 18 }, vol = 127 }),
  pluck = bank("pluck", { vol = 110 }),
  tom   = bank("tom",   { vol = 120 }),
  bell  = bank("bell",  { vol = 90 }),
}
-- phrases: { note, frames } ... ; the voice is keyed off after the last note
VOICE = {
  { inst = "flute", hit = { {"G5",4}, {"E5",6} }, ko = { {"A5",6}, {"G5",6}, {"F5",6}, {"E5",8}, {"D5",10}, {"C5",16} },
    special = { {"C5",4}, {"E5",4}, {"G5",10} }, win = { {"C5",5}, {"E5",5}, {"G5",5}, {"B5",16} }, impact = { "tom", "C3" } },
  { inst = "tom", hit = { {"A5",3}, {"A5",4} }, ko = { {"B5",4}, {"G5",4}, {"E5",6}, {"C5",12} },
    special = { {"C6",3}, {"C6",3}, {"C6",4} }, win = { {"A5",4}, {"A5",4}, {"C6",10} }, impact = { "pluck", "C5" } },
  { inst = "flute", hit = { {"E5",4}, {"G5",5} }, ko = { {"G5",5}, {"A5",5}, {"G5",8}, {"E5",10}, {"C5",14} },
    special = { {"E5",3}, {"G5",3}, {"B5",8} }, win = { {"G5",6}, {"B5",6}, {"A5",12} }, impact = { "pluck", "E5" } },
  { inst = "lead", hit = { {"G5",3}, {"A5",4} }, ko = { {"A5",4}, {"B5",4}, {"A5",4}, {"G5",6}, {"E5",12} },
    special = { {"E5",3}, {"G5",5} }, win = { {"G5",4}, {"A5",4}, {"B5",10} }, impact = { "tom", "C4" } },
  { inst = "tom", hit = { {"E6",3}, {"D6",3} }, ko = { {"E6",3}, {"D6",3}, {"C6",4}, {"B5",6}, {"A5",10} },
    special = { {"E6",2}, {"E6",2}, {"E6",3} }, win = { {"E6",3}, {"G6",3}, {"E6",3}, {"G6",8} }, impact = { "pluck", "G4" } },
  { inst = "bass", hit = { {"C2",6}, {"B1",8} }, ko = { {"E2",6}, {"D2",6}, {"C2",8}, {"B1",10}, {"A1",16} },
    special = { {"C2",4}, {"E2",4}, {"G2",10} }, win = { {"C2",5}, {"E2",5}, {"G2",5}, {"C3",14} }, impact = { "tom", "G2" } },
  { inst = "pluck", hit = { {"G5",2}, {"B5",3} }, ko = { {"B5",3}, {"G5",3}, {"E5",4}, {"C5",10} },
    special = { {"G5",2}, {"B5",2}, {"G5",4} }, win = { {"E5",3}, {"G5",3}, {"B5",3}, {"B5",8} }, impact = { "tom", "E4" } },
  { inst = "lead", hit = { {"C3",1}, {"C#3",1}, {"C3",1}, {"C#3",2} }, ko = { {"E3",2}, {"D#3",2}, {"D3",2}, {"C#3",2}, {"C3",3}, {"B2",3}, {"A#2",3}, {"A2",8} },
    special = { {"G3",1}, {"G#3",1}, {"G3",1}, {"G#3",1}, {"G3",1}, {"G#3",3} }, win = { {"C4",2}, {"E4",2}, {"G4",2}, {"C5",8} }, impact = { "tom", "C5" } },
}
VQ = {}
function play_voice(f, kind)
  local v = VOICE[f.char]
  local phrase = v[kind]
  if phrase == nil then return end
  local inst = VOX[v.inst]
  local at = AMB_F or 0
  VQ = {}
  for _, n in ipairs(phrase) do
    VQ[#VQ + 1] = { at = at, inst = inst, note = n[1] }
    at = at + n[2]
  end
  VQ[#VQ + 1] = { at = at, off = true }
end
local function pump_voice(f)
  local keep = {}
  for _, e in ipairs(VQ) do
    if e.at <= f then
      if e.off == true then koff(VOX_V) else sfx(e.inst, VOX_V, e.note) end
    else
      keep[#keep + 1] = e
    end
  end
  VQ = keep
end
function ko_sound(def)
  if def.ko_done == true then return end
  def.ko_done = true
  local v = VOICE[def.char]
  sfx(VOX[v.impact[1]], 5, v.impact[2])
  sfx(SND_DEEP, 7, "C1")
  play_voice(def, "ko")
end

-- ---------------------------------------------------------------- hit reactions
local base_apply_hit = apply_hit
function apply_hit(att, def, dmg, stun, low, high, hx, hy, pushback)
  local landed = base_apply_hit(att, def, dmg, stun, low, high, hx, hy, pushback)
  if landed then
    if def.state == "hit" and def.y >= FLOOR_Y - 2 then
      local rel = hy - def.y
      local r = rnd()
      local pose
      if rel < 24 then pose = (r < 0.7) and POSE_HEADSNAP or POSE_HIT
      elseif rel < 42 then pose = (r < 0.6) and POSE_GUT or POSE_HIT
      else pose = (r < 0.7) and POSE_STAGGER or POSE_GUT end
      def.pose = pose
      def.react = { pose, POSE_HIT }
      def.react_t = def.timer
      if rnd() < 0.35 then play_voice(def, "hit") end
    end
    if def.state == "ko" then ko_sound(def) end
  end
  return landed
end

local base_update_fighter = update_fighter
function update_fighter(f, opp, allow_input)
  local was = f.state
  base_update_fighter(f, opp, allow_input)
  if f.state == "hit" and f.react ~= nil and f.y >= FLOOR_Y then
    if f.timer > f.react_t * 0.45 then f.pose = f.react[1] else f.pose = f.react[2] end
  elseif f.state ~= "hit" then
    f.react = nil
  end
  if f.state ~= "ko" then f.ko_done = false end
  if was ~= "super" and f.state == "super" then play_voice(f, "special") end
  if was ~= "attack" and f.state == "attack" and f.atk == ATTACKS.shoot then play_voice(f, "special") end
end

-- ---------------------------------------------------------------- projectile clash
local base_update_projectiles = update_projectiles
function update_projectiles(f1, f2)
  local n = #PROJ
  if n >= 2 then
    local dead = {}
    for i = 1, n - 1 do
      for j = i + 1, n do
        local a, b = PROJ[i], PROJ[j]
        if a.owner ~= b.owner and not dead[i] and not dead[j]
           and a.x + 2 < b.x + 14 and b.x + 2 < a.x + 14 and a.y + 2 < b.y + 14 and b.y + 2 < a.y + 14 then
          dead[i] = true; dead[j] = true
          local mx, my = (a.x + b.x) / 2 + 8, (a.y + b.y) / 2 + 8
          spawn_spark(mx, my, 8); spawn_spark(mx + 6, my - 6, 11); spawn_spark(mx - 6, my + 4, 11)
          sfx(SND_KO, 5, "E4"); sfx(SND_DEEP, 7, "C2")
          ROUND.callout = "CLASH!"; ROUND.callout_t = 30
        end
      end
    end
    local keep = {}
    for i = 1, n do if not dead[i] then keep[#keep + 1] = PROJ[i] end end
    PROJ = keep
  end
  base_update_projectiles(f1, f2)
end

-- ---------------------------------------------------------------- celebrations
JUMP_HAPPY = 194
ANIM_POSE[JUMP_HAPPY] = { a = 6, b = 6, t = 0, expr = "happy" }
SPIN_HAPPY = 195
ANIM_POSE[SPIN_HAPPY] = { a = 0, b = 0, t = 0, expr = "happy" }
CELEB = {
  { { POSE_PUMP, 14 }, { POSE_FLEX, 16 }, { POSE_PUMP, 14 }, { JUMP_HAPPY, 22, 12 } },
  { { POSE_SIT, 26 }, { JUMP_HAPPY, 14, 6 }, { POSE_SIT, 26 }, { POSE_STRETCH, 20 } },
  { { POSE_STRETCH, 24 }, { POSE_SIT, 16 }, { POSE_FLAP, 20 }, { POSE_SIT, 16 } },
  { { POSE_STOMP, 12 }, { POSE_FLEX, 8 }, { POSE_STOMP, 12 }, { POSE_FLEX, 8 }, { POSE_PUMP, 26 } },
  { { POSE_FLAP, 7, 5 }, { POSE_PUMP, 7, 5 }, { POSE_FLAP, 7, 5 }, { POSE_PUMP, 7, 5 }, { POSE_FLEX, 24 } },
  { { POSE_FLEX, 24 }, { POSE_HUGWIN, 24 }, { POSE_FLEX, 24 }, { POSE_PUMP, 18 } },
  { { JUMP_HAPPY, 16, 14 }, { POSE_PUMP, 8 }, { JUMP_HAPPY, 16, 14 }, { POSE_FLEX, 18 } },
  { { POSE_BOW, 30 }, { SPIN_HAPPY, 24, 0, true }, { POSE_FLEX, 20 }, { POSE_BOW, 24 } },
}
local celeb_state = ""
local function celebrating()
  if ROUND.winner == nil or ROUND.winner.state ~= "win" then return false end
  if ROUND.state == "matchend" then return true end
  return ROUND.state == "roundend" and ROUND.timer >= 60
end
local base_draw_sprites = draw_sprites
function draw_sprites()
  local w = ROUND.winner
  local step, phase = nil, 0
  if celebrating() then
    local seq = CELEB[w.char]
    local total = 0
    for _, s in ipairs(seq) do total = total + s[2] end
    local k = (ROUND.timer - 60) % total
    for _, s in ipairs(seq) do
      if k < s[2] then step = s; phase = k / s[2]; break end
      k = k - s[2]
    end
    w.pose = step[1]
    if step[3] ~= nil and step[3] > 0 then w.y = FLOOR_Y - floor(step[3] * sin(phase * 3.14159)) else w.y = FLOOR_Y end
  end
  base_draw_sprites()
  if step ~= nil and step[4] == true then
    local o = obj[w.slot - 1]
    if (ROUND.timer // 4) % 2 == 1 then o.flip_x = not o.flip_x end
  end
end

local base_frame = frame
function frame(t, f)
  base_frame(t, f)
  pump_voice(f)
  local st = ROUND.state
  if st ~= celeb_state then
    if st == "roundend" and ROUND.winner ~= nil and ROUND.winner.state ~= "ko" then play_voice(ROUND.winner, "win") end
    celeb_state = st
  end
end
