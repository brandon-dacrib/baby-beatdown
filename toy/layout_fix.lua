-- layout_fix.lua: keep the breakables off the fighters' foot scanlines (sliver budget), runs after combat.lua
function spawn_objects()
  local b = BREAK[CURRENT_STAGE] or BREAK[1]
  OBJECTS = {
    { x = 2, y = FLOOR_Y + 34, cell = b.cell, alive = true },
    { x = 238, y = FLOOR_Y + 34, cell = b.cell, alive = true },
  }
end
