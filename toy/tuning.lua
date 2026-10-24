-- tuning.lua: balance overrides and small behaviour patches (runs after fight.lua)
SUPER[1].dmg = 24   -- diaper dump
SUPER[2].dmg = 22   -- bottle bash
SUPER[3].dmg = 8    -- rattle rampage x3
SUPER[4].dmg = 20   -- binky blast
SUPER[5].dmg = 26   -- bubble burp (slow, big)
SUPER[6].dmg = 22   -- tantrum toss
SUPER[7].dmg = 22   -- teething chomp
SUPER[8].dmg = 18   -- spit-up spray (short range)

-- jump kick: once the active frames are over, fall in the jump pose instead of holding the kick
local base_update_fighter = update_fighter
function update_fighter(f, opp, allow_input)
  base_update_fighter(f, opp, allow_input)
  if f.state == "attack" and f.atk and f.atk.air and f.timer > f.atk.startup + f.atk.active then
    f.pose = POSE_JUMP
  end
end
