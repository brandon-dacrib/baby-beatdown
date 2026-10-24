-- faces.lua: expressions, feet on the ground, a kickable ball. Runs after react.lua.
--  * faces react: angry brows + a yell when striking, gritted teeth when blocking or grabbing, "oof" and
--    X eyes when hurt, a tongue out at KO, closed happy eyes and a grin when celebrating, idle blinks
--  * ground contact: every planted foot gets a dark sole line on the sprite's bottom row and a dust puff
--    marks every landing (drawn just below the feet line, where the scanline budget has room)
--  * a beach ball sits in the Yard, Farm and Garden stages: strikes send it flying, it bounces off the walls,
--    and a fast ball that hits the other baby knocks them for 5 (credited to whoever kicked it)
local S, OX, OY = 1.8, 3.2, 7.2
local function TX(x) return x * S + OX end
local function TY(y) return y * S + OY end
local function put(c, x, y, v)
  x = floor(x); y = floor(y)
  if x >= 0 and x < 64 and y >= 0 and y < 64 then c[y * 64 + x] = v end
end
local function rect(c, x0, y0, w, h, v) for y = y0, y0 + h - 1 do for x = x0, x0 + w - 1 do put(c, x, y, v) end end end
local function hline(c, x0, x1, y, v) for x = x0, x1 do put(c, x, y, v) end end
local function lerp_pt(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t } end
local function stance_pose(ci, pi)
  local base = POSES[pi]
  if base == nil then return nil end
  if pi <= 2 and STANCE ~= nil and STANCE[ci] ~= nil then
    local m = {}
    for k, v in pairs(base) do m[k] = v end
    for k, v in pairs(STANCE[ci]) do m[k] = v end
    if pi ~= 0 then m.bleg = base.bleg; m.fleg = base.fleg end
    return m
  end
  return base
end
-- head centre (canvas px), expression, hurt flag and the two feet for any pose id, lerped like the renderer does
local function pose_info(ci, pi)
  local ch = CHARS[ci]
  local an = ANIM_POSE[pi]
  local neck, ho, hc, expr, hurt, fleg, bleg
  if an ~= nil then
    local A, B = stance_pose(ci, an.a), stance_pose(ci, an.b)
    if A == nil or B == nil then return nil end
    neck = lerp_pt(A.neck, B.neck, an.t); ho = { 0, 0 }; hc = nil
    expr = an.expr
    if expr == nil and an.t > 0.2 then expr = B.expr end
    hurt = false
    fleg = lerp_pt(A.fleg[2], B.fleg[2], an.t); bleg = lerp_pt(A.bleg[2], B.bleg[2], an.t)
  else
    local p = stance_pose(ci, pi)
    if p == nil then return nil end
    neck = p.neck; ho = p.headoff or { 0, 0 }; hc = p.headc; expr = p.expr; hurt = p.hurt == true
    fleg = p.fleg[2]; bleg = p.bleg[2]
  end
  if hc == nil then hc = { neck[1] + ho[1], neck[2] - ch.head[2] + 1 + ho[2] } end
  return { cx = TX(hc[1]), cy = TY(hc[2]), expr = expr, hurt = hurt, fleg = fleg, bleg = bleg }
end

local function brows(c, ex, ey)
  put(c, ex, ey - 3, 1); put(c, ex + 1, ey - 2, 1); put(c, ex + 2, ey - 2, 1); put(c, ex + 3, ey - 1, 1)
  put(c, ex + 8, ey - 1, 1); put(c, ex + 9, ey - 2, 1); put(c, ex + 10, ey - 2, 1); put(c, ex + 11, ey - 3, 1)
end
local function closed_eyes(c, ex, ey, skin, happy)
  rect(c, ex, ey - 1, 4, 7, skin); rect(c, ex + 8, ey - 1, 4, 7, skin)
  for _, ox in ipairs({ 0, 8 }) do
    if happy then
      put(c, ex + ox, ey + 3, 1); put(c, ex + ox + 1, ey + 2, 1); put(c, ex + ox + 2, ey + 2, 1); put(c, ex + ox + 3, ey + 3, 1)
    else
      hline(c, ex + ox, ex + ox + 3, ey + 3, 1)
    end
  end
