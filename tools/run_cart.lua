-- run_cart.lua: run cart/*.lua under plain Lua with Studio stubs; usage: lua tools/run_cart.lua [frames]
floor, ceil, abs = math.floor, math.ceil, math.abs
sin, cos, sqrt = math.sin, math.cos, math.sqrt
function min(a, b) return math.min(a, b) end
function max(a, b) return math.max(a, b) end
function rgb(r, g, b) return (b // 8) << 10 | (g // 8) << 5 | (r // 8) end
local function sink()
  local s = {}; local mt = {}
  mt.__index = function(t, k) local v = sink(); rawset(t, k, v); return v end
  mt.__newindex = function(t, k, v) rawset(t, k, v) end
  return setmetatable(s, mt)
end
vram, cgram, obj, bg, screen, m7 = sink(), sink(), sink(), sink(), sink(), sink()
pad = { left=false,right=false,up=false,down=false,a=false,b=false,x=false,y=false,l=false,r=false,start=false,select=false }
mode, brightness = 1, 15
function dma(name, o) return { name = name, char = (o and o.char) or 0, map = (o and o.map) or 0, pal = (o and o.pal) or 0, tile = 0, next_char = ((o and o.char) or 0) + 0x2000 } end
function bank() return {} end
function sfx() end
function score() return {} end
for _, f in ipairs({ "data.lua", "sprites.lua", "main.lua", "upload.lua" }) do
  local chunk = assert(loadfile("cart/" .. f)); chunk()
end
local ok, err = xpcall(init, debug.traceback)
if not ok then print("INIT ERROR", err); os.exit(1) end
local N = tonumber(arg[1]) or 600
local script = { [30] = { right = true }, [90] = { right = false, y = true }, [92] = { y = false }, [150] = { b = true }, [152] = { b = false },
                 [200] = { down = true, b = true }, [203] = { down = false, b = false }, [260] = { up = true }, [262] = { up = false } }
for f = 1, N do
  if script[f] then for k, v in pairs(script[f]) do pad[k] = v end end
  local ok, err = xpcall(frame, debug.traceback, f / 60, f)
  if not ok then print("FRAME", f, "ERROR", err); os.exit(1) end
  if f % 60 == 0 then
    print(string.format("f=%d P1 x=%d y=%d st=%d hp=%d cell=%d | P2 x=%d st=%d hp=%d cell=%d plan=%d", f, FX[1]//16, FY[1]//16, FSTATE[1], FHP[1], FCELL[1], FX[2]//16, FSTATE[2], FHP[2], FCELL[2], AI_PLAN))
  end
end
print("ok", N, "frames")
