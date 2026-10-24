-- terrier.lua: Arlo is a terrier. Runs after faces.lua.
-- The floppy puppy ear from art.lua is erased and replaced with two pricked, tan-lined terrier ears, the crown gets
-- wiry tufts, the brows are bushy tan points and a scruffy tan beard hangs under the muzzle.
local S, OX, OY = 1.8, 3.2, 7.2
local function TX(x) return x * S + OX end
local function TY(y) return y * S + OY end
local function put(c, x, y, v)
  x = floor(x); y = floor(y)
  if x >= 0 and x < 64 and y >= 0 and y < 64 then c[y * 64 + x] = v end
end
local function get(c, x, y)
  x = floor(x); y = floor(y)
  if x < 0 or x > 63 or y < 0 or y > 63 then return 0 end
  return c[y * 64 + x]
end
local function lerp_pt(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t } end
local function stance_pose(ci, pi)
  local base = POSES[pi]
  if base == nil then return nil end
  if pi <= 2 and STANCE ~= nil and STANCE[ci] ~= nil then
    local m = {}
    for k, v in pairs(base) do m[k] = v end
    for k, v in pairs(STANCE[ci]) do m[k] = v end
    return m
  end
  return base
end
local function head_center(ci, pi)
  local ch = CHARS[ci]
  local an = ANIM_POSE[pi]
  local neck, ho, hc
  if an ~= nil then
    local A, B = stance_pose(ci, an.a), stance_pose(ci, an.b)
    if A == nil or B == nil then return nil end
    neck = lerp_pt(A.neck, B.neck, an.t); ho = { 0, 0 }
  else
    local p = stance_pose(ci, pi)
    if p == nil then return nil end
    neck = p.neck; ho = p.headoff or { 0, 0 }; hc = p.headc
  end
  if hc == nil then hc = { neck[1] + ho[1], neck[2] - ch.head[2] + 1 + ho[2] } end
  return TX(hc[1]), TY(hc[2])
end
local function sgn(px, py, ax, ay, bx, by) return (px - bx) * (ay - by) - (ax - bx) * (py - by) end
local function in_tri(px, py, x0, y0, x1, y1, x2, y2)
  local d1, d2, d3 = sgn(px, py, x0, y0, x1, y1), sgn(px, py, x1, y1, x2, y2), sgn(px, py, x2, y2, x0, y0)
  local neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
  local pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
  return not (neg and pos)
end
local function tri(c, x0, y0, x1, y1, x2, y2, fill)
  for y = floor(min(y0, y1, y2)), floor(max(y0, y1, y2)) + 1 do
    for x = floor(min(x0, x1, x2)), floor(max(x0, x1, x2)) + 1 do
      if in_tri(x + 0.5, y + 0.5, x0, y0, x1, y1, x2, y2) then
        local edge = not (in_tri(x - 0.5, y + 0.5, x0, y0, x1, y1, x2, y2) and in_tri(x + 1.5, y + 0.5, x0, y0, x1, y1, x2, y2)
                      and in_tri(x + 0.5, y - 0.5, x0, y0, x1, y1, x2, y2) and in_tri(x + 0.5, y + 1.5, x0, y0, x1, y1, x2, y2))
        put(c, x, y, edge and 1 or fill)
      end
    end
  end
end

local base_render_pose = render_pose
function render_pose(ci, pi)
  local c = base_render_pose(ci, pi)
  if CHARS[ci].kind ~= "puppy" then return c end
  local cx, cy = head_center(ci, pi)
  if cx == nil then return c end
  local RX, RY = 6.5 * S, 6.0 * S
  local function in_head(x, y) local ex, ey = (x + 0.5 - cx) / RX, (y + 0.5 - cy) / RY return ex * ex + ey * ey <= 1 end
  -- erase the floppy ear (art.lua: ellipse at cx-9, cy+2, 4.0 x 7.6) where it hangs outside the head
  for y = floor(cy - 7), floor(cy + 11) do
    for x = floor(cx - 14), floor(cx - 4) do
      local ex, ey = (x + 0.5 - (cx - 9)) / 4.6, (y + 0.5 - (cy + 2)) / 8.2
      if ex * ex + ey * ey <= 1 and not in_head(x, y) then put(c, x, y, 0) end
    end
  end
  for y = floor(cy - 8), floor(cy + 12) do
    for x = floor(cx - 14), floor(cx - 3) do
      if in_head(x, y) and not (in_head(x - 1, y) and in_head(x + 1, y) and in_head(x, y - 1) and in_head(x, y + 1)) then put(c, x, y, 1) end
    end
  end
  -- pricked ears with tan lining
  tri(c, cx - 10, cy - 4, cx - 9, cy - 19, cx - 2, cy - 9, 3)
  tri(c, cx + 2, cy - 9, cx + 7, cy - 19, cx + 10, cy - 4, 3)
  tri(c, cx - 8, cy - 7, cx - 8, cy - 15, cx - 4, cy - 10, 12)
  tri(c, cx + 4, cy - 10, cx + 6, cy - 15, cx + 8, cy - 7, 12)
  for x = floor(cx - 8), floor(cx + 8) do   -- wiry tufts along the crown
    if (x + 1) % 4 == 0 then
      local top = cy - RY
      put(c, x, top - 1, 1); put(c, x, top - 2, 1); put(c, x + 1, top - 1, 3); put(c, x, top, 3)
    end
  end
  -- bushy tan brows
  local ex, ey = floor(cx) - 1, floor(cy) - 4
  for _, ox in ipairs({ 0, 8 }) do
    for i = 0, 3 do put(c, ex + ox + i, ey - 2, 12) end
    put(c, ex + ox + 1, ey - 3, 12); put(c, ex + ox + 2, ey - 3, 12)
    for i = -1, 4 do if get(c, ex + ox + i, ey - 4) ~= 1 then put(c, ex + ox + i, ey - 4, 1) end end
  end
  -- scruffy beard under the muzzle
  for i = 0, 5 do
    local bx = cx + 3 + i * 2
    local h = (i % 2 == 0) and 3 or 2
    for k = 0, h do
      local y = cy + 8 + k
      local v = (k == h) and 1 or 12
      if get(c, bx, y) ~= 9 and get(c, bx, y) ~= 10 then put(c, bx, y, v) end
    end
  end
  return c
end