end
local function muzzle(kind) return kind == "puppy" or kind == "bear" or kind == "piglet" end
local function draw_expr(c, ci, info)
  local ch = CHARS[ci]
  local kind = ch.kind
  local cx, cy = floor(info.cx), floor(info.cy)
  local ex, ey = cx - 1, cy - 4
  local skin = (kind == "bug") and ch.limb[1] or 3
  local e = info.expr
  if e == "yell" then
    brows(c, ex, ey)
    if kind == "human" then rect(c, cx + 2, cy + 6, 7, 4, 1); rect(c, cx + 3, cy + 7, 5, 2, 11)
    elseif kind == "puppy" or kind == "bear" then rect(c, cx + 6, cy + 6, 5, 3, 1); rect(c, cx + 7, cy + 7, 3, 1, 11)
    elseif kind == "piglet" then rect(c, cx + 4, cy + 8, 5, 3, 1); rect(c, cx + 5, cy + 9, 3, 1, 11)
    elseif kind == "duck" then hline(c, cx + 5, cx + 16, cy + 4, 1); rect(c, cx + 7, cy + 5, 8, 2, 11); hline(c, cx + 6, cx + 15, cy + 7, 1)
    elseif kind == "bug" then rect(c, cx + 3, cy + 5, 6, 3, 1); rect(c, cx + 4, cy + 6, 4, 1, 11)
    else rect(c, cx + 4, cy + 7, 4, 3, 1); rect(c, cx + 5, cy + 8, 2, 1, 11) end
  elseif e == "grit" then
    brows(c, ex, ey)
    if kind == "human" then rect(c, cx + 2, cy + 6, 7, 2, 1); hline(c, cx + 3, cx + 7, cy + 7, 9)
    elseif kind == "kitten" or kind == "bunny" or kind == "bug" then hline(c, cx + 3, cx + 8, cy + 7, 1) end
  elseif e == "happy" then
    closed_eyes(c, ex, ey, skin, true)
    if kind == "human" then rect(c, cx + 1, cy + 6, 9, 4, 1); rect(c, cx + 2, cy + 7, 7, 1, 9); rect(c, cx + 2, cy + 8, 7, 1, 11)
    elseif muzzle(kind) then hline(c, cx + 6, cx + 10, cy + 7, 1); put(c, cx + 5, cy + 6, 1); put(c, cx + 11, cy + 6, 1)
    elseif kind ~= "duck" then put(c, cx + 3, cy + 6, 1); hline(c, cx + 4, cx + 7, cy + 7, 1); put(c, cx + 8, cy + 6, 1) end
  elseif e == "blink" then
    closed_eyes(c, ex, ey, skin, false)
  elseif e == "oof" then
    local mx = muzzle(kind) and cx + 7 or cx + 4
    rect(c, mx, cy + 7, 3, 3, 1); put(c, mx + 1, cy + 8, 11)
  elseif e == "ko" then
    local mx = muzzle(kind) and cx + 8 or cx + 5
    rect(c, mx, cy + 9, 2, 3, 11); put(c, mx - 1, cy + 9, 1); put(c, mx + 2, cy + 9, 1)
  end
end

local base_render_pose = render_pose
function render_pose(ci, pi)
  local c = base_render_pose(ci, pi)
  local info = pose_info(ci, pi)
  if info == nil then return c end
  if info.expr ~= nil then draw_expr(c, ci, info) end
  -- soles: a dark contact line on the bottom row under every planted foot
  local rx = ((CHARS[ci].kind == "bunny") and 4.4 or 3.4) * S * 0.9
  for _, ft in ipairs({ info.fleg, info.bleg }) do
    if ft[2] >= 29.5 then
      local fx = (ft[1] + 0.6) * S + OX
      for x = floor(fx - rx), floor(fx + rx) do
        if x >= 0 and x < 64 and c[62 * 64 + x] ~= 0 then c[63 * 64 + x] = 1 end
      end
    end
  end
  return c
end

-- ---------------------------------------------------------------- the ball
BALL_TILE = 288
BALL_STAGES = { [2] = true, [4] = true, [7] = true }
BALL = nil
local ball_ready = false
local function upload_ball()
  local function pix(x, y)
    local ex, ey = (x + 0.5 - 8) / 7.5, (y + 0.5 - 8) / 7.5
    local d = ex * ex + ey * ey
    if d > 1 then return 0 end
    if d > 0.78 then return 1 end
    if (x + 0.5 - 8) * 0.7 - (y + 0.5 - 8) * 0.7 > 4.5 then return 5 end
    local band = floor((x + y) / 4) % 3
    if ex * 0.7 + ey * 0.7 > 0.55 then return 1 end
    if band == 0 then return 10 elseif band == 1 then return 15 else return 14 end
  end
  for ty = 0, 1 do
    for tx = 0, 1 do
      local addr = OBJ_BASE + (BALL_TILE + ty * 16 + tx) * 16
      for row = 0, 7 do
        local p0, p1, p2, p3 = 0, 0, 0, 0
        for col = 0, 7 do
          local v = pix(tx * 8 + col, ty * 8 + row)
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
  ball_ready = true
