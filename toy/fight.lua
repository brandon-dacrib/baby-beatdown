-- fight.lua: fighter state machine, hits, projectiles, CPU brain, sprite drawing (64x64 sprites)
ATTACKS = {
  punch = { startup = 4, active = 6, recover = 8,  dmg = 8,  stun = 14, pose = POSE_PUNCH, x0 = 38, x1 = 62, y0 = 22, y1 = 36 },
  kick  = { startup = 6, active = 8, recover = 12, dmg = 12, stun = 18, pose = POSE_KICK,  x0 = 40, x1 = 66, y0 = 26, y1 = 44 },
  sweep = { startup = 6, active = 8, recover = 14, dmg = 10, stun = 20, pose = POSE_CKICK, x0 = 36, x1 = 66, y0 = 44, y1 = 64, low = true },
  jkick = { startup = 3, active = 14, recover = 2, dmg = 10, stun = 16, pose = POSE_KICK,  x0 = 32, x1 = 62, y0 = 26, y1 = 54, air = true },
}
RUSH_BOX = { x0 = 34, x1 = 68, y0 = 14, y1 = 50 }

function new_fighter(slot, c, x, face, cpu)
  return { slot = slot, char = c, x = x, y = FLOOR_Y, vx = 0, vy = 0, face = face, hp = HP_MAX, meter = 0,
    state = "idle", timer = 0, pose = POSE_IDLE, hitdone = 0, crouch = false, cpu = cpu,
    inp = {}, wins = 0, ai_t = 0, ai_plan = "idle", anim = 0, atk = nil, sup = nil, flash = 0 }
end

function body_box(f)
  local y0 = f.crouch and f.y + 20 or f.y + 5
  if f.state == "ko" then y0 = f.y + 40 end
  return f.x + 20, y0, f.x + 44, f.y + 64
end

local function attack_box(f, a)
  local x0, x1
  if f.face == 1 then x0, x1 = f.x + a.x0, f.x + a.x1 else x0, x1 = f.x + 64 - a.x1, f.x + 64 - a.x0 end
  return x0, f.y + a.y0, x1, f.y + a.y1
end

