-- art.lua: procedural baby-fighter renderer. Each pose is drawn into a 64x64 canvas at match start,
-- encoded to SNES 4bpp words and streamed into the sprite window when a fighter changes pose.
-- Depth: far-side limbs are drawn a tone darker, big rounded parts (head, torso) get a specular highlight,
-- and every part has a light band toward the top-left and a shade band toward the bottom-right.
-- palette indices: 1 outline, 2 fur dark, 3 fur mid, 4 fur light, 5 diaper, 6 diaper shade,
-- 7 accent dark, 8 accent light, 9 eye white, 10 pupil, 11 pink, 12 belly light, 13 nose, 14 highlight, 15 misc
CHARS = {
  { name = "BRANDON", kind = "human", head = { 6.8, 6.3 }, torso = 5.0, belly = true, patch = false,
    pal = { {48,28,20}, {150,100,60}, {198,142,96}, {226,176,128}, {248,248,255}, {194,198,216}, {104,52,28}, {158,92,46},
            {255,255,255}, {86,48,22}, {220,130,110}, {210,150,100}, {120,60,40}, {255,255,255}, {255,220,100} } },
  { name = "ARLO", kind = "puppy", head = { 6.5, 6.0 }, torso = 5.4, belly = true, patch = true,
    pal = { {42,26,30}, {168,112,58}, {220,160,96}, {244,200,136}, {248,248,255}, {194,198,216}, {106,58,34}, {154,90,48},
            {255,255,255}, {26,16,32}, {240,138,160}, {251,232,192}, {26,16,32}, {255,255,255}, {255,224,102} } },
  { name = "DAWN", kind = "kitten", head = { 6.5, 6.0 }, torso = 4.4, belly = false, patch = true,
    pal = { {30,30,48}, {106,106,138}, {160,160,192}, {208,208,232}, {248,248,255}, {194,198,216}, {80,80,112}, {240,160,192},
            {255,255,255}, {26,16,32}, {240,138,160}, {240,240,255}, {240,128,160}, {255,255,255}, {255,224,102} } },
  { name = "CHRIS", kind = "piglet", head = { 6.8, 6.0 }, torso = 6.0, belly = true, patch = false,
    pal = { {58,26,46}, {216,112,144}, {248,160,184}, {255,200,216}, {248,248,255}, {194,198,216}, {192,88,120}, {255,184,204},
            {255,255,255}, {26,16,32}, {240,138,160}, {255,216,228}, {160,64,96}, {255,255,255}, {255,224,102} } },
  { name = "ISAAC", kind = "duck", head = { 6.5, 6.0 }, torso = 5.2, belly = true, patch = false,
    pal = { {58,42,16}, {208,160,32}, {248,216,64}, {255,240,144}, {248,248,255}, {194,198,216}, {240,128,32}, {255,176,80},
            {255,255,255}, {26,16,32}, {240,138,160}, {255,248,192}, {192,80,16}, {255,255,255}, {255,224,102} } },
  { name = "TEDDY", kind = "bear", head = { 7.0, 6.2 }, torso = 6.0, belly = true, patch = true,
    pal = { {42,24,16}, {122,74,40}, {168,112,64}, {208,152,96}, {248,248,255}, {194,198,216}, {90,48,24}, {200,144,96},
            {255,255,255}, {26,16,32}, {240,138,160}, {232,200,152}, {26,16,32}, {255,255,255}, {255,224,102} } },
  { name = "PIP", kind = "bunny", head = { 6.5, 5.2 }, torso = 4.6, belly = false, patch = true,
    pal = { {42,42,58}, {184,184,200}, {236,236,244}, {255,255,255}, {240,240,255}, {184,192,216}, {192,192,208}, {255,176,200},
            {255,255,255}, {26,16,32}, {240,138,160}, {255,255,255}, {240,128,160}, {255,255,255}, {255,224,102} } },
  { name = "BLUE", kind = "bug", head = { 6.0, 5.5 }, torso = 5.4, belly = false, patch = false, limb = { 7, 7, 8 },
    pal = { {18,14,34}, {30,60,170}, {60,110,230}, {130,180,255}, {248,248,255}, {194,198,216}, {44,44,86}, {92,92,150},
            {255,255,255}, {26,16,32}, {240,138,160}, {224,240,255}, {0,0,0}, {255,255,255}, {255,224,102} } },
}
for i = 1, 8 do CHAR_NAME[i] = CHARS[i].name; CHAR_PAL[i] = CHARS[i].pal end

