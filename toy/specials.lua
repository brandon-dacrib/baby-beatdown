-- specials.lua: crouch-punch projectiles for four characters (down + punch), runs after combat.lua
SPECIAL = {
  [1] = { cell = 16, name = "BINKY SHOT",  speed = 3.2, dmg = 6 },
  [3] = { cell = 17, name = "YARN BALL",   speed = 2.8, dmg = 6 },
  [5] = { cell = 18, name = "BUBBLE",      speed = 2.0, dmg = 5, wobble = true },
  [8] = { cell = 19, name = "SPIT GLOB",   speed = 3.6, dmg = 6 },
}
ATTACKS.shoot = { startup = 8, active = 1, recover = 16, dmg = 0, stun = 0, pose = POSE_PUNCH, x0 = 0, x1 = 0, y0 = 0, y1 = 0, shoot = true }

local tiles_ready = false
local function inside(x, y, cx, cy, rx, ry) local ex, ey = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry return ex * ex + ey * ey <= 1 end
local function with_outline(fn)
  return function(x, y)
    local v = fn(x, y)
    if v == 0 then return 0 end
    if fn(x - 1, y) == 0 or fn(x + 1, y) == 0 or fn(x, y - 1) == 0 or fn(x, y + 1) == 0 then return 1 end
    return v
  end
end
local function cell_pixels(cell, fn)
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
local function upload_special_tiles()
  cell_pixels(16, with_outline(function(x, y)
    if inside(x, y, 8, 9, 5.5, 3.5) then return 9 end
    if inside(x, y, 8, 4, 3, 3) and not inside(x, y, 8, 4, 1.4, 1.4) then return 8 end
    return 0
  end))
  cell_pixels(17, with_outline(function(x, y)
    if not inside(x, y, 8, 8, 6, 6) then return 0 end
    if (x + y) % 5 == 0 or (x - y) % 7 == 0 then return 6 end
    return 8
  end))
  cell_pixels(18, with_outline(function(x, y)
    if inside(x, y, 8, 8, 5.5, 5.5) then return inside(x, y, 6, 6, 1.5, 1.5) and 5 or 14 end
    return 0
  end))
  cell_pixels(19, with_outline(function(x, y)
    if inside(x, y, 9, 8, 6, 4) or inside(x, y, 3, 8, 2.5, 2) then return (y < 7) and 13 or 12 end
    return 0
  end))
  tiles_ready = true
end

local function owns_projectile(f)
  for _, p in ipairs(PROJ) do if p.owner == f and p.special == true then return true end end
  return false
end

local base_update_fighter = update_fighter
function update_fighter(f, opp, allow_input)
  if not tiles_ready then upload_special_tiles() end
  local sp = SPECIAL[f.char]
  local grounded = f.state == "idle" or f.state == "walk" or f.state == "crouch"
  if allow_input and sp ~= nil and grounded and f.inp.down and f.inp.punch and not owns_projectile(f) then
    f.state = "attack"; f.atk = ATTACKS.shoot; f.timer = 0; f.hitdone = 0; f.pose = POSE_PUNCH; f.combo = 0
    f.crouch = false; f.vx = 0
    f.face = (opp.x > f.x) and 1 or -1
    f.inp.punch = false
    sfx(SND_WHIFF, 7, "E5")
  end
  base_update_fighter(f, opp, allow_input)
  if f.state == "attack" and f.atk == ATTACKS.shoot and f.timer == ATTACKS.shoot.startup then
    local px = (f.face == 1) and f.x + 46 or f.x + 2
    PROJ[#PROJ + 1] = { x = px, y = f.y + 24, vx = f.face * sp.speed, cell = sp.cell, owner = f,
      dmg = sp.dmg, t = 0, wobble = sp.wobble, life = 300, special = true }
    sfx(SND_SEL, 6, "C6")
  end
end

local base_cpu_input = cpu_input
function cpu_input(f, opp)
  base_cpu_input(f, opp)
  if SPECIAL[f.char] ~= nil and abs(opp.x - f.x) > 90 and rnd() < 0.03 then
    f.inp.down = true; f.inp.punch = true
  end
end
