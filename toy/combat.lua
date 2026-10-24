-- combat.lua: combos, knockback, breakable stage objects, hit flash, idle breathing. Runs after styles.lua.
POSES[12] = { neck = {15,13}, hip = {13,22}, barm = {{20,15},{27,14}}, farm = {{18,18},{19,15}}, bleg = {{9,27},{8,31}}, fleg = {{19,27},{20,31}} }
POSES[13] = { neck = {15,12}, hip = {13,22}, barm = {{10,18},{12,15}}, farm = {{21,12},{22,5}},  bleg = {{9,27},{8,31}}, fleg = {{19,26},{21,31}} }
POSES[14] = { neck = {12,13}, hip = {13,21}, barm = {{7,17},{9,14}},   farm = {{16,17},{18,14}}, bleg = {{9,27},{8,31}}, fleg = {{21,14},{27,7}} }
POSE_CROSS, POSE_UPPER, POSE_HIGHKICK = 12, 13, 14

ATTACKS.jab      = { startup = 3, active = 5, recover = 7,  dmg = 6,  stun = 14, pose = POSE_PUNCH,    x0 = 38, x1 = 62, y0 = 22, y1 = 36 }
ATTACKS.cross    = { startup = 5, active = 6, recover = 10, dmg = 9,  stun = 16, pose = POSE_CROSS,    x0 = 40, x1 = 66, y0 = 20, y1 = 34 }
ATTACKS.upper    = { startup = 6, active = 7, recover = 14, dmg = 12, stun = 22, pose = POSE_UPPER,    x0 = 34, x1 = 58, y0 = 0,  y1 = 32, launch = true }
ATTACKS.highkick = { startup = 7, active = 7, recover = 12, dmg = 11, stun = 18, pose = POSE_HIGHKICK, x0 = 40, x1 = 68, y0 = 6,  y1 = 30, high = true }
ATTACKS.punch = ATTACKS.jab

CHAINS = {
  { Y = { "jab", "cross", "upper" },                 B = { "kick", "cross", "upper" } },
  { Y = { "jab", "cross", "highkick" },              B = { "kick", "sweep", "upper" } },
  { Y = { "jab", "jab", "jab", "cross" },            B = { "highkick", "sweep" } },
  { Y = { "cross", "upper" },                        B = { "kick", "kick" } },
  { Y = { "jab", "jab", "highkick" },                B = { "kick", "highkick", "highkick" } },
  { Y = { "cross", "cross", "upper" },               B = { "kick", "sweep" } },
  { Y = { "jab", "upper" },                          B = { "kick", "kick", "kick", "highkick" } },
  { Y = { "jab", "jab", "jab", "jab", "jab" },       B = { "sweep", "sweep", "kick" } },
}

local function begin(f, name, step)
  local a = ATTACKS[name]
  f.state = "attack"; f.atk = a; f.timer = 0; f.hitdone = 0; f.pose = a.pose; f.combo = step
  f.vx = 0
  sfx(SND_WHIFF, 7, "C5")
end

BREAK = {
  { cell = 12, color = "barrel" }, { cell = 14, color = "pot" }, { cell = 13, color = "crate" }, { cell = 12, color = "barrel" },
  { cell = 13, color = "crate" }, { cell = 14, color = "pot" }, { cell = 14, color = "pot" }, { cell = 15, color = "dew" },
}
OBJECTS = {}
local break_tiles_ready = false

local function fx_cell_pixel(cell, fn)
  for ty = 0, 1 do
    for tx = 0, 1 do
      local tile = fx_tile(cell) + ty * 16 + tx
      local addr = OBJ_BASE + tile * 16
      for row = 0, 7 do
        local p0, p1, p2, p3 = 0, 0, 0, 0
        for col = 0, 7 do
          local v = fn(tx * 8 + col, ty * 8 + row)
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
local function inside(x, y, cx, cy, rx, ry) local ex, ey = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry return ex * ex + ey * ey <= 1 end
local function with_outline(fn)
  return function(x, y)
    local v = fn(x, y)
    if v == 0 then return 0 end
    if fn(x - 1, y) == 0 or fn(x + 1, y) == 0 or fn(x, y - 1) == 0 or fn(x, y + 1) == 0 then return 1 end
    return v
  end
