-- I, 20kdc, release this into the public domain.
-- No warranty is provided, implied or otherwise.

-- Copper Reliability Layer
-- Notably, this should be instantiated rather than the normal Copper instance.

local culib = require("culib")

-- onRReceive is now: (from, to, port, data, unreliablePacket)
-- where to can be anything for unreliable packets, but otherwise is the current hostname.
return function (hostname, transmit, onRReceive, time)
	-- node.hostname should be used for hostname generally.
	local node
	local onReceive = function (nfrom, nto, data)
		if data:len() < 6 then return end
		local port = data:byte(2) + (data:byte(1) * 256)
		if data:byte(7) == 0x0F then
			onRReceive(nfrom, nto, port, data, true)
			return
		end
		if nto ~= node.hostname then
			return
		end
	end
	node = culib(hostname, transmit, onReceive, time)

	-- Just an array, no special index.
	-- Contents : {
	--     trigger = function(),
	--     expiry = time,
	-- }
	local timers = {}
	local relib = {}
	relib.refresh = function ()
		node.refresh()
		local i = 1
		local t = time()
		while i <= #timers do
			if timers[i].expiry < t then
				table.remove(timers, i)
			else
				i = i + 1
			end
		end
	end
	relib.input = node.input
	relib.output = function ()
		
	end
end
