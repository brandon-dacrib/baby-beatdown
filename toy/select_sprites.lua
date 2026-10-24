-- select_sprites.lua: on the character-select screen only the 32x32 portraits are shown
-- (size_sel 3 would crop the 64x64 fighter and shadow cells, so those sprites are hidden here)
local PORT_X = { 40, 88, 136, 184 }
local PORT_Y = { 40, 88 }
function draw_select_sprites()
  for i = 0, 31 do obj[i].on = false end
  for i = 1, 8 do
    draw_portrait(i, 3 + i, PORT_X[(i - 1) % 4 + 1], PORT_Y[(i - 1) // 4 + 1])
  end
  local p1 = obj[3 + SEL.cursor]
  p1.y = p1.y - ((ROUND.timer // 8) % 2)
  if SEL.cpu ~= 0 then
    local p2 = obj[3 + SEL.cpu]
    p2.y = p2.y - ((ROUND.timer // 8 + 1) % 2)
  end
end