end
local function upload_breakables()
  fx_cell_pixel(12, with_outline(function(x, y)
    if x < 2 or x > 13 or y < 1 or y > 15 then return 0 end
    if y == 4 or y == 11 then return 3 end
    if (x == 2 or x == 13) and (y < 3 or y > 13) then return 0 end
    return (x < 6) and 11 or 7
  end))
  fx_cell_pixel(13, with_outline(function(x, y)
    if x < 1 or x > 14 or y < 2 or y > 15 then return 0 end
    if x == y + 1 or x == 15 - y + 1 or y == 2 or y == 15 or x == 1 or x == 14 then return 7 end
    return 15
  end))
  fx_cell_pixel(14, with_outline(function(x, y)
    if y >= 1 and y <= 3 and x >= 3 and x <= 12 then return 9 end
    if y > 3 and inside(x, y, 8, 10, 6.5, 5.5) then return (x < 6 and y < 9) and 5 or 9 end
    return 0
  end))
  fx_cell_pixel(15, with_outline(function(x, y)
    if inside(x, y, 8, 9, 6, 6) or (y < 4 and abs(x - 7.5) < (y + 1)) then return (x < 6 and y < 8) and 5 or 14 end
    return 0
  end))
  break_tiles_ready = true
end

function spawn_objects()
  local b = BREAK[CURRENT_STAGE] or BREAK[1]
  OBJECTS = {
    { x = 2, y = FLOOR_Y + 48, cell = b.cell, alive = true },
    { x = 238, y = FLOOR_Y + 48, cell = b.cell, alive = true },
  }
end

