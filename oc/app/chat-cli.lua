-- I, 20kdc, release this into the public domain.
-- No warranty is provided, implied or otherwise.
-- Chat client
local serv = ({...})[1]
local event = require("event")
local term = require("term")
local gpu = term.gpu()
local occure = require("occure")
-- show a message onscreen
local sw, sh = gpu.getResolution()
-- The idea is to use the term API and the normal stuff at the same time.
-- Ehehe.
local function postMessage(s)
	gpu.copy(1, 2, sw, sh - 3, 0, -1)
	gpu.fill(1, sh - 2, sw, 2, " ")
	gpu.set(1, sh - 2, s)
end
local function sysCallback(tp, nfrom, nto, port, data, un)
	if tp == "copper_packet" then
		if nfrom == serv then
			if nto == occure.getHostname() then
				if port == 3 then
					postMessage(data)
				end
			end
		end
	end
end
event.listen("copper_packet", sysCallback)
local cancelMeLater = event.timer(1, function()
	occure.output(serv, 2, "")
end, math.huge)
pcall(function()
	while true do
		term.setCursor(1, sh)
		local text = term.read({nowrap = true})
		-- Because Term Sucks (tm)
		gpu.fill(1, sh - 1, sw, 1, " ")
		gpu.copy(1, 1, sw, sh - 1, 0, 1)
		gpu.fill(1, 1, sw, 1, " ")
		occure.output(serv, 2, text:sub(1, text:len() - 1))
	end
end)
event.ignore("copper_packet", sysCallback)
event.cancel(cancelMeLater)
