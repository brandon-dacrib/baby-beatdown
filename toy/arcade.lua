-- arcade.lua: the arcade ladder and the endings. Runs last.
--  * a human match is the first rung of a 7-fight ladder: beat the CPU and the next baby steps in on their
--    own stage ("MATCH n OF 7" under the round call), lose and it is back to the title
--  * beat all seven and the champion gets a big win sequence on their home stage: fireworks, confetti, their
--    celebration moves, their victory voice and a four-line story, then "THE END"
ARCADE = { on = false, order = {}, idx = 0, char = 1 }
ENDING = {
  { "BRANDON TOOK DOWN EVERY BABY.", "THE BAYOU PORCH IS QUIET.", "ONE LAST BOTTLE. THEN A NAP.", "CHAMPION OF THE CRIB." },
  { "ARLO OUT-WIGGLED THEM ALL.", "SEVEN BABIES. ONE GOOD BOY.", "THE BACKYARD IS HIS KINGDOM.", "BELLY RUBS FOR THE CHAMPION." },
  { "DAWN NEVER LOST HER BALANCE.", "THE ROOFTOP IS HERS TONIGHT.", "SHE CURLS UP ON THE WARM VENT.", "NINE LIVES. ZERO LOSSES." },
  { "CHRIS PUSHED EVERYONE OUT.", "THE MUD FARM SHAKES WITH JOY.", "A VICTORY ROLL IN THE PUDDLE.", "YOKOZUNA OF THE PLAYPEN." },
  { "ISAAC KICKED HIGHER THAN ALL.", "THE POND RIPPLES WITH CHEERS.", "HE FLAPS. HE QUACKS. HE WINS.", "GRANDMASTER DUCK." },
  { "TEDDY HUGGED THE WHOLE LEAGUE.", "THE HONEY CAVE IS SAFE AGAIN.", "A JAR OF HONEY FOR THE CHAMP.", "BIGGEST BEAR IN THE CRIB." },
  { "PIP BOUNCED OVER EVERY RIVAL.", "THE CARROT GARDEN IS SAVED.", "ONE CARROT PER KNOCKOUT.", "CHAMPION HOPPER." },
  { "BLUE BOWED. THEN BLUE WON.", "THE BIG LEAF HUMS WITH PRIDE.", "SEVEN KNOCKOUTS. ONE TINY BUG.", "KARATE CHAMPION OF THE GARDEN." },
}
local PAGE = 210

local function any_button()
  return pressed("start") or pressed("a") or pressed("b") or pressed("y") or pressed("x")
