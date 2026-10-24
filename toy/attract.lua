-- attract.lua: arcade attract mode. After five seconds on the title the game plays a real CPU-vs-CPU match
-- ("DEMO" flashing under the HUD); any button returns to the title, as does the end of the match.
-- Also sharpens the CPU: it chains combos after a landed hit, mixes in hooks/roundhouses/knees, and
-- throws its projectile special from range. Caps live sparks at four so burst debris cannot overflow a
-- scanline on top of two fighters and their shadows. Runs last.
DEMO = false
local DEMO_IDLE = 300

local function pick_pair()
  local a = 1 + floor(rnd() * 8)
  local b = 1 + floor(rnd() * 7)
  if b >= a then b = b + 1 end
  return a, b
end

local function demo_start()
  local c1, c2 = pick_pair()
  DEMO = true
  obj.size_sel = 4
  P1 = new_fighter(1, c1, 32, 1, true)
  P2 = new_fighter(2, c2, 160, -1, true)
  load_fighter(1, c1, false)
  load_fighter(2, c2, false)
  if restore_fx_palette ~= nil then restore_fx_palette() end
  build_stage(c2)
  ROUND.num = 1
  P1.hp, P2.hp = HP_MAX, HP_MAX
  PROJ = {}; SPARKS = {}
  ROUND.clock = 99
  ROUND.state = "intro"; ROUND.timer = 0
  ROUND.callout_t = 0
  clear_hud()
end

local function demo_stop()
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

-- in the demo the "player" is driven by the CPU brain too
local base_read_p1 = read_p1
function read_p1(f)
  if DEMO then cpu_input(f, P2) else base_read_p1(f) end
end

-- smarter CPU: combos, direction strikes, projectile specials, fewer idle stalls
local base_cpu_input = cpu_input
function cpu_input(f, opp)
  base_cpu_input(f, opp)
  local inp = f.inp
  local d = abs(opp.x - f.x)
  local fwd = (opp.x > f.x) and "right" or "left"
  if f.state == "attack" and f.atk ~= nil and f.hitdone == 1 and f.atk.air == nil and rnd() < 0.55 then
    if rnd() < 0.6 then inp.punch = true else inp.kick = true end
  end
  if (f.state == "idle" or f.state == "walk") and d < 62 and d > 40 and rnd() < 0.05 then
    inp[fwd] = true
    if rnd() < 0.5 then inp.punch = true else inp.kick = true end
  end
  if f.ai_plan == "idle" and rnd() < 0.3 then f.ai_plan = "approach" end
  if SPECIAL ~= nil and SPECIAL[f.char] ~= nil and d > 110 and rnd() < 0.04 then
    inp.down = true; inp.punch = true
  end
  if opp.state == "attack" and d < 70 and rnd() < 0.25 then
    inp[fwd] = nil
    inp[(opp.x > f.x) and "left" or "right"] = true
  end
end

local function any_button()
  return pressed("start") or pressed("a") or pressed("b") or pressed("y") or pressed("x")
end

local base_draw_sprites = draw_sprites
function draw_sprites()
  if #SPARKS > 4 then
    local keep = {}
    for i = #SPARKS - 3, #SPARKS do keep[#keep + 1] = SPARKS[i] end
    SPARKS = keep
  end
  base_draw_sprites()
end

local base_frame = frame
function frame(t, f)
  if DEMO then
    if any_button() or (ROUND.state == "matchend" and ROUND.timer > 150) or ROUND.state == "title" then
      demo_stop()
      sfx(SND_SEL, 6, "C5")
    end
  elseif ROUND.state == "title" and TITLE.t >= DEMO_IDLE and not any_button() then
    demo_start()
  end
  base_frame(t, f)
  if DEMO and ROUND.state ~= "title" then
    if (AMB_F or 0) % 60 < 36 then text_center(25, "DEMO - PUSH START") else clear_row(25) end
  end
end