POSES = {
  [0]  = { neck = {14,13}, hip = {14,22}, barm = {{9,18},{11,15}},  farm = {{19,18},{21,15}}, bleg = {{10,27},{9,31}},  fleg = {{18,27},{19,31}} },
  [1]  = { neck = {14,13}, hip = {14,22}, barm = {{9,18},{11,15}},  farm = {{19,18},{21,15}}, bleg = {{8,27},{6,31}},   fleg = {{20,27},{22,31}} },
  [2]  = { neck = {14,13}, hip = {14,22}, barm = {{9,18},{11,15}},  farm = {{19,18},{21,15}}, bleg = {{12,27},{13,31}}, fleg = {{16,27},{15,31}} },
  [3]  = { neck = {16,13}, hip = {13,22}, barm = {{11,18},{13,15}}, farm = {{23,15},{29,15}}, bleg = {{9,27},{8,31}},   fleg = {{19,27},{20,31}} },
  [4]  = { neck = {12,13}, hip = {13,21}, barm = {{7,17},{9,14}},   farm = {{17,17},{19,14}}, bleg = {{9,27},{8,31}},   fleg = {{23,20},{29,18}} },
  [5]  = { neck = {14,19}, hip = {14,26}, barm = {{9,23},{11,21}},  farm = {{19,23},{21,21}}, bleg = {{8,29},{6,31}},   fleg = {{20,29},{22,31}} },
  [6]  = { neck = {14,11}, hip = {14,20}, barm = {{8,10},{7,6}},    farm = {{20,10},{21,6}},  bleg = {{11,25},{9,28}},  fleg = {{17,25},{20,28}} },
  [7]  = { neck = {11,14}, hip = {14,22}, barm = {{6,15},{3,12}},   farm = {{8,19},{5,17}},   bleg = {{10,27},{8,31}},  fleg = {{18,27},{20,31}}, headoff = {-2,0}, hurt = true },
  [8]  = { neck = {14,13}, hip = {14,22}, barm = {{18,19},{19,13}}, farm = {{21,20},{21,14}}, bleg = {{10,27},{9,31}},  fleg = {{18,27},{19,31}} },
  [9]  = { neck = {10,27}, hip = {19,26}, barm = {{6,22},{3,21}},   farm = {{13,22},{12,19}}, bleg = {{25,29},{30,30}}, fleg = {{24,26},{29,27}}, headc = {6.5,25}, hurt = true, lying = true },
  [10] = { neck = {14,12}, hip = {14,21}, barm = {{8,10},{7,5}},    farm = {{20,10},{21,5}},  bleg = {{8,27},{6,31}},   fleg = {{20,27},{22,31}} },
  [11] = { neck = {12,19}, hip = {12,26}, barm = {{7,23},{9,21}},   farm = {{17,22},{19,20}}, bleg = {{8,29},{6,31}},   fleg = {{20,27},{29,27}} },
}

local S, OX, OY = 1.8, 3.2, 7.2
local function TX(x) return x * S + OX end
local function TY(y) return y * S + OY end
local function TR(r) return r * S end

local function newmask() return { b = {}, x0 = 64, y0 = 64, x1 = -1, y1 = -1 } end
local function mset(m, x, y)
  if x < 0 or x > 63 or y < 0 or y > 63 then return end
  m.b[y * 64 + x] = true
  if x < m.x0 then m.x0 = x end
  if x > m.x1 then m.x1 = x end
  if y < m.y0 then m.y0 = y end
  if y > m.y1 then m.y1 = y end
end
local function inm(m, x, y)
  if x < 0 or x > 63 or y < 0 or y > 63 then return false end
  return m.b[y * 64 + x] == true
