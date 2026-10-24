-- cps.lua: the Capcom CPS-1 look. Runs after smooth.lua.
--  * dark COLOURED outlines per character (a deep tint of the body colour, not near-black)
--  * cel shading in hard bands: the checker specular from art.lua is filled into a solid highlight band
--  * species-specific hands and feet redrawn over the front hand/foot: a knuckled fist for the human, toed paws
--    (with claws on bear/kitten, pink pads on bunny/kitten), a cloven trotter for the piglet, a feathered
--    wingtip and webbed foot for the duck, a pincer and a little boot for the bug
--  * environments muted ~16% toward a warm grey so the saturated fighters sit in front of them
--  * fake camera: a soft pan toward the fighters drives layered parallax (sky < hills/mid < floor) and
--    line-by-line row scroll on the floor plane, the CPS trick for perspective
--  * Arlo the puppy is a black-and-tan pup (tan muzzle + belly patch, black nose), not bear/duck gold
CHARS[2].pal = { {18,16,22}, {24,22,28}, {54,50,60}, {92,86,100}, {248,248,255}, {194,198,216}, {32,28,36}, {64,58,70},
                 {255,255,255}, {26,16,32}, {240,138,160}, {214,152,82}, {18,14,20}, {126,118,136}, {255,224,102} }
CHAR_PAL[2] = CHARS[2].pal
local OUTLINE = { {72,34,24}, {18,16,22}, {38,36,80}, {98,30,62}, {98,62,10}, {58,30,14}, {56,56,94}, {14,22,80} }
for i = 1, 8 do CHARS[i].pal[1] = OUTLINE[i] end

local S, OX, OY = 1.8, 3.2, 7.2
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
local function effective(ci, pi)
  local an = ANIM_POSE[pi]
  if an ~= nil then
    local A, B = stance_pose(ci, an.a), stance_pose(ci, an.b)
    if A == nil or B == nil then return nil end
    local r = { neck = lerp_pt(A.neck, B.neck, an.t), hip = lerp_pt(A.hip, B.hip, an.t) }
    for _, k in ipairs({ "farm", "fleg", "barm", "bleg" }) do
      r[k] = { lerp_pt(A[k][1], B[k][1], an.t), lerp_pt(A[k][2], B[k][2], an.t) }
    end
    return r
  end
  return stance_pose(ci, pi)
end

-- ---------------------------------------------------------------- canvas helpers (64x64 index canvas)
local function put(c, x, y, v)
  x = floor(x); y = floor(y)
  if x >= 0 and x < 64 and y >= 0 and y < 64 then c[y * 64 + x] = v end
end
local function blob(c, cx, cy, rx, ry, col, outlined)
  local function inside(x, y) local ex, ey = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry return ex * ex + ey * ey <= 1 end
  for y = max(0, floor(cy - ry) - 1), min(63, floor(cy + ry) + 1) do
    for x = max(0, floor(cx - rx) - 1), min(63, floor(cx + rx) + 1) do
      if inside(x, y) then
        local v
        if outlined and not (inside(x - 1, y) and inside(x + 1, y) and inside(x, y - 1) and inside(x, y + 1)) then
          v = 1
        else
          local nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
          local l = -(nx * 0.7 + ny * 0.7)
          if l > 0.38 then v = col[3] elseif l < -0.28 then v = col[2] else v = col[1] end
        end
        c[y * 64 + x] = v
      end
    end
  end
end
local function vline(c, x, y0, y1, v) for y = y0, y1 do put(c, x, y, v) end end
local function hline(c, x0, x1, y, v) for x = x0, x1 do put(c, x, y, v) end end
local function wedge(c, x0, y, len, half, v)
  for dx = 0, len do
    local h = half * (1 - dx / len)
    for dy = -h, h do put(c, x0 + dx, y + dy, v) end
  end
end

