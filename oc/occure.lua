-- I, 20kdc, release this into the public domain.
-- No warranty is provided, implied or otherwise.

-- OC/CU/RE Driver
-- (Copper w/Reliability Layer on OpenComputers/OpenOS)
-- I, 20kdc, release this into the public domain.
-- No warranty is provided, implied or otherwise.

local event = require("event")
local computer = require("computer")
local component = require("component")

local modems = {}
local args = {...}
if #args ~= 1 then error("Needs hostname") end
local host = tostring(args[1])

if package.loaded["occure"] then
  error("Already installed")
end

local node = require("relib")(host, function (tgt, data)
  for _, v in ipairs(modems) do
    if tgt then
      v.send(tgt, 4957, "copper", data)
    else
      v.broadcast(4957, "copper", data)
    end
  end
end, function (...)
  computer.pushSignal("copper_packet", ...)
end, computer.uptime)

package.loaded["occure"] = node

for v, _ in component.list("modem") do
  local m = component.proxy(v)
  table.insert(modems, m)
  m.open(4957)
end
event.listen("modem_message", function (et, adto, adfrom, port, dist, magic, data)
  if et ~= "modem_message" then return end
  if port == 4957 then
    if magic == "copper" then
      node.input(adfrom, data)
    end
  end
end)
event.timer(1, node.refresh, math.huge)