end
local function capsule(m, x0, y0, x1, y1, r)
  local dx, dy = x1 - x0, y1 - y0
  local L2 = dx * dx + dy * dy
  local ax, bx = floor(min(x0, x1) - r), floor(max(x0, x1) + r) + 1
  local ay, by = floor(min(y0, y1) - r), floor(max(y0, y1) + r) + 1
  for y = max(0, ay), min(63, by) do
    for x = max(0, ax), min(63, bx) do
      local px, py = x + 0.5, y + 0.5
      local t = 0
      if L2 > 0 then
        t = ((px - x0) * dx + (py - y0) * dy) / L2
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
      end
      local cx, cy = x0 + dx * t, y0 + dy * t
      local ex, ey = px - cx, py - cy
      if ex * ex + ey * ey <= r * r then mset(m, x, y) end
    end
  end
  return m
end
local function ellipse(m, cx, cy, rx, ry)
  for y = max(0, floor(cy - ry)), min(63, floor(cy + ry) + 1) do
    for x = max(0, floor(cx - rx)), min(63, floor(cx + rx) + 1) do
      local ex, ey = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
      if ex * ex + ey * ey <= 1 then mset(m, x, y) end
    end
  end
  return m
end
local function sgn(px, py, ax, ay, bx, by) return (px - bx) * (ay - by) - (ax - bx) * (py - by) end
local function tri(m, x0, y0, x1, y1, x2, y2)
  for y = max(0, floor(min(y0, y1, y2))), min(63, floor(max(y0, y1, y2)) + 1) do
    for x = max(0, floor(min(x0, x1, x2))), min(63, floor(max(x0, x1, x2)) + 1) do
      local px, py = x + 0.5, y + 0.5
      local d1, d2, d3 = sgn(px, py, x0, y0, x1, y1), sgn(px, py, x1, y1, x2, y2), sgn(px, py, x2, y2, x0, y0)
      local neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
      local pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
      if not (neg and pos) then mset(m, x, y) end
    end
  end
  return m
