-- styles.lua: per-character stances and fighting styles, air punch, hit sounds (runs after fight/art/tuning)
STYLE = {
  { name = "BOXER",    walk = 1.0,  jump = -6.8, grav = 0.32, pmul = 1.1, kmul = 1.0 },
  { name = "POUNCER",  walk = 1.15, jump = -7.4, grav = 0.36, pmul = 0.9, kmul = 1.1 },
  { name = "SLINKY",   walk = 1.3,  jump = -7.0, grav = 0.34, pmul = 0.8, kmul = 0.9 },
  { name = "BRUISER",  walk = 0.8,  jump = -6.0, grav = 0.36, pmul = 1.3, kmul = 1.2 },
  { name = "FLAPPER",  walk = 1.0,  jump = -6.4, grav = 0.22, pmul = 0.9, kmul = 1.0 },
  { name = "GRIZZLY",  walk = 0.75, jump = -6.2, grav = 0.40, pmul = 1.4, kmul = 1.3 },
  { name = "HOPPER",   walk = 1.2,  jump = -8.4, grav = 0.38, pmul = 0.7, kmul = 1.4 },
  { name = "SKITTER",  walk = 1.25, jump = -6.6, grav = 0.34, pmul = 0.8, kmul = 0.8 },
}

-- NOTE: this Lua needs every argument passed explicitly (missing ones are not nil).
local function stance(arms, body, legs)
  local o = {}
  if arms ~= nil then o.barm = arms[1]; o.farm = arms[2] end
  if body ~= nil then o.neck = body[1]; o.hip = body[2] end
  if legs ~= nil then o.bleg = legs[1]; o.fleg = legs[2] end
  return o
end
STANCE = {
  stance({ {{10,17},{12,13}}, {{20,16},{22,12}} }, nil, nil),
  stance({ {{10,20},{12,19}}, {{20,21},{23,19}} }, { {15,15}, {13,23} }, { {{9,27},{7,31}}, {{19,27},{21,31}} }),
  stance({ {{9,19},{12,17}}, {{20,17},{24,13}} }, { {14,14}, {14,22} }, nil),
  stance({ {{8,19},{7,15}}, {{20,19},{21,15}} }, nil, { {{7,27},{5,31}}, {{21,27},{23,31}} }),
  stance({ {{7,16},{4,13}}, {{21,16},{24,13}} }, nil, nil),
  stance({ {{10,19},{12,21}}, {{21,17},{25,20}} }, nil, { {{8,27},{6,31}}, {{20,27},{22,31}} }),
  stance({ {{10,19},{12,17}}, {{18,19},{20,17}} }, { {14,15}, {14,23} }, { {{9,28},{7,31}}, {{19,28},{21,31}} }),
  stance({ {{8,20},{10,18}}, {{20,20},{22,18}} }, { {14,16}, {14,23} }, { {{8,28},{6,31}}, {{20,28},{22,31}} }),
}

local base_render_pose = render_pose
function render_pose(ci, pi)
  if pi <= 2 and STANCE[ci] ~= nil then
    local saved = POSES[pi]
    local merged = {}
    for k, v in pairs(saved) do merged[k] = v end
    for k, v in pairs(STANCE[ci]) do merged[k] = v end
    if pi ~= 0 then merged.bleg = saved.bleg; merged.fleg = saved.fleg end
    POSES[pi] = merged
    local c = base_render_pose(ci, pi)
    POSES[pi] = saved
    return c
  end
  return base_render_pose(ci, pi)
end

ATTACKS.jpunch = { startup = 3, active = 10, recover = 2, dmg = 7, stun = 14, pose = POSE_PUNCH, x0 = 36, x1 = 60, y0 = 18, y1 = 40, air = true }

local base_update_fighter = update_fighter
function update_fighter(f, opp, allow_input)
  local st = STYLE[f.char]
  GRAVITY = st.grav
  local was = f.state
  if allow_input and f.state == "jump" and f.inp.punch then
    f.state = "attack"; f.atk = ATTACKS.jpunch; f.timer = 0; f.hitdone = 0; f.pose = POSE_PUNCH
    f.inp.punch = false
    sfx(SND_WHIFF, 7, "C5")
  end
  base_update_fighter(f, opp, allow_input)
  if f.state == "walk" then f.x = f.x + f.vx * (st.walk - 1) end
  if f.state == "jump" and was ~= "jump" then f.vy = st.jump + GRAVITY end
  if f.x < -8 then f.x = -8 elseif f.x > 200 then f.x = 200 end
end

SND_DEEP = bank("kick", { vol = 127 })
SND_SMACK = bank("clap", { vol = 110 })
SND_CRACK = bank("snare", { vol = 120 })

function apply_hit(att, def, dmg, stun, low, high, hx, hy, pushback)
  local st = STYLE[att.char]
  local heavy = false
  local push = 2.5
  if att.state == "attack" and att.atk ~= nil then
    if att.atk.pose == POSE_PUNCH then dmg = floor(dmg * st.pmul + 0.5) else dmg = floor(dmg * st.kmul + 0.5); heavy = true; push = 3.5 end
  elseif att.state == "super" then
    heavy = true
    if att.sup ~= nil and att.sup.hits ~= nil and att.sup.hits > 1 then push = 1 else push = 5 end
  else
    heavy = true; push = 4
  end
  local grounded = def.state == "idle" or def.state == "walk" or def.state == "crouch"
  local back = false
  if def.face == 1 then back = def.inp.left == true else back = def.inp.right == true end
  local can_block = grounded and back
  if can_block and low == true and not def.crouch then can_block = false end
  if can_block and high == true and def.crouch then can_block = false end
  if can_block then
    def.state = "block"; def.timer = 12; def.pose = POSE_BLOCK
    def.vx = -def.face * 2
    def.meter = min(METER_MAX, def.meter + 3)
    spawn_spark(hx, hy, 9)
    sfx(SND_BLOCK, 6, "C4")
    return false
  end
  def.hp = max(0, def.hp - dmg)
  def.state = "hit"; def.timer = stun; def.pose = POSE_HIT; def.crouch = false
  def.vx = -def.face * push
  if def.y < FLOOR_Y then def.vy = -3 end
  def.flash = 6
  att.meter = min(METER_MAX, att.meter + 12)
  def.meter = min(METER_MAX, def.meter + 6)
  spawn_spark(hx, hy, 8)
  if heavy then
    sfx(SND_DEEP, 7, "C2"); sfx(SND_CRACK, 6, "G3"); sfx(SND_SMACK, 5, "A3")
  else
    sfx(SND_DEEP, 7, "G2"); sfx(SND_SMACK, 6, "D4")
  end
  if def.hp <= 0 then
    def.state = "ko"; def.timer = 0; def.pose = POSE_KO; def.vy = -5; def.vx = -def.face * 3
    sfx(SND_KO, 4, "C4")
  end
  return true
end