local function burst(o, who)
  o.alive = false
  for i = 1, 6 do
    SPARKS[#SPARKS + 1] = { x = o.x + 8, y = o.y + 8, cell = 11, t = 28, vx = (rnd() - 0.5) * 5, vy = -2 - rnd() * 3, frag = true }
  end
  SPARKS[#SPARKS + 1] = { x = o.x + 8, y = o.y + 8, cell = 8, t = 10 }
  sfx(SND_KO, 4, "G4"); sfx(SND_DEEP, 7, "C2")
  if who ~= nil then who.meter = min(METER_MAX, who.meter + 12) end
end

local function box_hit(ax0, ay0, ax1, ay1, o)
  return ax0 < o.x + 14 and o.x + 2 < ax1 and ay0 < o.y + 16 and o.y + 2 < ay1
end

local function check_objects()
  for _, o in ipairs(OBJECTS) do
    if o.alive then
      for _, f in ipairs({ P1, P2 }) do
        if f.state == "attack" and f.atk ~= nil and f.timer > f.atk.startup and f.timer <= f.atk.startup + f.atk.active then
          local a = f.atk
          local x0, x1
          if f.face == 1 then x0, x1 = f.x + a.x0, f.x + a.x1 else x0, x1 = f.x + 64 - a.x1, f.x + 64 - a.x0 end
          if box_hit(x0, f.y + a.y0, x1, f.y + a.y1, o) then burst(o, f) end
        elseif (f.state == "hit" or f.state == "ko") and abs(f.vx) > 1 then
          local bx0, by0, bx1, by1 = body_box(f)
          if box_hit(bx0, by0, bx1, by1, o) then burst(o, nil) end
        end
      end
      for _, p in ipairs(PROJ) do
        if o.alive and box_hit(p.x + 2, p.y + 2, p.x + 14, p.y + 14, o) then burst(o, p.owner) end
      end
    end
  end
end

local base_update_fighter = update_fighter
function update_fighter(f, opp, allow_input)
  local was = f.state
  local ci = f.char
  if allow_input and f.state == "attack" and f.atk ~= nil and f.atk.air == nil and f.hitdone == 1 and f.timer >= f.atk.startup + 1 then
    local btn = nil
    if f.inp.punch then btn = "Y" elseif f.inp.kick then btn = "B" end
    if btn ~= nil then
      local chain = CHAINS[ci][btn]
      local step = (f.combo or 1) + 1
      if chain[step] ~= nil then
        begin(f, chain[step], step)
        f.inp.punch = false; f.inp.kick = false
      end
    end
  end
  base_update_fighter(f, opp, allow_input)
  if was ~= "attack" and f.state == "attack" and f.atk ~= nil and f.atk.air == nil and f.timer == 0 then
    local btn = (f.atk.pose == POSE_PUNCH) and "Y" or "B"
    if f.atk.pose ~= POSE_CKICK then
      local a = ATTACKS[CHAINS[ci][btn][1]]
      f.atk = a; f.pose = a.pose
    end
    f.combo = 1
  end
  if f.state ~= "attack" then f.combo = 0 end
  if f.push_t ~= nil and f.push_t > 0 then
    f.push_t = f.push_t - 1
    f.x = f.x - f.face * 2.5
    if f.x < -8 then f.x = -8 elseif f.x > 200 then f.x = 200 end
  end
end

function apply_hit(att, def, dmg, stun, low, high, hx, hy, pushback)
  local st = STYLE[att.char]
  local heavy = false
  local push = 3.5
  local a = att.atk
  if att.state == "attack" and a ~= nil then
    if a.pose == POSE_PUNCH or a.pose == POSE_CROSS or a.pose == POSE_UPPER then dmg = floor(dmg * st.pmul + 0.5) else dmg = floor(dmg * st.kmul + 0.5); heavy = true; push = 5 end
    if a.launch == true then heavy = true end
    if a.high == true then high = true end
  elseif att.state == "super" then
    heavy = true
    if att.sup ~= nil and att.sup.hits ~= nil and att.sup.hits > 1 then push = 1.5 else push = 6 end
  else
    heavy = true; push = 5
  end
  local grounded = def.state == "idle" or def.state == "walk" or def.state == "crouch"
  local back = false
  if def.face == 1 then back = def.inp.left == true else back = def.inp.right == true end
  local can_block = grounded and back
  if can_block and low == true and not def.crouch then can_block = false end
  if can_block and high == true and def.crouch then can_block = false end
  if can_block then
    def.state = "block"; def.timer = 12; def.pose = POSE_BLOCK
    def.vx = -def.face * 2.5
    def.meter = min(METER_MAX, def.meter + 3)
    spawn_spark(hx, hy, 9)
    sfx(SND_BLOCK, 6, "C4")
    if (def.face == 1 and def.x <= -6) or (def.face == -1 and def.x >= 198) then att.push_t = 6 end
    return false
  end
  def.hp = max(0, def.hp - dmg)
  def.state = "hit"; def.timer = stun; def.pose = POSE_HIT; def.crouch = false
  def.vx = -def.face * push
  if a ~= nil and a.launch == true and att.state == "attack" then def.vy = -6; def.timer = stun + 10
  elseif def.y < FLOOR_Y then def.vy = -3 end
  def.flash = 8
  att.meter = min(METER_MAX, att.meter + 12)
  def.meter = min(METER_MAX, def.meter + 6)
  spawn_spark(hx, hy, 8)
  if heavy then spawn_spark(hx + 6, hy - 6, 11) end
  if heavy then
    sfx(SND_DEEP, 7, "C2"); sfx(SND_CRACK, 6, "G3"); sfx(SND_SMACK, 5, "A3")
  else
    sfx(SND_DEEP, 7, "G2"); sfx(SND_SMACK, 6, "D4")
  end
  if (def.face == 1 and def.x <= -6) or (def.face == -1 and def.x >= 198) then att.push_t = 8 end
  if att.state == "attack" and att.combo ~= nil and att.combo >= 2 then
    ROUND.combo_t = 50; ROUND.combo_n = att.combo; ROUND.combo_side = att.slot
  end
  if def.hp <= 0 then
    def.state = "ko"; def.timer = 0; def.pose = POSE_KO; def.vy = -5; def.vx = -def.face * 3.5
    sfx(SND_KO, 4, "C4")
  end
  return true
end

local last_round_state = ""
local base_draw_sprites = draw_sprites
function draw_sprites()
  if not break_tiles_ready then upload_breakables() end
  if ROUND.state == "intro" and last_round_state ~= "intro" then spawn_objects() end
  if ROUND.state == "title" or ROUND.state == "select" then OBJECTS = {} end
  last_round_state = ROUND.state
  if P1 ~= nil and P2 ~= nil and ROUND.state ~= "title" and ROUND.state ~= "select" then check_objects() end
  for _, s in ipairs(SPARKS) do
    if s.frag == true then s.x = s.x + s.vx; s.y = s.y + s.vy; s.vy = s.vy + 0.3 end
  end
  base_draw_sprites()
  for i, f in ipairs({ P1, P2 }) do
    if f ~= nil then
      local o = obj[i - 1]
      o.on = true
      if f.state == "idle" and (f.anim // 16) % 2 == 1 then o.y = o.y + 1 end
      local tint = (i == 2 and P1 ~= nil and P2 ~= nil and P1.char == P2.char)
      if f.flash > 0 and f.flash % 2 == 0 then
        for k = 1, 15 do cgram[128 + (f.slot - 1) * 16 + k] = rgb(255, 255, 255) end
        f.flash_dirty = true
      elseif f.flash_dirty == true then
        load_char_palette(f.slot - 1, f.char, tint)
        f.flash_dirty = false
      end
    end
  end
  for i = 1, 2 do
    local o = OBJECTS[i]
    local s = obj[15 + i]
    if o ~= nil and o.alive then
      s.tile = fx_tile(o.cell); s.pal = 2; s.large = false; s.x = o.x; s.y = o.y; s.prio = 2; s.flip_x = false; s.on = true
    else
      s.on = false
    end
  end
  if ROUND.combo_t ~= nil and ROUND.combo_t > 0 then
    ROUND.combo_t = ROUND.combo_t - 1
    local msg = ROUND.combo_n .. " HIT COMBO!"
    if ROUND.combo_side == 1 then text(1, 5, msg) else text(31 - string.len(msg), 5, msg) end
    if ROUND.combo_t == 0 then clear_row(5) end
  end
end