end
local function union(a, b)
  local m = newmask()
  for k, _ in pairs(a.b) do mset(m, k % 64, k // 64) end
  for k, _ in pairs(b.b) do mset(m, k % 64, k // 64) end
  return m
end

local function paint(c, m, mid, dark, light, outline)
  if outline == nil then outline = 1 end
  local big = (m.x1 - m.x0 >= 16) and (m.y1 - m.y0 >= 14)
  for y = m.y0, m.y1 do
    for x = m.x0, m.x1 do
      if m.b[y * 64 + x] then
        local edge = not (inm(m, x - 1, y) and inm(m, x + 1, y) and inm(m, x, y - 1) and inm(m, x, y + 1))
        if edge and outline > 0 then
          c[y * 64 + x] = outline
        else
          local col = mid
          if not inm(m, x - 3, y - 2) or not inm(m, x - 2, y - 3) then col = light
          elseif not inm(m, x + 3, y + 2) or not inm(m, x + 2, y + 3) then col = dark
          elseif not inm(m, x + 5, y + 4) or not inm(m, x + 4, y + 5) then col = dark end
          if big and col == light and not (inm(m, x - 4, y - 3) and inm(m, x - 3, y - 4)) and inm(m, x - 2, y - 2) and y > m.y0 + 2 and x > m.x0 + 2 then
            if (x + y) % 2 == 0 then col = 14 end
          end
          c[y * 64 + x] = col
        end
      end
    end
  end
end

local function px(c, x, y, k)
  x = floor(x); y = floor(y)
  if x >= 0 and x < 64 and y >= 0 and y < 64 then c[y * 64 + x] = k end
end
local function rect(c, x0, y0, w, h, k)
  for y = y0, y0 + h - 1 do for x = x0, x0 + w - 1 do px(c, x, y, k) end end
end

local function limb_colors(ch, back)
  local col = ch.limb or { 3, 2, 4 }
  if back then return { col[2], col[2], col[1] } end
  return col
end
local function limb(c, ch, a, b, r, back)
  local col = limb_colors(ch, back)
  paint(c, capsule(newmask(), TX(a[1]), TY(a[2]), TX(b[1]), TY(b[2]), TR(r)), col[1], col[2], col[3], 1)
end
local function hand(c, ch, p, back)
  local col = limb_colors(ch, back)
  paint(c, ellipse(newmask(), TX(p[1]), TY(p[2]), TR(2.6), TR(2.4)), col[1], col[2], col[3], 1)
end
local function foot(c, ch, p, back)
  local col = limb_colors(ch, back)
  if ch.kind == "duck" then col = back and { 7, 7, 7 } or { 7, 7, 8 } end
  local rx = (ch.kind == "bunny") and 3.6 or 2.9
  paint(c, ellipse(newmask(), TX(p[1] + 0.5), TY(p[2] - 0.5), TR(rx), TR(1.9)), col[1], col[2], col[3], 1)
end

local function eyes(c, ex, ey, hurt, hcol)
  for _, ox in ipairs({ 0, 8 }) do
    if hurt then
      for i = 0, 3 do px(c, ex + ox + i, ey + 1 + i, 1); px(c, ex + ox + 3 - i, ey + 1 + i, 1) end
    else
      rect(c, ex + ox, ey, 4, 6, 9)
      rect(c, ex + ox + 1, ey + 2, 2, 3, 10)
      px(c, ex + ox + 2, ey + 2, 14)
      px(c, ex + ox, ey, hcol); px(c, ex + ox + 3, ey, hcol)
      px(c, ex + ox, ey + 5, hcol); px(c, ex + ox + 3, ey + 5, hcol)
      rect(c, ex + ox, ey - 1, 4, 1, 1)
    end
  end
end

function render_pose(ci, pi)
  local ch = CHARS[ci]
  local p = POSES[pi]
  local c = {}
  for i = 0, 4095 do c[i] = 0 end
  local kind = ch.kind
  local neck, hip = p.neck, p.hip
  local sh = { neck[1], neck[2] + 2 }
  local rx, ry = ch.head[1], ch.head[2]
  local ho = p.headoff or { 0, 0 }
  local hc = p.headc or { neck[1] + ho[1], neck[2] - ry + 1 + ho[2] }
  local hurt = p.hurt or false
  local skin = { 3, 2, 4 }
  local tr = ch.torso
  local tx, ty = hip[1] - tr - 1, hip[2] - 1
  if kind == "puppy" then limb(c, ch, { tx + 1, ty }, { tx - 2, ty - 5 }, 1.8, true) end
  if kind == "kitten" then
    paint(c, capsule(newmask(), TX(tx + 1), TY(ty), TX(tx - 4), TY(ty - 5), TR(1.6)), 2, 2, 3, 1)
    paint(c, capsule(newmask(), TX(tx - 4), TY(ty - 5), TX(tx - 2), TY(ty - 10), TR(1.6)), 2, 2, 3, 1)
    paint(c, ellipse(newmask(), TX(tx - 2), TY(ty - 10), TR(1.7), TR(1.7)), 7, 7, 8, 1)
  end
  if kind == "piglet" then
    paint(c, capsule(newmask(), TX(tx + 1), TY(ty), TX(tx - 1), TY(ty - 2), TR(0.9)), 2, 2, 3, 1)
    paint(c, capsule(newmask(), TX(tx - 1), TY(ty - 2), TX(tx - 3), TY(ty - 1), TR(0.9)), 2, 2, 3, 1)
    paint(c, capsule(newmask(), TX(tx - 3), TY(ty - 1), TX(tx - 2), TY(ty - 4), TR(0.9)), 2, 2, 3, 1)
  end
  if kind == "duck" then paint(c, tri(newmask(), TX(tx + 1), TY(ty + 1), TX(tx - 5), TY(ty - 5), TX(tx - 1), TY(ty - 6)), 2, 2, 3, 1) end
  if kind == "bear" then paint(c, ellipse(newmask(), TX(tx), TY(ty), TR(2.0), TR(1.8)), 2, 2, 3, 1) end
  if kind == "bunny" then paint(c, ellipse(newmask(), TX(tx), TY(ty), TR(2.4), TR(2.2)), 12, 6, 12, 1) end
  if kind == "bug" then
    paint(c, ellipse(newmask(), TX(neck[1] - 4), TY((neck[2] + hip[2]) / 2 - 1), TR(4.0), TR(5.5)), 12, 12, 14, 1)
  end
  local e, hd = p.barm[1], p.barm[2]
  limb(c, ch, { sh[1] - 2, sh[2] }, e, 2.3, true); limb(c, ch, e, hd, 2.0, true); hand(c, ch, hd, true)
  local k, ft = p.bleg[1], p.bleg[2]
  limb(c, ch, { hip[1] - 2, hip[2] + 1 }, k, 2.6, true); limb(c, ch, k, ft, 2.3, true); foot(c, ch, ft, true)
  local tm = capsule(newmask(), TX(neck[1]), TY(neck[2]), TX(hip[1]), TY(hip[2]), TR(tr))
  if ch.belly then tm = union(tm, ellipse(newmask(), TX((neck[1] + hip[1]) / 2 + 1), TY((neck[2] + hip[2]) / 2 + 2), TR(tr + 1.0), TR(tr - 0.5))) end
  paint(c, tm, 3, 2, 4, 1)
  if ch.patch then
    local pm = ellipse(newmask(), TX((neck[1] + hip[1]) / 2 + 2), TY((neck[2] + hip[2]) / 2 + 1), TR(tr - 1.5), TR(tr - 1.0))
    for key, _ in pairs(pm.b) do
      if tm.b[key] and c[key] ~= 1 and c[key] ~= 14 then c[key] = 12 end
    end
  end
  if kind == "bug" then
    local spots = { {-2,-3}, {2,-1}, {-1,2}, {3,3}, {-3,1} }
    for _, s in ipairs(spots) do
      local sm = ellipse(newmask(), TX((neck[1] + hip[1]) / 2 + s[1]), TY((neck[2] + hip[2]) / 2 + s[2]), 1.8, 1.8)
      for key, _ in pairs(sm.b) do if tm.b[key] and c[key] ~= 1 then c[key] = 1 end end
    end
  end
  local dm = newmask()
  if p.lying then
    for key, _ in pairs(tm.b) do
      local x = key % 64
      if x >= TX(hip[1] - 3) then mset(dm, x, key // 64) end
    end
    dm = union(dm, ellipse(newmask(), TX(hip[1] + 1), TY(hip[2]), TR(3.5), TR(tr + 1.5)))
  else
    for key, _ in pairs(tm.b) do
      local y = key // 64
      if y >= TY(hip[2] - 3) then mset(dm, key % 64, y) end
    end
    dm = union(dm, ellipse(newmask(), TX(hip[1]), TY(hip[2] + 1), TR(tr + 1.5), TR(3.5)))
  end
  paint(c, dm, 5, 6, 5, 1)
  px(c, TX(hip[1] + 1), TY(hip[2] + 1), 15); px(c, TX(hip[1] + 1) + 1, TY(hip[2] + 1), 15)
  local bx, by = floor(TX((neck[1] + hip[1]) / 2 + 1)), floor(TY((neck[2] + hip[2]) / 2))
  if c[by * 64 + bx] == 3 or c[by * 64 + bx] == 12 then c[by * 64 + bx] = 2; c[by * 64 + bx + 1] = 2 end
  k, ft = p.fleg[1], p.fleg[2]
  limb(c, ch, { hip[1] + 2, hip[2] + 1 }, k, 2.6, false); limb(c, ch, k, ft, 2.3, false); foot(c, ch, ft, false)
  e, hd = p.farm[1], p.farm[2]
  limb(c, ch, { sh[1] + 2, sh[2] }, e, 2.3, false); limb(c, ch, e, hd, 2.0, false); hand(c, ch, hd, false)
  local cx, cy = TX(hc[1]), TY(hc[2])
  local RX, RY = TR(rx), TR(ry)
  if kind == "kitten" then
    paint(c, tri(newmask(), cx - 9, cy - 5, cx - 7, cy - 17, cx - 1, cy - 9), 3, 2, 4, 1)
    paint(c, tri(newmask(), cx + 2, cy - 9, cx + 6, cy - 17, cx + 9, cy - 5), 3, 2, 4, 1)
    paint(c, tri(newmask(), cx - 7, cy - 7, cx - 6, cy - 13, cx - 3, cy - 9), 11, 11, 11, 0)
    paint(c, tri(newmask(), cx + 3, cy - 9, cx + 5, cy - 13, cx + 7, cy - 7), 11, 11, 11, 0)
  end
  if kind == "piglet" then
    paint(c, tri(newmask(), cx - 9, cy - 5, cx - 9, cy - 15, cx - 2, cy - 9), 3, 2, 4, 1)
    paint(c, tri(newmask(), cx + 2, cy - 9, cx + 7, cy - 15, cx + 9, cy - 5), 3, 2, 4, 1)
  end
  if kind == "bear" then
    paint(c, ellipse(newmask(), cx - 8, cy - 8, 4.6, 4.6), 3, 2, 4, 1); paint(c, ellipse(newmask(), cx + 8, cy - 8, 4.6, 4.6), 3, 2, 4, 1)
    paint(c, ellipse(newmask(), cx - 8, cy - 8, 2.2, 2.2), 8, 8, 8, 0); paint(c, ellipse(newmask(), cx + 8, cy - 8, 2.2, 2.2), 8, 8, 8, 0)
  end
  if kind == "bunny" then
    paint(c, capsule(newmask(), cx - 4, cy - 5, cx - 7, cy - 20, 3.4), 3, 2, 4, 1)
    paint(c, capsule(newmask(), cx + 4, cy - 5, cx + 4, cy - 20, 3.4), 3, 2, 4, 1)
    paint(c, capsule(newmask(), cx - 4.5, cy - 8, cx - 6.5, cy - 17, 1.4), 11, 11, 11, 0)
    paint(c, capsule(newmask(), cx + 4, cy - 8, cx + 4, cy - 17, 1.4), 11, 11, 11, 0)
  end
  if kind == "bug" then
    for _, side in ipairs({ -1, 1 }) do
      local ax = cx + side * 4
      local bxx = cx + side * 8
      for i = 0, 8 do px(c, ax + (bxx - ax) * i / 8, cy - RY - 1 - i, 1) end
      paint(c, ellipse(newmask(), bxx, cy - RY - 10, 2.2, 2.2), 8, 7, 8, 1)
    end
  end
  local hcol = (kind == "bug") and ch.limb or skin
  local hm = ellipse(newmask(), cx, cy, RX, RY)
  paint(c, hm, hcol[1], hcol[2], hcol[3], 1)
  if kind == "human" then
    for key, _ in pairs(hm.b) do
      local y = key // 64
      if y < cy - RY * 0.5 and c[key] ~= 1 then c[key] = 7 end
    end
    for _, cu in ipairs({ {-9,-6}, {-6,-10}, {-2,-12.5}, {2,-13}, {6,-11.5}, {9,-8}, {-4,-8}, {4,-9}, {0,-9.5} }) do
      paint(c, ellipse(newmask(), cx + cu[1], cy + cu[2], 3.0, 2.8), 7, 7, 8, 1)
    end
  end
  if kind == "kitten" then
    for _, cu in ipairs({ {-3,-6}, {0,-7}, {3,-6} }) do px(c, cx + cu[1], cy + cu[2], 12) end
  end
  if kind == "duck" then
    paint(c, capsule(newmask(), cx - 1, cy - RY + 1, cx - 3, cy - RY - 5, 1.3), 3, 2, 4, 1)
    paint(c, capsule(newmask(), cx + 1, cy - RY + 1, cx + 2, cy - RY - 5, 1.3), 3, 2, 4, 1)
  end
  local ex, ey = floor(cx) - 1, floor(cy) - 4
  if kind == "puppy" then
    paint(c, ellipse(newmask(), cx + 8, cy + 4, 5.8, 4.0), 12, 12, 12, 1)
    paint(c, ellipse(newmask(), cx + 11, cy + 2.5, 2.3, 1.8), 13, 13, 13, 0)
    if hurt then rect(c, cx + 8, cy + 6, 4, 2, 11) end
  elseif kind == "piglet" then
    paint(c, ellipse(newmask(), cx + 9, cy + 4, 5.4, 3.6), 8, 7, 8, 1)
    px(c, cx + 8, cy + 4, 13); px(c, cx + 8, cy + 5, 13); px(c, cx + 11, cy + 4, 13); px(c, cx + 11, cy + 5, 13)
    if hurt then rect(c, cx + 4, cy + 9, 4, 2, 1) end
  elseif kind == "duck" then
    paint(c, ellipse(newmask(), cx + 11, cy + 4, 7.2, 3.2), 7, 7, 8, 1)
    px(c, cx + 6, cy + 4, 1); px(c, cx + 7, cy + 4, 1); px(c, cx + 8, cy + 4, 1); px(c, cx + 9, cy + 4, 1)
    if hurt then rect(c, cx + 7, cy + 5, 6, 1, 1) end
  elseif kind == "bear" then
    paint(c, ellipse(newmask(), cx + 7, cy + 4, 5.4, 4.0), 12, 12, 12, 1)
    paint(c, ellipse(newmask(), cx + 9, cy + 2.5, 2.3, 1.8), 13, 13, 13, 0)
    if hurt then rect(c, cx + 7, cy + 6, 4, 2, 11) end
  elseif kind == "human" then
    if hurt then
      rect(c, cx + 2, cy + 6, 6, 3, 11); rect(c, cx + 2, cy + 6, 6, 1, 1)
    else
      rect(c, cx + 1, cy + 6, 9, 3, 1)
      rect(c, cx + 2, cy + 7, 7, 1, 9)
      px(c, cx + 1, cy + 6, 2); px(c, cx + 9, cy + 6, 2)
    end
    px(c, cx + 4, cy + 3, 2); px(c, cx + 5, cy + 3, 2)
  elseif kind == "kitten" then
    px(c, cx + 5, cy + 4, 11); px(c, cx + 6, cy + 4, 11); px(c, cx + 5, cy + 5, 11); px(c, cx + 6, cy + 5, 11)
    for i = 0, 2 do px(c, cx + 4 + i, cy + 6 + (i == 1 and 0 or 1), 1); px(c, cx + 8 - i, cy + 6 + (i == 1 and 0 or 1), 1) end
    for i = 0, 4 do px(c, cx + RX + i, cy + 2 + i // 2, 1); px(c, cx + RX + i, cy + 6 - i // 2, 1) end
    if hurt then rect(c, cx + 4, cy + 8, 4, 2, 11) end
  elseif kind == "bunny" then
    px(c, cx + 5, cy + 4, 11); px(c, cx + 6, cy + 4, 11)
    rect(c, cx + 4, cy + 6, 4, 3, 9); px(c, cx + 6, cy + 6, 1); px(c, cx + 6, cy + 7, 1); px(c, cx + 6, cy + 8, 1)
    rect(c, cx + 3, cy + 6, 1, 3, 1); rect(c, cx + 8, cy + 6, 1, 3, 1)
    if hurt then rect(c, cx + 4, cy + 9, 4, 2, 11) end
  elseif kind == "bug" then
    rect(c, cx + 3, cy + 5, 6, 1, 8)
    if hurt then rect(c, cx + 4, cy + 6, 4, 2, 11) end
  end
  eyes(c, ex, ey, hurt, hcol[1])
  if not hurt and kind ~= "bug" then rect(c, ex - 5, ey + 7, 3, 2, 11); rect(c, ex + 13, ey + 7, 3, 2, 11) end
  if kind == "puppy" then paint(c, ellipse(newmask(), cx - 9, cy + 2, 4.0, 7.6), 7, 7, 8, 1) end
  return c
end

local function encode(c)
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
    w = encode(render_pose(ci, pi))
    POSE_CACHE[key] = w
  end
  return w
end

VRAM_POSE = { -1, -1 }
SLOT_TILE = { 0, 8 }
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
  for p = 0, 11 do pose_words(ci, p) end
end
