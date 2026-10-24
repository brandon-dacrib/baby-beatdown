-- dump_poses.lua: run the Studio toy's renderer under plain Lua and write every pose of every
-- character as a 64x64 palette-index grid (JSON) for the cartridge sprite sheets.
-- usage: lua tools/dump_poses.lua toy/ render/poses/
local toydir, outdir = arg[1], arg[2]

-- ---- Studio globals, stubbed ------------------------------------------------
floor, ceil, abs = math.floor, math.ceil, math.abs
sin, cos, sqrt, atan = math.sin, math.cos, math.sqrt, math.atan
function min(...) return math.min(...) end
function max(...) return math.max(...) end
function rnd(n) return n and math.random(n) or math.random() end
random = rnd
function rgb(r, g, b) return (b // 8) << 10 | (g // 8) << 5 | (r // 8) end
local function sink()
  local s = {}
  local mt = {}
  mt.__index = function(t, k) local v = sink(); rawset(t, k, v); return v end
  mt.__call = function() return sink() end
  mt.__add = function() return 0 end; mt.__sub = mt.__add; mt.__mul = mt.__add; mt.__div = mt.__add
  mt.__idiv = mt.__add; mt.__mod = mt.__add; mt.__unm = mt.__add
  mt.__lt = function() return false end; mt.__le = mt.__lt
  mt.__concat = function() return "" end
  mt.__tostring = function() return "sink" end
  return setmetatable(s, mt)
end
vram, cgram, obj, bg, m7, screen, pad, pad2, voice, dsp, window = sink(), sink(), sink(), sink(), sink(), sink(), sink(), sink(), sink(), sink(), sink()
mode, brightness, force_blank = 1, 15, false
function dma(name, opts) return { name = name, tile = 0, pal = 0, char = 0 } end
function bank(name, opts) return { name = name } end
function score(opts) return { play = function() end, stop = function() end, song = opts.song } end
function sfx() end
function hdma() end
function error_or_warn(msg) io.stderr:write(msg, "\n") end

-- ---- load the toy in Studio order -------------------------------------------
local order = {}
for line in io.lines(toydir .. "/../00_LOAD_ORDER.md") do
  local f = line:match("^|%s*%d+b?%s*|%s*([%w_]+%.lua)")
  if f then order[#order + 1] = f end
end
-- expand the grouped rows of the load-order table
local files = {}
local function add(f) files[#files + 1] = f end
for _, f in ipairs(order) do
  if f == "bg1.lua" then
    for i = 1, 8 do add("bg" .. i .. ".lua") end
    for i = 1, 8 do for _, p in ipairs({ "a", "b", "c", "m" }) do add("bg" .. i .. p .. ".lua") end end
  elseif f == "bg9.lua" then
    add("bg9.lua"); for _, p in ipairs({ "a", "b", "c", "m" }) do add("bg9" .. p .. ".lua") end
  elseif f == "face1.lua" then
    for i = 1, 8 do add("face" .. i .. ".lua") end
  else add(f) end
end
for _, f in ipairs(files) do
  local chunk, err = loadfile(toydir .. "/" .. f)
  if not chunk then error(err) end
  local ok, e = pcall(chunk)
  if not ok then io.stderr:write("WARN ", f, ": ", tostring(e), "\n") end
end
io.stderr:write("loaded ", #files, " files; poses defined: ", #POSES + 1, "\n")

-- ---- dump --------------------------------------------------------------------
local function json_grid(c)
  local rows = {}
  for y = 0, 63 do
    local r = {}
    for x = 0, 63 do r[#r + 1] = string.format("%x", c[y * 64 + x] or 0) end
    rows[#rows + 1] = '"' .. table.concat(r) .. '"'
  end
  return "[" .. table.concat(rows, ",") .. "]"
end
local npose = #POSES
for ci = 1, 8 do
  local out = { '{"char":' .. ci .. ',"name":"' .. tostring(CHAR_NAME[ci]) .. '","palette":[' }
  local pal = {}
  for i = 1, 15 do local p = CHAR_PAL[ci][i]; pal[#pal + 1] = string.format("[%d,%d,%d]", p[1], p[2], p[3]) end
  out[#out + 1] = table.concat(pal, ",") .. '],"poses":{'
  local ps = {}
  local nonempty = 0
  for pi = 0, npose do
    if POSES[pi] then
      local ok, c = pcall(render_pose, ci, pi)
      if ok and c then
        ps[#ps + 1] = '"' .. pi .. '":' .. json_grid(c)
        nonempty = nonempty + 1
      else
        io.stderr:write("char ", ci, " pose ", pi, " failed: ", tostring(c), "\n")
      end
    end
  end
  out[#out + 1] = table.concat(ps, ",") .. "}}"
  local fh = assert(io.open(outdir .. "/char" .. ci .. ".json", "w"))
  fh:write(table.concat(out)); fh:close()
  io.stderr:write("char ", ci, " ", tostring(CHAR_NAME[ci]), ": ", nonempty, " poses\n")
end
