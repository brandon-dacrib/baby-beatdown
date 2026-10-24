-- smooth.lua: smoother strikes and planted feet. Runs last.
--  * every strike now has 7 frames: two wind-ups, an over-extension, the hit frame, three recovery frames
--    (all interpolated from the stance and the strike pose; strikes.lua's render_pose handles ANIM_POSE ids)
--  * the body lunges 2px forward on the active frames
--  * idle breathing is a real pose (a slight knee/hip dip) instead of lifting the whole sprite, so feet stay on the ground
-- Pose caches are re-keyed to ci*256+pi because ids now go past 64.
local next_id = 200
local function anim_id(a, b, t)
  local id = next_id
  next_id = next_id + 1
  ANIM_POSE[id] = { a = a, b = b, t = t }
  return id
end
for _, name in ipairs({ "jab", "cross", "upper", "kick", "highkick", "sweep", "hook", "roundhouse", "knee" }) do
  local a = ATTACKS[name]
  local from = (name == "sweep") and 5 or 0
  a.w1 = anim_id(from, a.pose, 0.28)
  a.w2 = anim_id(from, a.pose, 0.68)
  a.r1 = a.w2
  a.r2 = anim_id(from, a.pose, 0.42)
  a.r3 = anim_id(from, a.pose, 0.16)
end
BREATH_POSE = anim_id(0, 5, 0.12)

POSE_CACHE = {}
function pose_words(ci, pi)
  local key = ci * 256 + pi
  local w = POSE_CACHE[key]
  if w == nil then
    w = ENCODE_POSE(render_pose(ci, pi))
    POSE_CACHE[key] = w
  end
  return w
end
VRAM_POSE = { -1, -1 }
function set_fighter_vram(slot, ci, pi)
  local key = ci * 256 + pi
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
  pose_words(ci, BREATH_POSE)
end

local function in_active(f)
  local a = f.atk
  if f.state ~= "attack" or a == nil or a.air == true or a.shoot == true then return false end
  return f.timer > a.startup and f.timer <= a.startup + a.active
end

local base_update_fighter = update_fighter
function update_fighter(f, opp, allow_input)
  base_update_fighter(f, opp, allow_input)
  if f.state == "attack" and f.atk ~= nil and f.atk.w1 ~= nil then
    local a = f.atk
    local s, e, r = a.startup, a.startup + a.active, a.recover
    local half = s // 2
    if half < 1 then half = 1 end
    if f.timer <= half then f.pose = a.w1
    elseif f.timer <= s then f.pose = a.w2
    elseif f.timer <= s + 1 then f.pose = a.over
    elseif f.timer <= e then f.pose = a.pose
    else
      local k = f.timer - e
      if k * 3 <= r then f.pose = a.r1
      elseif k * 3 <= r * 2 then f.pose = a.r2
      else f.pose = a.r3 end
    end
  elseif f.state == "idle" and f.pose == POSE_IDLE and (f.anim // 26) % 2 == 1 then
    f.pose = BREATH_POSE
  end
end

local base_draw_sprites = draw_sprites
function draw_sprites()
  base_draw_sprites()
  if ROUND.state == "select" then return end
  for i, f in ipairs({ P1, P2 }) do
    if f ~= nil then
      local o = obj[i - 1]
      if f.state == "idle" then o.y = floor(f.y) end
      if in_active(f) then o.x = o.x + f.face * 2 end
    end
  end
end
