-- check_ranges.lua: run the cart under plain Lua with every ---@snes array/range contract enforced on store,
-- the way the cartridge runtime enforces them (a violation on hardware is the red "contract failed" screen).
-- usage: lua tools/check_ranges.lua [frames] [seed]   (random P1 input against the CPU; P2 = CPU)
floor, ceil, abs = math.floor, math.ceil, math.abs
sin, cos, sqrt = math.sin, math.cos, math.sqrt
function min(a, b) return math.min(a, b) end
function max(a, b) return math.max(a, b) end
function rgb(r, g, b) return (b // 8) << 10 | (g // 8) << 5 | (r // 8) end

local FILES = { "data.lua", "sprites.lua", "stage.lua", "main.lua", "upload.lua" }
local ranges, arrays = {}, {}        -- name -> {lo, hi} ; name -> {n, lo, hi}
local src = {}
for _, f in ipairs(FILES) do
  local fh = io.open("cart/" .. f); if fh then src[f] = fh:read("a"); fh:close() end
end
for f, text in pairs(src) do
  for name, lo, hi in text:gmatch("%-%-%-@snes range (%S+) (%-?%d+) (%-?%d+)") do ranges[name] = { tonumber(lo), tonumber(hi) } end
  for name, n, lo, hi in text:gmatch("%-%-%-@snes array (%S+) (%d+) (%-?%d+) (%-?%d+)") do arrays[name] = { tonumber(n), tonumber(lo), tonumber(hi) } end
end
local violations, seen = 0, {}
local CUR_FRAME = 0
local function fail(what, v, lo, hi)
  local key = what
  if not seen[key] then
    seen[key] = true; violations = violations + 1
    print(string.format("CONTRACT FAILED f=%d %s = %s outside [%d, %d]\n%s", CUR_FRAME, what, tostring(v), lo, hi, debug.traceback("", 3)))
  end
end
local function wrap_array(name, t, spec)
  local n, lo, hi = spec[1], spec[2], spec[3]
  local store = {}
  for i = 1, n do
    local v = t[i]
    if v == nil then v = 0 end
    if v < lo or v > hi then fail(name .. "[" .. i .. "] (initial)", v, lo, hi) end
    store[i] = v
  end
  if #t > n then fail(name .. " length", #t, n, n) end
  return setmetatable({}, {
    __index = function(_, k)
      if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then fail(name .. " index", k, 1, n); return 0 end
      return store[k]
    end,
    __newindex = function(_, k, v)
      if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then fail(name .. " index", k, 1, n); return end
      if type(v) ~= "number" or v ~= math.floor(v) then fail(name .. "[" .. k .. "] non-integer", v, lo, hi)
      elseif v < lo or v > hi then fail(name .. "[" .. k .. "]", v, lo, hi) end
      store[k] = v
    end,
    __len = function() return n end,
  })
end
local shadow = {}
setmetatable(_G, {
  __index = function(_, k) return shadow[k] end,
  __newindex = function(t, k, v)
    if arrays[k] and type(v) == "table" then rawset(t, k, wrap_array(k, v, arrays[k])); return end
    if ranges[k] then
      local lo, hi = ranges[k][1], ranges[k][2]
      if type(v) ~= "number" or v ~= math.floor(v) then fail(k .. " non-integer", v, lo, hi)
      elseif v < lo or v > hi then fail(k, v, lo, hi) end
      shadow[k] = v; return
    end
    rawset(t, k, v)
  end,
})

local function sink()
  local s = {}; local mt = {}
  mt.__index = function(t, k) local v = sink(); rawset(t, k, v); return v end
  mt.__newindex = function(t, k, v) rawset(t, k, v) end
  return setmetatable(s, mt)
end
vram, cgram, bg, screen, m7 = sink(), sink(), sink(), sink(), sink()
-- obj: 128 entries, x/y/tile ranges checked like the PPU would see them
obj = setmetatable({}, { __index = function(t, k)
  if type(k) ~= "number" then local v = sink(); rawset(t, k, v); return v end
  if k < 0 or k > 127 then fail("obj index", k, 0, 127) end
  local o = setmetatable({}, { __newindex = function(ot, f, v)
    if f == "x" and (v < -256 or v > 255) then fail("obj[" .. k .. "].x", v, -256, 255) end
    if f == "y" and (v < -32 or v > 255) then fail("obj[" .. k .. "].y", v, -32, 255) end
    if f == "tile" and (v < 0 or v > 511) then fail("obj[" .. k .. "].tile", v, 0, 511) end
    rawset(ot, f, v)
  end })
  rawset(t, k, o); return o
end })
pad = { left=false,right=false,up=false,down=false,a=false,b=false,x=false,y=false,l=false,r=false,start=false,select=false }
mode, brightness = 1, 15
function dma(name, o) return { name = name, char = (o and o.char) or 0, map = (o and o.map) or 0, pal = (o and o.pal) or 0, tile = 0 } end
function bank() return {} end
function sfx() end
function koff() end
function score() return { play = function() end, stop = function() end } end
-- a vram store counter so the VBlank window budget can be reported
local vram_writes, vram_bad = 0, 0
local VB_LO, VB_HI
for f, text in pairs(src) do local a, b = text:match("%-%-%-@snes vblank (%d+) (%d+)"); if a then VB_LO, VB_HI = tonumber(a), tonumber(b) end end
local in_frame = false
local vram_store = {}
vram = setmetatable({}, { __index = vram_store, __newindex = function(t, k, v)
  if in_frame then
    vram_writes = vram_writes + 1
    if VB_LO and (k < VB_LO or k > VB_HI) then vram_bad = vram_bad + 1 end
  end
  vram_store[k] = v
end })

for _, f in ipairs(FILES) do
  if src[f] then local chunk = assert(load(src[f], "@cart/" .. f)); chunk() end
end
local ok, err = xpcall(init, debug.traceback)
if not ok then print("INIT ERROR", err); os.exit(1) end
local N = tonumber(arg[1]) or 20000
math.randomseed(tonumber(arg[2]) or 7)
local keys = { "left", "right", "up", "down", "y", "b", "a", "x" }
local hold = 0
in_frame = true
for f = 1, N do
  CUR_FRAME = f
  if hold == 0 then
    for _, k in ipairs(keys) do pad[k] = false end
    local n = math.random(0, 3)
    for _ = 1, n do pad[keys[math.random(#keys)]] = true end
    hold = math.random(1, 24)
  end
  hold = hold - 1
  local ok, err = xpcall(frame, debug.traceback, f / 60, f)
  if not ok then print("FRAME", f, "ERROR", err); os.exit(1) end
  if f % 2400 == 0 then
    print(string.format("f=%d P1 x=%d y=%d st=%d hp=%d | P2 x=%d y=%d st=%d hp=%d clock=%d", f, FX[1]//16, FY[1]//16, FSTATE[1], FHP[1], FX[2]//16, FY[2]//16, FSTATE[2], FHP[2], CLOCK))
  end
end
print(string.format("%d frames, %d distinct contract violations, %d vram words written from frame() (%d outside the vblank window)", N, violations, vram_writes, vram_bad))
os.exit(violations == 0 and 0 or 2)
