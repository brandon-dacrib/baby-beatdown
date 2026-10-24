-- flow.lua: title, character select, rounds, init and frame
ROUND = { state = "title", timer = 0, num = 1, clock = 99, msg = "", winner = nil }
P1, P2 = nil, nil
SEL = { cursor = 1, cpu = 0, timer = 0 }
TITLE = { pair = 0, t = 0 }

function rnd() return math.random() end

local function reset_round()
  P1.x, P1.y, P1.vx, P1.vy = 32, FLOOR_Y, 0, 0
  P2.x, P2.y, P2.vx, P2.vy = 160, FLOOR_Y, 0, 0
  P1.face, P2.face = 1, -1
  P1.hp, P2.hp = HP_MAX, HP_MAX
  P1.state, P2.state = "idle", "idle"
  P1.pose, P2.pose = POSE_IDLE, POSE_IDLE
  P1.crouch, P2.crouch = false, false
  P1.inp, P2.inp = {}, {}
  PROJ = {}; SPARKS = {}
  ROUND.clock = 99
  ROUND.state = "intro"; ROUND.timer = 0
  ROUND.callout_t = 0
  clear_hud()
end

local function start_match(c1, c2)
  obj.size_sel = 4
  P1 = new_fighter(1, c1, 32, 1, false)
  P2 = new_fighter(2, c2, 160, -1, true)
  load_fighter(1, c1, false)
  load_fighter(2, c2, c1 == c2)
  if restore_fx_palette ~= nil then restore_fx_palette() end
  if build_stage ~= nil then build_stage(c2) end
  ROUND.num = 1
  reset_round()
end

local function title_pair()
  local a = 1 + floor(rnd() * 8)
  local b = 1 + floor(rnd() * 7)
  if b >= a then b = b + 1 end
  P1 = new_fighter(1, a, 36, 1, false)
  P2 = new_fighter(2, b, 156, -1, false)
  load_fighter(1, a, false); load_fighter(2, b, false)
  TITLE.t = 0
end

local function go_title()
  ROUND.state = "title"; ROUND.timer = 0
  obj.size_sel = 4
  clear_hud()
  if restore_fx_palette ~= nil then restore_fx_palette() end
  title_pair()
  if build_stage ~= nil then build_stage(1 + floor(rnd() * 8)) end
  PROJ = {}; SPARKS = {}
end

local function go_select()
  ROUND.state = "select"; ROUND.timer = 0
  SEL.cursor = 1; SEL.cpu = 0; SEL.timer = 0
  clear_hud()
  P2 = nil
  P1 = new_fighter(1, 1, 8, 1, false)
  load_fighter(1, 1, false)
  obj.size_sel = 3
  if prepare_portraits ~= nil then prepare_portraits() end
end

function init()
  mode = 1
  obj.char_base = OBJ_BASE
  obj.size_sel = 4
  bg[1].char_base = HUD_CHAR; bg[1].map_base = HUD_MAP
  bg[2].char_base = STAGE_CHAR; bg[2].map_base = STAGE_MAP
  bg[1].scroll.y = -1; bg[2].scroll.y = -1
  screen.main.bg1 = true; screen.main.bg2 = true; screen.main.obj = true
  cgram[0] = rgb(220, 239, 255)
  upload_tiles(FX_TILES, FX_SUM, "fx")
  for i = 1, 15 do cgram[128 + 2 * 16 + i] = rgb(FX_PAL[i][1], FX_PAL[i][2], FX_PAL[i][3]) end
  go_title()
end

local function any_button()
  return pressed("start") or pressed("a") or pressed("b") or pressed("y")
end

local function update_title()
  ROUND.timer = ROUND.timer + 1
  TITLE.t = TITLE.t + 1
  if draw_logo ~= nil then draw_logo(3, 3) end
  text_center(7, "8 BABIES. 1 NAP TIME.")
  if ROUND.timer % 60 < 40 then text_center(10, "PUSH START") else clear_row(10) end
  text_center(25, "1 PLAYER VS CPU")
  P1.anim = P1.anim + 1; P2.anim = P2.anim + 1
  local beat = TITLE.t % 240
  P1.pose = POSE_IDLE; P2.pose = POSE_IDLE
  if beat >= 90 and beat < 104 then P1.pose = POSE_PUNCH end
  if beat >= 170 and beat < 186 then P2.pose = POSE_KICK end
  P1.state = "idle"; P2.state = "idle"
  if TITLE.t >= 480 then
    title_pair()
    if build_stage ~= nil then build_stage(1 + floor(rnd() * 8)) end
  end
  if any_button() then
    sfx(SND_SEL, 6, "C5")
    go_select()
  end
end