-- hands follow the forearm: (dx, dy) is the unit vector elbow -> hand in canvas space. A bent arm (guard, chamber)
-- gets a closed fist with the knuckles on the leading side; an extended arm gets the species' open fingers,
-- claws, trotter, wingtip or pincer pointing the way the arm points.
local function draw_hand(c, ch, cx, cy, col, dx, dy, ext)
  local k = ch.kind
  local function at(ox, oy) return cx + ox * dx - oy * dy, cy + ox * dy + oy * dx end
  local function dot(ox, oy, v) local x, y = at(ox, oy); put(c, x, y, v) end
  local function seg(ox0, oy0, ox1, oy1, v)
    local n = max(abs(ox1 - ox0), abs(oy1 - oy0))
    for i = 0, n do local t = (n == 0) and 0 or i / n; dot(ox0 + (ox1 - ox0) * t, oy0 + (oy1 - oy0) * t, v) end
  end
  if not ext then
    -- closed fist (paw / trotter / wing curled): round, knuckle marks on the leading edge, thumb crease behind
    local rx = (k == "piglet" or k == "bear") and 3.1 or 2.9
    blob(c, cx, cy, rx * S, 2.8 * S, col, true)
    if k == "duck" then
      seg(1.2 * S, -1.4 * S, 1.2 * S, 1.4 * S, col[2])
    elseif k == "bug" then
      seg(1.6 * S, -1.2 * S, 2.6 * S, 0, 1); seg(1.6 * S, 1.2 * S, 2.6 * S, 0, 1)
    else
      for i = -1, 1 do dot(2.2 * S, i * 1.2 * S, 1); dot(2.2 * S - 1, i * 1.2 * S, col[2]) end
      seg(-1.6 * S, 1.2 * S, 0.2 * S, 1.9 * S, col[2])
      if k == "bunny" or k == "kitten" then local x, y = at(-0.6 * S, 0.6 * S); blob(c, x, y, 1.1 * S, 0.9 * S, { 11, 11, 11 }, false) end
    end
    return
  end
  if k == "human" then
    blob(c, cx, cy, 3.1 * S, 2.7 * S, col, true)
    local tx, ty = at(-1.9 * S, -1.2 * S)
    blob(c, tx, ty, 1.3 * S, 1.1 * S, col, true)
    for i = -1, 1 do dot(1.6 * S, i * 1.1 * S, 1); dot(1.6 * S - 1, i * 1.1 * S, col[2]) end
    seg(2.6 * S, -0.4 * S, 2.6 * S, 1.0 * S, col[2])
  elseif k == "piglet" then
    blob(c, cx, cy, 2.9 * S, 2.6 * S, col, true)
    seg(1.1 * S, -1.9 * S, 1.1 * S, 1.9 * S, 1)
    seg(1.1 * S + 1, -1.5 * S, 1.1 * S + 1, 1.5 * S, col[2])
  elseif k == "duck" then
    local bx, by = at(-0.4 * S, 0)
    blob(c, bx, by, 2.6 * S, 2.4 * S, col, true)
    for i = -1, 1 do local fx, fy = at(2.2 * S, i * 1.7 * S); blob(c, fx, fy, 1.5 * S, 1.2 * S, col, true) end
  elseif k == "bug" then
    blob(c, cx, cy, 3.0 * S, 2.6 * S, col, true)
    seg(0.4 * S, -1.6 * S, 3.8 * S, -0.2 * S, 1); seg(0.4 * S, 1.6 * S, 3.8 * S, 0.2 * S, 1)
    seg(1.0 * S, -1.1 * S, 3.2 * S, -0.3 * S, col[1]); seg(1.0 * S, 1.1 * S, 3.2 * S, 0.3 * S, col[1])
    dot(2.6 * S, -2.0 * S, 1); dot(2.6 * S, 2.0 * S, 1)
  else
    blob(c, cx, cy, 2.9 * S, 2.7 * S, col, true)
    for i = -1, 1 do local tx, ty = at(2.3 * S, i * 1.6 * S); blob(c, tx, ty, 1.15 * S, 1.05 * S, col, true) end
    local pad = (k == "bunny" or k == "kitten") and { 11, 11, 11 } or { col[2], col[2], col[2] }
    local px, py = at(-0.5 * S, 0.4 * S)
    blob(c, px, py, 1.3 * S, 1.0 * S, pad, false)
    if k == "bear" or k == "kitten" then
      for i = -1, 1 do seg(3.4 * S, i * 1.6 * S, 3.4 * S + 2, i * 1.6 * S, 1) end
    end
  end