end
local BALL_REST = FLOOR_Y + 38
local function box_hit(ax0, ay0, ax1, ay1, bx, by)
  return ax0 < bx + 14 and bx + 2 < ax1 and ay0 < by + 16 and by + 2 < ay1
end
local function attack_box_of(f)
  local a = f.atk
  local x0, x1
  if f.face == 1 then x0, x1 = f.x + a.x0, f.x + a.x1 else x0, x1 = f.x + 64 - a.x1, f.x + 64 - a.x0 end
  return x0, f.y + a.y0, x1, f.y + a.y1
end
local function update_ball()
  local b = BALL
  if b == nil then return end
  if b.cool > 0 then b.cool = b.cool - 1 end
  b.vy = b.vy + 0.3
  b.y = b.y + b.vy
  if b.y >= BALL_REST then
    b.y = BALL_REST
    if b.vy > 0.8 then b.vy = -b.vy * 0.5; sfx(SND_BLOCK, 6, "C5") else b.vy = 0 end
  end
  b.x = b.x + b.vx
  if b.y >= BALL_REST then b.vx = b.vx * 0.96 else b.vx = b.vx * 0.995 end
  if abs(b.vx) < 0.08 then b.vx = 0 end
  if b.x < 0 then b.x = 0; b.vx = -b.vx * 0.7; sfx(SND_BLOCK, 6, "E4") end
  if b.x > 240 then b.x = 240; b.vx = -b.vx * 0.7; sfx(SND_BLOCK, 6, "E4") end
  for _, f in ipairs({ P1, P2 }) do
    if f ~= nil and b.cool == 0 then
      local a = f.atk
      if f.state == "attack" and a ~= nil and f.timer > a.startup and f.timer <= a.startup + a.active then
        local x0, y0, x1, y1 = attack_box_of(f)
        if box_hit(x0, y0, x1, y1, b.x, b.y) then
          b.vx = f.face * (5 + rnd() * 2.5); b.vy = -3 - rnd() * 2.5; b.last = f; b.cool = 10
          spawn_spark(b.x + 8, b.y + 8, 9)
          sfx(SND_BLOCK, 6, "G4"); sfx(SND_SMACK, 5, "C4")
        end
      elseif f.state == "walk" then
        local bx0, by0, bx1, by1 = body_box(f)
        if box_hit(bx0, by0, bx1, by1, b.x, b.y) then b.vx = f.face * 1.8; b.vy = -1; b.last = f; b.cool = 6 end
      end
    end
  end
  if abs(b.vx) > 2.5 and b.last ~= nil and b.cool == 0 then
    for _, g in ipairs({ P1, P2 }) do
      if g ~= nil and g ~= b.last and g.state ~= "ko" and g.state ~= "hit" and g.state ~= "held" then
        local bx0, by0, bx1, by1 = body_box(g)
        if box_hit(bx0, by0, bx1, by1, b.x, b.y) then
          apply_hit(b.last, g, 5, 14, false, false, b.x + 8, b.y + 8, 3)
          b.vx = -b.vx * 0.6; b.vy = -2; b.cool = 14
        end
      end
    end
  end
end

local last_state = ""
local base_draw_sprites = draw_sprites
function draw_sprites()
  if not ball_ready then upload_ball() end
  local st = ROUND.state
  if st == "title" or st == "select" then
    BALL = nil
  elseif st == "intro" and last_state ~= "intro" then
    if BALL_STAGES[CURRENT_STAGE] == true then BALL = { x = 112, y = BALL_REST, vx = 0, vy = 0, last = nil, cool = 0 } else BALL = nil end
  end
  last_state = st
  -- landing dust
  for _, f in ipairs({ P1, P2 }) do
    if f ~= nil and st ~= "title" and st ~= "select" then
      if f.prev_y ~= nil and f.prev_y < FLOOR_Y - 2 and f.y >= FLOOR_Y and #SPARKS < 3 then
        spawn_spark(f.x + 32, FLOOR_Y + 72, 9)   -- puff below the feet line: keeps the foot scanlines under the sliver budget
      end
      f.prev_y = f.y
    end
  end
  if BALL ~= nil and st ~= "title" and st ~= "select" and P1 ~= nil and P2 ~= nil then update_ball() end
  base_draw_sprites()
  local o = obj[18]
  if BALL ~= nil then
    o.tile = BALL_TILE; o.pal = 2; o.large = false; o.prio = 2
    o.x = floor(BALL.x); o.y = floor(BALL.y)
    local q = floor(BALL.x / 6) % 4
    o.flip_x = (q == 1 or q == 2); o.flip_y = (q >= 2); o.on = true
  else
    o.on = false
  end
end