local PORT_X = { 40, 88, 136, 184 }
local PORT_Y = { 40, 88 }
local function portrait_pos(i) return PORT_X[(i - 1) % 4 + 1], PORT_Y[(i - 1) // 4 + 1] end

local function frame_box(i, tile)
  local x, y = portrait_pos(i)
  local c0, r0 = x // 8 - 1, y // 8 - 1
  for k = 0, 5 do
    hud_tile(c0 + k, r0, tile); hud_tile(c0 + k, r0 + 5, tile)
    hud_tile(c0, r0 + k, tile); hud_tile(c0 + 5, r0 + k, tile)
  end
end

local function update_select()
  ROUND.timer = ROUND.timer + 1
  local c = SEL.cursor
  if SEL.cpu == 0 then
    local moved = false
    if pressed("left") then if c % 4 == 1 then c = c + 3 else c = c - 1 end; moved = true end
    if pressed("right") then if c % 4 == 0 then c = c - 3 else c = c + 1 end; moved = true end
    if pressed("up") or pressed("down") then if c > 4 then c = c - 4 else c = c + 4 end; moved = true end
    if moved then
      SEL.cursor = c
      sfx(SND_SEL, 6, "E5")
      P1.char = c
      load_fighter(1, c, false)
      if prepare_portraits ~= nil then prepare_portraits() end
      clear_hud()
    end
    if any_button() then
      SEL.cpu = 1 + floor(rnd() * 8)
      SEL.timer = 0
      sfx(SND_SEL, 6, "G5")
      P2 = new_fighter(2, SEL.cpu, 184, -1, true)
      load_fighter(2, SEL.cpu, false)
      if prepare_portraits ~= nil then prepare_portraits() end
    end
  else
    SEL.timer = SEL.timer + 1
    if SEL.timer > 100 then start_match(SEL.cursor, SEL.cpu) return end
  end
  text_center(1, "CHOOSE YOUR BABY")
  for i = 1, 8 do frame_box(i, 0) end
  frame_box(c, ((ROUND.timer // 4) % 2 == 0) and 43 or 48)
  if SEL.cpu ~= 0 then frame_box(SEL.cpu, 44) end
  clear_row(18); clear_row(19)
  text_center(18, CHAR_NAME[c] .. "  " .. STYLE[c].name)
  text_center(19, "SUPER: " .. SUPER[c].name)
  if SEL.cpu ~= 0 then
    text_center(21, "VS  CPU " .. CHAR_NAME[SEL.cpu])
    text_center(22, "STAGE: " .. STAGES[SEL.cpu].name)
  end
  P1.x = 8; P1.y = 150; P1.face = 1; P1.state = "idle"; P1.anim = P1.anim + 1
  P1.pose = (SEL.cpu ~= 0 and (ROUND.timer // 20) % 2 == 0) and POSE_PUNCH or POSE_IDLE
  if P2 ~= nil then
    P2.x = 184; P2.y = 150; P2.face = -1; P2.state = "idle"; P2.anim = P2.anim + 1
    P2.pose = ((ROUND.timer // 20) % 2 == 1) and POSE_KICK or POSE_IDLE
  end
end

function draw_select_sprites()
  for i = 1, 8 do
    local x, y = portrait_pos(i)
    draw_portrait(i, 3 + i, x, y)
  end
  obj[0].pal = P1.char - 1
  if P2 ~= nil then obj[1].pal = P2.char - 1 end
end

local function fight_over(winner, msg)
  ROUND.state = "roundend"; ROUND.timer = 0; ROUND.msg = msg; ROUND.winner = winner
  if winner ~= nil then winner.wins = winner.wins + 1 end
end

local function update_fight()
  ROUND.timer = ROUND.timer + 1
  local live = ROUND.state == "fight"
  if live then
    read_p1(P1)
    cpu_input(P2, P1)
  else
    P1.inp = {}; P2.inp = {}
  end
  update_fighter(P1, P2, live)
  update_fighter(P2, P1, live)
  separate(P1, P2)
  update_projectiles(P1, P2)
  if ROUND.callout_t ~= nil and ROUND.callout_t > 0 then
    ROUND.callout_t = ROUND.callout_t - 1
    text_center(8, ROUND.callout)
    if ROUND.callout_t == 0 then clear_row(8) end
  end
  draw_hud()
  if ROUND.state == "intro" then
    if ROUND.timer < 70 then text_center(10, "ROUND " .. ROUND.num)
    elseif ROUND.timer < 110 then text_center(10, "FIGHT! ")
    else clear_row(10); ROUND.state = "fight"; ROUND.timer = 0 end
  elseif ROUND.state == "fight" then
    if ROUND.timer % 60 == 0 and ROUND.clock > 0 then ROUND.clock = ROUND.clock - 1 end
    if P2.hp <= 0 then fight_over(P1, "K.O.")
    elseif P1.hp <= 0 then fight_over(P2, "K.O.")
    elseif ROUND.clock <= 0 then
      if P1.hp > P2.hp then fight_over(P1, "TIME UP") elseif P2.hp > P1.hp then fight_over(P2, "TIME UP") else fight_over(nil, "DRAW") end
    end
  elseif ROUND.state == "roundend" then
    if ROUND.timer < 60 then
      text_center(10, ROUND.msg)
    else
      local w = ROUND.winner
      if w ~= nil then
        text_center(10, CHAR_NAME[w.char] .. " WINS   ")
        if w.state ~= "ko" then
          w.state = "win"
          w.pose = ((ROUND.timer // 15) % 2 == 0) and POSE_SUPER or POSE_IDLE
        end
      end
    end
    if ROUND.timer == 150 then
      if ROUND.winner ~= nil and ROUND.winner.wins >= 2 then
        ROUND.state = "matchend"; ROUND.timer = 0
      else
        ROUND.num = ROUND.num + 1
        reset_round()
      end
    end
  elseif ROUND.state == "matchend" then
    local w = ROUND.winner
    text_center(10, CHAR_NAME[w.char] .. " WINS THE MATCH")
    text_center(12, (w == P1) and "NAP TIME FOR THE CPU!" or "WAAAH! TRY AGAIN!")
    if w.state ~= "ko" then w.pose = ((ROUND.timer // 15) % 2 == 0) and POSE_SUPER or POSE_IDLE end
    if ROUND.timer > 120 and any_button() then go_title() end
    if ROUND.timer > 600 then go_title() end
  end
end

function frame(t, f)
  brightness = 15
  local st = ROUND.state
  if st == "title" then update_title()
  elseif st == "select" then update_select()
  else update_fight() end
  draw_sprites()
  if st == "select" then draw_select_sprites() end
  remember_pad()
end