end

-- feet: planted feet lie flat (toes forward); a lifted foot points along the shin (knee -> foot)
local function draw_foot(c, ch, cx, cy, col, dx, dy, lifted)
  local k = ch.kind
  if not lifted then dx, dy = 1, 0 end
  local function at(ox, oy) return cx + ox * dx - oy * dy, cy + ox * dy + oy * dx end
  local function dot(ox, oy, v) local x, y = at(ox, oy); put(c, x, y, v) end
  local function seg(ox0, oy0, ox1, oy1, v)
    local n = max(abs(ox1 - ox0), abs(oy1 - oy0))
    for i = 0, n do local t = (n == 0) and 0 or i / n; dot(ox0 + (ox1 - ox0) * t, oy0 + (oy1 - oy0) * t, v) end
  end
  if k == "human" then
    local bx, by = at(0.3 * S, 0)
    blob(c, bx, by, 3.7 * S, 2.1 * S, col, true)
    local hx, hy = at(-2.6 * S, -0.3 * S)
    blob(c, hx, hy, 1.4 * S, 1.6 * S, col, true)
    seg(2.2 * S, -1.0 * S, 2.2 * S, 1.0 * S, col[2])
    for i = 0, 2 do dot(3.2 * S - i, -1.6 * S + i * 0.4, 1) end
  elseif k == "duck" then
    local orange = { 7, 7, 8 }
    local bx, by = at(-0.6 * S, 0)
    blob(c, bx, by, 2.4 * S, 1.6 * S, orange, true)
    for i = -1, 1 do local tx, ty = at(2.4 * S, i * 1.5 * S); blob(c, tx, ty, 1.6 * S, 0.9 * S, orange, true) end
    for ox = 0.8 * S, 3.0 * S do
      local h = 1.5 * S * (1 - (ox - 0.8 * S) / (2.2 * S))
      for oy = -h, h do local x, y = at(ox, oy); if c[floor(y) * 64 + floor(x)] == 0 then put(c, x, y, 7) end end
    end
  elseif k == "piglet" then
    blob(c, cx, cy, 3.1 * S, 2.0 * S, col, true)
    seg(1.3 * S, -1.6 * S, 1.3 * S, 1.6 * S, 1)
    seg(-2.4 * S, 1.1 * S, 2.6 * S, 1.1 * S, col[2])
  elseif k == "bug" then
    blob(c, cx, cy, 2.8 * S, 1.8 * S, col, true)
    seg(-2.2 * S, 0.6 * S, 2.2 * S, 0.6 * S, col[2])
  else
    local rx = (k == "bunny") and 4.4 or 3.4
    blob(c, cx, cy, rx * S, 2.1 * S, col, true)
    for i = -1, 1 do local tx, ty = at((rx - 0.4) * S, i * 1.3 * S); blob(c, tx, ty, 1.1 * S, 0.9 * S, col, true) end
    if k == "bear" or k == "kitten" then
      for i = -1, 1 do seg((rx + 0.9) * S, i * 1.3 * S, (rx + 0.9) * S + 2, i * 1.3 * S, 1) end
    end
  end
end

local function unit(a, b)
  local dx, dy = b[1] - a[1], b[2] - a[2]
  local L = (dx * dx + dy * dy) ^ 0.5
  if L < 0.01 then return 1, 0, 0 end
  return dx / L, dy / L, L
end

