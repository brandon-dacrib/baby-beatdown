-- hud.lua: Street Fighter II style HUD (bold outlined font, bordered health bars, KO emblem, names under bars)
-- font palettes: BG pal 1 (cgram 16..) yellow/orange text; BG pal 2 (cgram 32..) red text for the KO emblem
local function font_palettes()
  cgram[33] = rgb(16, 16, 24); cgram[34] = rgb(255, 60, 40); cgram[35] = rgb(170, 20, 20); cgram[36] = rgb(255, 255, 255)
  cgram[37] = rgb(90, 16, 16); cgram[38] = rgb(140, 24, 24); cgram[39] = rgb(96, 192, 255); cgram[40] = rgb(32, 96, 192)
end

function text_pal(col, row, s, pal)
  local attr = (pal << 10) | 0x2000
  local base = HUD_MAP + row * 32 + col
  for i = 1, string.len(s) do
    local b = string.byte(s, i)
    local g = 0
    if b >= 65 and b <= 90 then g = b - 64
    elseif b >= 48 and b <= 57 then g = b - 48 + 27
    elseif b == 33 then g = 37 elseif b == 46 then g = 38 elseif b == 45 then g = 39
    elseif b == 58 then g = 40 elseif b == 62 then g = 41 elseif b == 60 then g = 42 end
    vram[base + i - 1] = g | attr
  end
end

function draw_hud()
  font_palettes()
  local h1 = (P1.hp + 7) // 8
  local h2 = (P2.hp + 7) // 8
  for i = 0, 11 do
    hud_tile(12 - i, 1, (i < h1) and 43 or 44)
    hud_tile(19 + i, 1, (i < h2) and 43 or 44)
  end
  hud_tile(0, 1, 48); hud_tile(31, 1, 48)
  text_pal(14, 1, " KO ", 2)
  text(1, 2, CHAR_NAME[P1.char] .. "   ")
  local n2 = CHAR_NAME[P2.char]
  text(31 - string.len(n2), 2, n2)
  hud_tile(11, 2, (P1.wins >= 1) and 47 or 0)
  hud_tile(12, 2, (P1.wins >= 2) and 47 or 0)
  hud_tile(19, 2, (P2.wins >= 2) and 47 or 0)
  hud_tile(20, 2, (P2.wins >= 1) and 47 or 0)
  local c = floor(ROUND.clock)
  text(15, 2, string.sub("0" .. c, -2, -1))
  local m1 = P1.meter // 16
  local m2 = P2.meter // 16
  for i = 0, 5 do
    hud_tile(12 - i, 3, (i < m1) and 45 or 46)
    hud_tile(19 + i, 3, (i < m2) and 45 or 46)
  end
  if P1.meter >= METER_MAX and (ROUND.timer // 8) % 2 == 0 then text(1, 3, "SUPER!") else text(1, 3, "      ") end
  if P2.meter >= METER_MAX and (ROUND.timer // 8) % 2 == 0 then text(25, 3, "SUPER!") else text(25, 3, "      ") end
end