local function overlap(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
  return ax0 < bx1 and bx0 < ax1 and ay0 < by1 and by0 < ay1
end

SPARKS = {}
PROJ = {}
function spawn_spark(x, y, cell)
  SPARKS[#SPARKS + 1] = { x = x, y = y, cell = cell, t = 12 }
end

local function holding_back(f)
  if f.face == 1 then return f.inp.left else return f.inp.right end
end

local function grounded(f)
  return f.state == "idle" or f.state == "walk" or f.state == "crouch"
end

function apply_hit(att, def, dmg, stun, low, high, hx, hy, pushback)
  local can_block = grounded(def) and holding_back(def)
  if can_block and low and not def.crouch then can_block = false end
  if can_block and high and def.crouch then can_block = false end
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
  def.vx = -def.face * (pushback or 2.5)
  if def.y < FLOOR_Y then def.vy = -3 end
  def.flash = 6
  att.meter = min(METER_MAX, att.meter + 12)
  def.meter = min(METER_MAX, def.meter + 6)
  spawn_spark(hx, hy, 8)
  sfx(SND_HIT, 6, "C4"); sfx(SND_THUD, 7, "C3")
  if def.hp <= 0 then
    def.state = "ko"; def.timer = 0; def.pose = POSE_KO; def.vy = -5; def.vx = -def.face * 3
    sfx(SND_KO, 5, "C4")
  end
  return true
end

local function start_attack(f, name)
  local a = ATTACKS[name]
  f.state = "attack"; f.atk = a; f.timer = 0; f.hitdone = 0; f.pose = a.pose
  if not a.air then f.vx = 0 end
  sfx(SND_WHIFF, 7, "C5")
end

local function start_super(f, opp)
  local s = SUPER[f.char]
  f.meter = 0
  f.state = "super"; f.timer = 0; f.pose = POSE_SUPER; f.sup = s; f.hitdone = 0; f.vx = 0; f.crouch = false
  f.face = (opp.x > f.x) and 1 or -1
  ROUND.callout = s.name; ROUND.callout_t = 60
  sfx(SND_SUPER, 5, "G5")
end

local function fire_projectile(f)
  local s = f.sup
  local px = f.face == 1 and f.x + 48 or f.x
  PROJ[#PROJ + 1] = { x = px, y = f.y + s.dy, vx = f.face * s.speed, cell = f.char - 1, owner = f,
    dmg = s.dmg, t = 0, wobble = s.wobble, life = s.short or 400 }
end

local function land(f)
  f.y = FLOOR_Y; f.vy = 0
  if f.state == "jump" or (f.state == "attack" and f.atk.air) then f.state = "idle"; f.vx = 0 end
  if f.state == "hit" and f.timer <= 0 then f.state = "idle"; f.vx = 0 end
end

local function physics(f)
  f.x = f.x + f.vx
  if f.y < FLOOR_Y or f.vy ~= 0 then
    f.vy = f.vy + GRAVITY
    f.y = f.y + f.vy
    if f.y >= FLOOR_Y then land(f) end
  end
  if f.x < -8 then f.x = -8 end
  if f.x > 200 then f.x = 200 end
end

function update_fighter(f, opp, allow_input)
  local inp = f.inp
  if not allow_input then inp = {} end
  f.anim = f.anim + 1
  if f.flash > 0 then f.flash = f.flash - 1 end

  if f.state == "ko" then
    physics(f)
    if f.y >= FLOOR_Y then f.vx = f.vx * 0.8 end
    f.pose = POSE_KO
    return
  end
  if f.state == "win" then return end
  if f.state == "hit" or f.state == "block" then
    f.timer = f.timer - 1
    physics(f)
    f.vx = f.vx * 0.85
    if f.timer <= 0 and f.y >= FLOOR_Y then f.state = "idle"; f.vx = 0; f.crouch = false end
    return
  end
  if f.state == "attack" then
    local a = f.atk
    f.timer = f.timer + 1
    physics(f)
    if f.timer > a.startup and f.timer <= a.startup + a.active and f.hitdone == 0 then
      local x0, y0, x1, y1 = attack_box(f, a)
      local bx0, by0, bx1, by1 = body_box(opp)
      if opp.state ~= "ko" and overlap(x0, y0, x1, y1, bx0, by0, bx1, by1) then
        f.hitdone = 1
        apply_hit(f, opp, a.dmg, a.stun, a.low, a.air, (x0 + x1) // 2, (y0 + y1) // 2)
      end
    end
    if a.air then
      if f.y >= FLOOR_Y then f.state = "idle"; f.vx = 0 end
    elseif f.timer >= a.startup + a.active + a.recover then
      f.state = "idle"; f.pose = f.crouch and POSE_CROUCH or POSE_IDLE
    end
    return
  end
  if f.state == "super" then
    local s = f.sup
    f.timer = f.timer + 1
    if s.kind == "proj" then
      f.pose = POSE_SUPER
      if f.timer == 18 then fire_projectile(f) end
      if f.timer > 18 then f.pose = POSE_PUNCH end
      if f.timer >= 36 then f.state = "idle" end
    else
      if f.timer < 12 then
        f.pose = POSE_SUPER
      else
        f.pose = s.pose
        f.vx = f.face * s.speed
        if s.hop and f.timer == 12 then f.vy = -5 end
        if f.timer % 6 == 0 and f.hitdone < s.hits then
          local x0, y0, x1, y1 = attack_box(f, RUSH_BOX)
          local bx0, by0, bx1, by1 = body_box(opp)
          if opp.state ~= "ko" and overlap(x0, y0, x1, y1, bx0, by0, bx1, by1) then
            f.hitdone = f.hitdone + 1
            apply_hit(f, opp, s.dmg, 24, false, false, (x0 + x1) // 2, (y0 + y1) // 2, s.hits > 1 and 1 or 5)
          end
        end
        if f.timer >= 36 then f.state = "idle"; f.vx = 0 end
      end
    end
    physics(f)
    if f.state == "idle" then f.vx = 0 end
    return
  end
  if f.state == "jump" then
    physics(f)
    f.pose = POSE_JUMP
    if inp.punch or inp.kick then start_attack(f, "jkick") end
    return
  end

  f.face = (opp.x > f.x) and 1 or -1
  f.vx = 0
  f.crouch = false
  if inp.super and f.meter >= METER_MAX then
    start_super(f, opp)
  elseif inp.kick and inp.down then
    f.crouch = true; start_attack(f, "sweep")
  elseif inp.punch then
    if inp.down then f.crouch = true end
    start_attack(f, "punch")
  elseif inp.kick then
    start_attack(f, "kick")
  elseif inp.up then
    f.state = "jump"; f.vy = -6.8
    if inp.left then f.vx = -2.4 elseif inp.right then f.vx = 2.4 end
    physics(f)
  elseif inp.down then
    f.state = "crouch"; f.crouch = true; f.pose = POSE_CROUCH
  elseif inp.left or inp.right then
    f.state = "walk"
    local dir = inp.left and -1 or 1
    f.vx = dir * ((dir == f.face) and 2.4 or 1.8)
    physics(f)
    local step = (f.anim // 8) % 4
    if step == 0 then f.pose = POSE_WALK1 elseif step == 2 then f.pose = POSE_WALK2 else f.pose = POSE_IDLE end
  else
    f.state = "idle"
    f.pose = POSE_IDLE
  end
end

function separate(a, b)
  if a.state == "ko" or b.state == "ko" then return end
  local dx = b.x - a.x
  if abs(dx) < 28 and abs(a.y - b.y) < 50 then
    local push = (28 - abs(dx)) / 2
    if dx >= 0 then a.x = a.x - push; b.x = b.x + push else a.x = a.x + push; b.x = b.x - push end
    if a.x < -8 then a.x = -8; b.x = 20 end
    if b.x < -8 then b.x = -8; a.x = 20 end
    if a.x > 200 then a.x = 200; b.x = 172 end
    if b.x > 200 then b.x = 200; a.x = 172 end
  end
end

function update_projectiles(f1, f2)
  local keep = {}
  for i = 1, #PROJ do
    local p = PROJ[i]
    p.t = p.t + 1
    p.x = p.x + p.vx
    if p.wobble then p.y = p.y + sin(p.t / 6) * 0.8 end
    local target = (p.owner == f1) and f2 or f1
    local bx0, by0, bx1, by1 = body_box(target)
    local alive = p.x > -16 and p.x < 256 and p.t < p.life
    if alive and target.state ~= "ko" and overlap(p.x + 2, p.y + 2, p.x + 14, p.y + 14, bx0, by0, bx1, by1) then
      apply_hit(p.owner, target, p.dmg, 26, false, false, p.x + 8, p.y + 8, 4)
      alive = false
    end
    if alive then keep[#keep + 1] = p end
  end
  PROJ = keep
end

-- ---------------------------------------------------------------- CPU brain
local function cpu_think(f, opp)
  f.ai_t = f.ai_t - 1
  if f.ai_t > 0 then return end
  local d = abs(opp.x - f.x)
  local r = rnd()
  if f.meter >= METER_MAX and d < 150 and r < 0.4 then f.ai_plan = "super"; f.ai_t = 4
  elseif opp.state == "attack" and d < 60 and r < 0.4 then f.ai_plan = "block"; f.ai_t = 18
  elseif opp.y < FLOOR_Y - 10 and d < 70 and r < 0.5 then f.ai_plan = "punch"; f.ai_t = 8
  elseif d > 44 then
    if r < 0.62 then f.ai_plan = "approach"; f.ai_t = 10 + floor(rnd() * 16)
    elseif r < 0.74 and d > 90 then f.ai_plan = "jumpin"; f.ai_t = 10
    elseif r < 0.86 then f.ai_plan = "crouch"; f.ai_t = 12
    else f.ai_plan = "idle"; f.ai_t = 10 end
  else
    if r < 0.32 then f.ai_plan = "punch"; f.ai_t = 8
    elseif r < 0.58 then f.ai_plan = "kick"; f.ai_t = 10
    elseif r < 0.7 then f.ai_plan = "sweep"; f.ai_t = 10
    elseif r < 0.82 then f.ai_plan = "block"; f.ai_t = 14
    elseif r < 0.9 then f.ai_plan = "retreat"; f.ai_t = 12
    else f.ai_plan = "idle"; f.ai_t = 8 end
  end
end

function cpu_input(f, opp)
  cpu_think(f, opp)
  local inp = {}
  local fwd = (opp.x > f.x) and "right" or "left"
  local back = (opp.x > f.x) and "left" or "right"
  local plan = f.ai_plan
  if plan == "approach" then inp[fwd] = true
  elseif plan == "retreat" or plan == "block" then inp[back] = true
  elseif plan == "jumpin" then inp.up = true; inp[fwd] = true; f.ai_plan = "air"
  elseif plan == "air" then if f.y < FLOOR_Y - 20 and abs(opp.x - f.x) < 60 then inp.kick = true end
  elseif plan == "punch" then inp.punch = (f.ai_t == 7)
  elseif plan == "kick" then inp.kick = (f.ai_t == 9)
  elseif plan == "sweep" then inp.down = true; inp.kick = (f.ai_t == 9)
  elseif plan == "crouch" then inp.down = true
  elseif plan == "super" then inp.super = (f.ai_t == 3) end
  f.inp = inp
end

-- ---------------------------------------------------------------- input
PREV = {}
function pressed(name) return pad[name] and not PREV[name] end
function read_p1(f)
  f.inp = { left = pad.left, right = pad.right, up = pad.up, down = pad.down,
    punch = pressed("y") or pressed("x"), kick = pressed("b"), super = pressed("a") }
end
function remember_pad()
  PREV = { left = pad.left, right = pad.right, up = pad.up, down = pad.down, a = pad.a, b = pad.b,
    x = pad.x, y = pad.y, start = pad.start, select = pad.select, l = pad.l, r = pad.r }
end

-- ---------------------------------------------------------------- drawing
local function draw_fighter(f, slot_obj)
  set_fighter_vram(f.slot, f.char, f.pose)
  local o = obj[slot_obj]
  o.tile = SLOT_TILE[f.slot]
  o.pal = f.slot - 1
  o.large = true
  o.flip_x = (f.face == -1)
  o.x = floor(f.x)
  o.y = floor(f.y)
  o.prio = 2
  o.on = not (f.flash > 0 and f.flash % 2 == 1)
end

function draw_sprites()
  for i = 0, 15 do obj[i].on = false end
  if P1 then draw_fighter(P1, 0) end
  if P2 then draw_fighter(P2, 1) end
  local n = 2
  for i = 1, #PROJ do
    local p = PROJ[i]
    obj[n].tile = fx_tile(p.cell); obj[n].pal = 2; obj[n].large = false
    obj[n].x = floor(p.x); obj[n].y = floor(p.y); obj[n].flip_x = p.vx < 0; obj[n].prio = 2; obj[n].on = true
    n = n + 1
  end
  local keep = {}
  for i = 1, #SPARKS do
    local s = SPARKS[i]
    s.t = s.t - 1
    if s.t > 0 then
      keep[#keep + 1] = s
      obj[n].tile = fx_tile(s.cell); obj[n].pal = 2; obj[n].large = false
      obj[n].x = s.x - 8; obj[n].y = s.y - 8; obj[n].flip_x = (s.t % 4 < 2); obj[n].prio = 3; obj[n].on = true
      n = n + 1
    end
  end
  SPARKS = keep
end

function draw_hud()
  text(1, 1, CHAR_NAME[P1.char])
  local n2 = CHAR_NAME[P2.char]
  text(31 - string.len(n2), 1, n2)
  local h1 = (P1.hp + 7) // 8
  local h2 = (P2.hp + 7) // 8
  for i = 0, 11 do
    hud_tile(13 - i, 2, (i < h1) and 43 or 44)
    hud_tile(18 + i, 2, (i < h2) and 43 or 44)
  end
  local m1 = P1.meter // 16
  local m2 = P2.meter // 16
  for i = 0, 5 do
    hud_tile(13 - i, 3, (i < m1) and 45 or 46)
    hud_tile(18 + i, 3, (i < m2) and 45 or 46)
  end
  hud_tile(13, 1, (P1.wins >= 1) and 43 or 44)
  hud_tile(14, 1, (P1.wins >= 2) and 43 or 44)
  hud_tile(17, 1, (P2.wins >= 2) and 43 or 44)
  hud_tile(18, 1, (P2.wins >= 1) and 43 or 44)
  local c = floor(ROUND.clock)
  text(15, 2, string.sub("0" .. c, -2, -1))
  if P1.meter >= METER_MAX then text(1, 4, "SUPER!") else text(1, 4, "      ") end
  if P2.meter >= METER_MAX then text(25, 4, "SUPER!") else text(25, 4, "      ") end
end