local base_render_pose = render_pose
function render_pose(ci, pi)
  local c = base_render_pose(ci, pi)
  local ch = CHARS[ci]
  local p = effective(ci, pi)
  local col = ch.limb or { 3, 2, 4 }
  if p ~= nil and p.fleg ~= nil then
    local kn, ft = p.fleg[1], p.fleg[2]
    local dx, dy = unit(kn, ft)
    draw_foot(c, ch, (ft[1] + 0.6) * S + OX, (ft[2] - 0.4) * S + OY, col, dx, dy, ft[2] < 29)
  end
  if p ~= nil and p.barm ~= nil then
    -- the far hand, darker; only when it is not hidden behind the body
    local e, h = p.barm[1], p.barm[2]
    local dx, dy, L = unit(e, h)
    local behind = h[1] > p.neck[1] - 4 and h[1] < p.neck[1] + 5 and h[2] > p.neck[2] + 1 and h[2] < p.hip[2] + 3
    if not behind then draw_hand(c, ch, h[1] * S + OX, h[2] * S + OY, { col[2], col[2], col[1] }, dx, dy, L >= 6.2) end
  end
  if p ~= nil and p.farm ~= nil then
    local e, h = p.farm[1], p.farm[2]
    local dx, dy, L = unit(e, h)
    draw_hand(c, ch, h[1] * S + OX, h[2] * S + OY, col, dx, dy, L >= 6.2)
  end
  for y = 1, 62 do
    for x = 1, 62 do
      local k = y * 64 + x
      if c[k] == 4 then
        local n = 0
        if c[k - 1] == 14 then n = n + 1 end
        if c[k + 1] == 14 then n = n + 1 end
        if c[k - 64] == 14 then n = n + 1 end
        if c[k + 64] == 14 then n = n + 1 end
        if n >= 2 then c[k] = 14 end
      end
    end
  end
  return c
end

local function mute(c, k) return { floor(c[1] + (140 - c[1]) * k), floor(c[2] + (134 - c[2]) * k), floor(c[3] + (122 - c[3]) * k) } end
local MUTE_KEYS = { "fol_dark", "fol_light", "wood_dark", "wood_light", "wall_dark", "wall_light", "ground_dark", "ground_light",
  "water_dark", "water_light", "hill_dark", "hill_light", "prop_a", "prop_b", "prop_c", "prop_d", "acc_a", "acc_b" }
for i = 1, 8 do
  for _, k in ipairs(MUTE_KEYS) do SCENES[i].p[k] = mute(SCENES[i].p[k], 0.16) end
end

local function lerp3(a, b, t) return { floor(a[1] + (b[1] - a[1]) * t + 0.5), floor(a[2] + (b[2] - a[2]) * t + 0.5), floor(a[3] + (b[3] - a[3]) * t + 0.5) } end
CAM = 0
function stage_sky()
  local ci = CURRENT_STAGE
  local sc = SCENES[ci]
  local a = AMBIENT[ci]
  local sw, dr = nil, nil
  if a ~= nil then sw = a.sway; dr = a.drift end
  local tt = AMB_T or 0
  local keys = SKY_KEYS
  local cam = CAM
  hdma(0, 159, function(y)
    cgram[0] = ramp_color(keys, y)
    local sx = 0
    if dr ~= nil and y >= dr[1] and y <= dr[2] then sx = floor(tt * dr[3]) % 256 end
    if sw ~= nil and y >= sw[1] and y <= sw[2] then sx = sx + sin(tt * 1.5 + y / sw[4]) * sw[3] end
    if y >= 100 then sx = sx - cam * 0.10 elseif y >= 60 then sx = sx - cam * 0.04 end
    if ci == 1 and y >= 119 then sx = sx + sin(tt * 2.5 + y / 5) * 1.5 end
    bg[2].scroll.x = sx
  end)
  if sc == nil then return end
  local gd, gl = sc.p.ground_dark, sc.p.ground_light
  local ramp = {}
  for i = 1, 6 do ramp[i] = lerp3(gd, gl, (i - 1) / 5) end
  hdma(160, 223, function(y)
    local k = 1.05 - (y - 160) / 64 * 0.42
    for i = 1, 6 do
      local c = ramp[i]
      cgram[i] = rgb(min(255, floor(c[1] * k)), min(255, floor(c[2] * k)), min(255, floor(c[3] * k)))
    end
    local sx = -cam * (0.12 + 0.24 * (y - 160) / 64)
    if ci == 5 then sx = sx + sin(tt * 2.5 + y / 5) * 1.5 end
    bg[2].scroll.x = sx
  end)
end

local base_frame = frame
function frame(t, f)
  local target = 0
  if P1 ~= nil and P2 ~= nil and ROUND.state ~= "title" and ROUND.state ~= "select" then
    target = (P1.x + P2.x) / 2 + 32 - 128
    if target > 40 then target = 40 elseif target < -40 then target = -40 end
  end
  CAM = CAM + (target - CAM) * 0.08
  base_frame(t, f)
end
