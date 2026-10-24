-- paint.lua: painterly depth (floor shading toward the camera, water shimmer) and a title logo that recolours
-- to contrast with whatever stage is behind it. Runs last.
-- Font palette (BG pal 1, cgram 16..31). The importer numbers colours by first appearance in the sheet:
--   index 1 = outline, 2 = letter top (yellow), 6 = letter bottom (orange), 4 = white cap/highlight,
--   3 = empty-bar dark red, 7 = empty-bar red, 5 = super-meter light blue, 8 = super-meter dark blue.
local function lum(c) return c[1] * 0.3 + c[2] * 0.59 + c[3] * 0.11 end
local function font_colors(o, a, b, h)
  cgram[17] = rgb(o[1], o[2], o[3]); cgram[18] = rgb(a[1], a[2], a[3]); cgram[22] = rgb(b[1], b[2], b[3]); cgram[20] = rgb(h[1], h[2], h[3])
end
local DEFAULT_FONT = { {16,16,24}, {255,224,64}, {255,144,32}, {255,255,255} }

local base_draw_logo = draw_logo
function draw_logo(row, col)
  base_draw_logo(row, col)
  local st = STAGES[CURRENT_STAGE]
  local t = AMB_T or 0
  local pulse = (sin(t * 2) + 1) * 0.5
  if st ~= nil and lum(st.sky[1]) > 150 then
    font_colors({ 250, 240, 230 }, { 200 + floor(pulse * 40), 30, 50 }, { 120, 16, 40 }, { 255, 170, 170 })
  elseif st ~= nil and lum(st.sky[1]) > 70 then
    font_colors({ 20, 10, 20 }, { 255, 220 + floor(pulse * 30), 60 }, { 240, 120, 30 }, { 255, 255, 240 })
  else
    font_colors({ 10, 10, 30 }, { 230, 240 + floor(pulse * 15), 255 }, { 120, 170, 240 }, { 255, 255, 255 })
  end
end

local WATER = { [1] = { 112, 159 }, [5] = { 176, 223 } }

local base_stage_sky = stage_sky
function stage_sky()
  base_stage_sky()
  local st = STAGES[CURRENT_STAGE]
  if st == nil then return end
  local t = AMB_T or 0
  local p5, p6, p7 = st.pal[5], st.pal[6], st.pal[7]
  local w = WATER[CURRENT_STAGE]
  hdma(160, 223, function(y)
    local k = 1.0 - (y - 160) / 64 * 0.38
    cgram[5] = rgb(floor(p5[1] * k), floor(p5[2] * k), floor(p5[3] * k))
    cgram[6] = rgb(floor(p6[1] * k), floor(p6[2] * k), floor(p6[3] * k))
    cgram[7] = rgb(floor(p7[1] * k), floor(p7[2] * k), floor(p7[3] * k))
    if w ~= nil and y >= w[1] and y <= w[2] then bg[2].scroll.x = sin(t * 2.5 + y / 5) * 1.5 end
  end)
  if w ~= nil and w[1] < 160 then
    hdma(w[1], min(159, w[2]), function(y)
      bg[2].scroll.x = sin(t * 2.5 + y / 5) * 1.5
    end)
  end
end

local base_frame = frame
function frame(t, f)
  if ROUND.state ~= "title" then font_colors(DEFAULT_FONT[1], DEFAULT_FONT[2], DEFAULT_FONT[3], DEFAULT_FONT[4]) end
  base_frame(t, f)
end
