-- strikes.lua: animated strikes (wind-up / extended / recovery frames built by interpolating poses), longer reach,
-- extra strike types with direction modifiers. Runs after combat/specials/ambient.
POSES[3].farm = {{23,15},{31,15}}
POSES[4].fleg = {{23,20},{31,17}}
POSES[12].barm = {{20,15},{30,14}}
POSES[14].fleg = {{21,14},{30,6}}
ATTACKS.jab.x1 = 66; ATTACKS.punch.x1 = 66
ATTACKS.cross.x1 = 68
ATTACKS.kick.x1 = 70
ATTACKS.highkick.x1 = 70
POSES[15] = { neck = {15,13}, hip = {13,22}, barm = {{10,18},{12,15}}, farm = {{23,11},{31,16}}, bleg = {{9,27},{8,31}}, fleg = {{19,27},{20,31}} }
POSES[16] = { neck = {11,13}, hip = {13,21}, barm = {{6,16},{8,13}},   farm = {{16,16},{18,13}},  bleg = {{9,27},{8,31}}, fleg = {{22,14},{31,10}} }
POSES[17] = { neck = {15,13}, hip = {14,21}, barm = {{19,17},{23,14}}, farm = {{21,19},{24,15}},  bleg = {{10,27},{9,31}}, fleg = {{21,19},{22,15}} }
POSE_HOOK, POSE_ROUNDHOUSE, POSE_KNEE = 15, 16, 17
ATTACKS.hook       = { startup = 6, active = 6, recover = 12, dmg = 10, stun = 18, pose = POSE_HOOK,       x0 = 40, x1 = 68, y0 = 14, y1 = 30 }
ATTACKS.roundhouse = { startup = 8, active = 7, recover = 14, dmg = 14, stun = 22, pose = POSE_ROUNDHOUSE, x0 = 42, x1 = 70, y0 = 10, y1 = 34, high = true }
ATTACKS.knee       = { startup = 4, active = 6, recover = 10, dmg = 9,  stun = 16, pose = POSE_KNEE,       x0 = 36, x1 = 56, y0 = 24, y1 = 44 }

ANIM_POSE = {}
local next_id = 20
local function lerp_pt(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t } end
local function lerp_pose(A, B, t)
  local P = {}
  P.neck = lerp_pt(A.neck, B.neck, t); P.hip = lerp_pt(A.hip, B.hip, t)
  for _, k in ipairs({ "barm", "farm", "bleg", "fleg" }) do
    P[k] = { lerp_pt(A[k][1], B[k][1], t), lerp_pt(A[k][2], B[k][2], t) }
  end
  return P
end
local function anim_id(a, b, t)
  local id = next_id
  next_id = next_id + 1
  ANIM_POSE[id] = { a = a, b = b, t = t }
  return id
end
for _, name in ipairs({ "jab", "cross", "upper", "kick", "highkick", "sweep", "hook", "roundhouse", "knee" }) do
  local a = ATTACKS[name]
  local from = (name == "sweep") and 5 or 0
  a.windup = anim_id(from, a.pose, 0.45)
  a.recov = anim_id(from, a.pose, 0.6)
  a.over = anim_id(from, a.pose, 1.12)
end

local function stance_pose(ci, pi)
  local base = POSES[pi]
  if pi <= 2 and STANCE ~= nil and STANCE[ci] ~= nil then
    local merged = {}
    for k, v in pairs(base) do merged[k] = v end
    for k, v in pairs(STANCE[ci]) do merged[k] = v end
    return merged
  end
  return base
end

local base_render_pose = render_pose
function render_pose(ci, pi)
  local an = ANIM_POSE[pi]
  if an ~= nil then
    local A = stance_pose(ci, an.a)
    local B = stance_pose(ci, an.b)
    POSES[pi] = lerp_pose(A, B, an.t)
    local c = base_render_pose(ci, pi)
    POSES[pi] = nil
    return c
  end
  return base_render_pose(ci, pi)
end

function ENCODE_POSE(c)
  local words = {}
  local n = 0
  for ty = 0, 7 do
    for tx = 0, 7 do
      for row = 0, 7 do
        local p0, p1, p2, p3 = 0, 0, 0, 0
        local base = (ty * 8 + row) * 64 + tx * 8
        for col = 0, 7 do
          local v = c[base + col]
          if v ~= 0 then
            local bit = 1 << (7 - col)
            if v & 1 ~= 0 then p0 = p0 | bit end
            if v & 2 ~= 0 then p1 = p1 | bit end
            if v & 4 ~= 0 then p2 = p2 | bit end
            if v & 8 ~= 0 then p3 = p3 | bit end
          end
        end
        words[n + row] = p0 | (p1 << 8)
        words[n + 8 + row] = p2 | (p3 << 8)
      end
      n = n + 16
    end
  end
  return words
end
POSE_CACHE = {}
function pose_words(ci, pi)
  local key = ci * 64 + pi
  local w = POSE_CACHE[key]
  if w == nil then
    w = ENCODE_POSE(render_pose(ci, pi))
    POSE_CACHE[key] = w
  end
  return w
end
VRAM_POSE = { -1, -1 }
function set_fighter_vram(slot, ci, pi)
  local key = ci * 64 + pi
  if VRAM_POSE[slot] == key then return end
  VRAM_POSE[slot] = key
  local w = pose_words(ci, pi)
  local n = 0
  for ty = 0, 7 do
    for tx = 0, 7 do
      local addr = OBJ_BASE + (SLOT_TILE[slot] + ty * 16 + tx) * 16
      for i = 0, 15 do vram[addr + i] = w[n + i] end
      n = n + 16
    end
  end
end
function prerender(ci)
  for p = 0, 17 do pose_words(ci, p) end
end

local base_update_fighter = update_fighter
function update_fighter(f, opp, allow_input)
  local grounded = f.state == "idle" or f.state == "walk"
  if allow_input and grounded and not f.inp.down then
    local fwd = (f.face == 1) and f.inp.right or f.inp.left
    local back = (f.face == 1) and f.inp.left or f.inp.right
    local name = nil
    if f.inp.punch and fwd then name = "hook"
    elseif f.inp.kick and fwd then name = "roundhouse"
    elseif f.inp.kick and back then name = "knee" end
    if name ~= nil then
      local a = ATTACKS[name]
      f.state = "attack"; f.atk = a; f.timer = 1; f.hitdone = 0; f.pose = a.windup; f.combo = 1; f.vx = 0
      f.inp.punch = false; f.inp.kick = false
      sfx(SND_WHIFF, 7, "C5")
    end
  end
  base_update_fighter(f, opp, allow_input)
  if f.state == "attack" and f.atk ~= nil and f.atk.windup ~= nil then
    local a = f.atk
    if f.timer <= a.startup then f.pose = a.windup
    elseif f.timer <= a.startup + 2 then f.pose = a.over
    elseif f.timer <= a.startup + a.active then f.pose = a.pose
    else f.pose = a.recov end
  end
end