end
local function shuffle_others(c, first)
  local list = {}
  for i = 1, 8 do if i ~= c and i ~= first then list[#list + 1] = i end end
  for i = #list, 2, -1 do
    local j = 1 + floor(rnd() * i)
    list[i], list[j] = list[j], list[i]
  end
  local out = { first }
  for _, v in ipairs(list) do out[#out + 1] = v end
  return out
end

local function next_match(c2)
  P1.wins = 0; P1.hp = HP_MAX; P1.meter = 0; P1.state = "idle"; P1.pose = POSE_IDLE
  P1.x = 32; P1.y = FLOOR_Y; P1.vx = 0; P1.vy = 0; P1.face = 1; P1.inp = {}; P1.crouch = false
  P2 = new_fighter(2, c2, 160, -1, true)
  load_fighter(1, P1.char, false)
  load_fighter(2, c2, c2 == P1.char)
  if restore_fx_palette ~= nil then restore_fx_palette() end
  build_stage(c2)
  ROUND.num = 1
  PROJ = {}; SPARKS = {}
  ROUND.clock = 99
  ROUND.state = "intro"; ROUND.timer = 0
  ROUND.callout_t = 0; ROUND.winner = nil
  clear_hud()
end

local function to_title()
  ARCADE.on = false
  DEMO = false
  ROUND.state = "title"; ROUND.timer = 0
  obj.size_sel = 4
  clear_hud()
  if restore_fx_palette ~= nil then restore_fx_palette() end
  local a = 1 + floor(rnd() * 8)
  local b = 1 + floor(rnd() * 7)
  if b >= a then b = b + 1 end
  P1 = new_fighter(1, a, 36, 1, false)
  P2 = new_fighter(2, b, 156, -1, false)
  load_fighter(1, a, false); load_fighter(2, b, false)
  TITLE.t = 0
  build_stage(1 + floor(rnd() * 8))
  PROJ = {}; SPARKS = {}
end

local function start_ending()
  ROUND.state = "ending"; ROUND.timer = 0
  P2 = nil
  P1.state = "win"; P1.x = 96; P1.y = FLOOR_Y; P1.face = 1; P1.hp = HP_MAX; P1.vx = 0; P1.vy = 0; P1.flash = 0
  load_fighter(1, P1.char, false)
  if restore_fx_palette ~= nil then restore_fx_palette() end
  build_stage(P1.char)
  PROJ = {}; SPARKS = {}; OBJECTS = {}; BALL = nil
  clear_hud()
  if play_voice ~= nil then play_voice(P1, "win") end
  sfx(SND_KO, 4, "C5")
end

local function update_ending(f)
  local T = ROUND.timer
  ROUND.timer = T + 1
  stage_sky()
  -- the champion runs their celebration moves
  local seq = CELEB[P1.char]
  local total = 0
  for _, s in ipairs(seq) do total = total + s[2] end
  local k = T % total
  local step, phase = seq[1], 0
  for _, s in ipairs(seq) do
    if k < s[2] then step = s; phase = k / s[2]; break end
    k = k - s[2]
  end
  P1.pose = step[1]
  if step[3] ~= nil and step[3] > 0 then P1.y = FLOOR_Y - floor(step[3] * sin(phase * 3.14159)) else P1.y = FLOOR_Y end
  P1.anim = P1.anim + 1
  -- fireworks and confetti (sparks are capped at four, so one piece at a time)
  if T % 45 == 10 then
    local fx, fy = 30 + rnd() * 196, 20 + rnd() * 50
    spawn_spark(fx, fy, 8)
    sfx(SND_DEEP, 7, "C2"); sfx(SND_SMACK, 6, "G4")
  end
  if T % 12 == 0 and #SPARKS < 3 then
    SPARKS[#SPARKS + 1] = { x = 10 + rnd() * 236, y = 8 + rnd() * 30, cell = 11, t = 34, vx = (rnd() - 0.5) * 2, vy = -1 - rnd() * 2, frag = true }
  end
  if T % 90 == 60 and play_voice ~= nil and rnd() < 0.5 then play_voice(P1, "special") end
  -- captions
  local lines = ENDING[P1.char]
  local name = CHAR_NAME[P1.char]
  if (T // 8) % 2 == 0 then text_center(3, name .. " WINS IT ALL!") else clear_row(3) end
  local page = T // PAGE + 1
  clear_row(5); clear_row(6)
  if page <= #lines then
    text_center(5, lines[page])
  else
    text_center(5, "THE END")
    if (T // 30) % 2 == 0 then text_center(6, "PUSH START") else clear_row(6) end
  end
  local tag = "MATCH 7 OF 7 - PERFECT RUN"
  if T < PAGE then text_center(25, tag) elseif T == PAGE then clear_row(25) end
  if (T > 150 and any_button()) or T > PAGE * (#lines + 1) + 360 then
    sfx(SND_SEL, 6, "C5")
    to_title()
  end
end

local base_frame = frame
function frame(t, f)
  if ROUND.state == "ending" then
    brightness = 15
    update_ending(f)
    if ROUND.state == "ending" then draw_sprites() else draw_sprites() end
    remember_pad()
    return
  end
  if not DEMO and ROUND.state == "intro" and ROUND.timer == 0 and not ARCADE.on and P1 ~= nil and P2 ~= nil and not P1.cpu then
    ARCADE.on = true; ARCADE.char = P1.char; ARCADE.idx = 1
    ARCADE.order = shuffle_others(P1.char, P2.char)
  end
  if ARCADE.on then
    if DEMO or ROUND.state == "title" or ROUND.state == "select" then
      ARCADE.on = false
    elseif ROUND.state == "matchend" and ROUND.winner == P1 and (ROUND.timer >= 170 or (ROUND.timer > 100 and any_button())) then
      if ARCADE.idx < 7 then
        ARCADE.idx = ARCADE.idx + 1
        next_match(ARCADE.order[ARCADE.idx])
        sfx(SND_SEL, 6, "G5")
      else
        start_ending()
        draw_sprites()
        remember_pad()
        return
      end
    end
  end
  base_frame(t, f)
  if ARCADE.on and ROUND.state == "intro" and ROUND.num == 1 and ROUND.timer < 70 then
    text_center(12, "MATCH " .. ARCADE.idx .. " OF 7")
  elseif ARCADE.on and ROUND.state == "intro" and ROUND.num == 1 and ROUND.timer == 70 then
    clear_row(12)
  end
end
