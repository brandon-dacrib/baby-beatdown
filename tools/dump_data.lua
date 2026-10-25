-- dump_data.lua: load the Studio toy under plain Lua (same stubs as dump_poses) and dump the gameplay
-- tables the cart needs (ATTACKS, SUPER, STANCE, CHAR_NAME, POSE ids) as JSON.
local toydir, out = arg[1], arg[2]
floor, ceil, abs = math.floor, math.ceil, math.abs
sin, cos, sqrt, atan = math.sin, math.cos, math.sqrt, math.atan
function min(...) return math.min(...) end
function max(...) return math.max(...) end
function rnd(n) return n and math.random(n) or math.random() end
random = rnd
function rgb(r, g, b) return (b // 8) << 10 | (g // 8) << 5 | (r // 8) end
local function sink()
  local s = {}; local mt = {}
  mt.__index = function(t, k) local v = sink(); rawset(t, k, v); return v end
  mt.__call = function() return sink() end
  mt.__add = function() return 0 end; mt.__sub = mt.__add; mt.__mul = mt.__add; mt.__div = mt.__add
  mt.__idiv = mt.__add; mt.__mod = mt.__add; mt.__unm = mt.__add
  mt.__lt = function() return false end; mt.__le = mt.__lt
  mt.__concat = function() return "" end; mt.__tostring = function() return "sink" end
  return setmetatable(s, mt)
end
vram, cgram, obj, bg, m7, screen, pad, pad2, voice, dsp, window = sink(), sink(), sink(), sink(), sink(), sink(), sink(), sink(), sink(), sink(), sink()
mode, brightness, force_blank = 1, 15, false
function dma(name, opts) return { name = name, tile = 0, pal = 0, char = 0 } end
function bank(name, opts) return { name = name } end
function score(opts) return { play = function() end, stop = function() end, song = opts.song } end
function sfx() end
function hdma() end
local order = {}
for line in io.lines(toydir .. "/../00_LOAD_ORDER.md") do
  local f = line:match("^|%s*%d+b?%s*|%s*([%w_]+%.lua)")
  if f then order[#order + 1] = f end
end
local files = {}
local function add(f) files[#files + 1] = f end
for _, f in ipairs(order) do
  if f == "bg1.lua" then for i = 1, 8 do add("bg" .. i .. ".lua") end
    for i = 1, 8 do for _, p in ipairs({ "a", "b", "c", "m" }) do add("bg" .. i .. p .. ".lua") end end
  elseif f == "bg9.lua" then add("bg9.lua"); for _, p in ipairs({ "a", "b", "c", "m" }) do add("bg9" .. p .. ".lua") end
  elseif f == "face1.lua" then for i = 1, 8 do add("face" .. i .. ".lua") end
  else add(f) end
end
for _, f in ipairs(files) do
  local chunk, err = loadfile(toydir .. "/" .. f)
  if chunk then local ok, e = pcall(chunk); if not ok then io.stderr:write("WARN ", f, ": ", tostring(e), "\n") end end
end
-- minimal JSON encoder for plain tables (numbers, strings, booleans, nested tables)
local function enc(v, depth)
  depth = depth or 0
  local t = type(v)
  if t == "number" then if v ~= v or v == math.huge then return "null" end
    if v == floor(v) then return string.format("%d", v) end return string.format("%.4f", v) end
  if t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"' end
  if t == "boolean" then return tostring(v) end
  if t ~= "table" or depth > 4 then return "null" end
  if getmetatable(v) then return "null" end
  local n = #v
  if n > 0 then local a = {}; for i = 1, n do a[i] = enc(v[i], depth + 1) end; return "[" .. table.concat(a, ",") .. "]" end
  local keys = {}
  for k in pairs(v) do if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local a = {}
  for _, k in ipairs(keys) do local e = enc(v[k], depth + 1); if e ~= "null" then a[#a + 1] = '"' .. tostring(k) .. '":' .. e end end
  return "{" .. table.concat(a, ",") .. "}"
end
local poses = {}
for k, v in pairs(_G) do if type(k) == "string" and k:match("^POSE_") and type(v) == "number" then poses[k] = v end end
local dump = { ATTACKS = ATTACKS, SUPER = SUPER, STANCE = STANCE, CHAR_NAME = CHAR_NAME, POSE = poses,
  FLOOR_Y = FLOOR_Y, HP_MAX = HP_MAX, METER_MAX = METER_MAX, GRAVITY = GRAVITY, RUSH_BOX = RUSH_BOX,
  STYLE = STYLE, ART = ART, MOVENAME = MOVENAME, IDLE2 = IDLE2 }
local fh = assert(io.open(out, "w")); fh:write(enc(dump)); fh:close()
io.stderr:write("dumped to ", out, "\n")
