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

	-- The maximum amount of timers (used to cap memory usage)
	local tuningMaxTimers = 0x200
	local tuningClearAntiduplicate = 60
	local tuningAttempts = 8
	local tuningAttemptTime = 4

	-- Just an array, no special index.
	-- Contents : {
	--     trigger function,
	--     expiry time
	-- }
	local timers = {}
	-- Indexes are globalIds, values are timers for deleting entries out of this table.
	local weAcked = {}
	-- Indexes are globalIds, values are { successFunc, deathTimer }
	local needsAck = {}

	local function addTimer(trig, expi)
		if #timers < tuningMaxTimers then
			local t = {trig, time() + expi}
			table.insert(timers, t)
			return t
		end
		return nil
	end
	local function killTimer(t)
		for i = 1, #timers do
			if timers[i] == t then
				table.remove(timers, i)
				return
			end
		end
	end
	local function gen3Random()
		return string.char(math.random(256) - 1) .. string.char(math.random(256) - 1) .. string.char(math.random(256) - 1)
	end
	local function genGlobalId(port)
		local low = math.abs(math.floor(port)) % 256
		local high = math.abs(math.floor(port / 256)) % 256
		local portD = string.char(high) .. string.char(low)
		return portD .. gen3Random()
	end

	local onReceive = function (nfrom, nto, data)
		if data:len() < 7 then return end
		local port = data:byte(2) + (data:byte(1) * 256)
		local tp = data:byte(7)
		local globalId = data:sub(1, 5)
		if (tp == 0x01) or (tp == 0x00) then
			-- Only send one acknowledgement per packet,
			-- but only receive the packet once.
			-- (This is why timers are counted - to prevent the weAcked pool from getting too big.)
			if not weAcked[nto .. globalId] then
				onRReceive(nfrom, nto, port, data:sub(8), tp == 0x00)
			else
				killTimer(weAcked[nto .. globalId])
			end
			weAcked[nto .. globalId] = addTimer(function ()
				weAcked[nto .. globalId] = nil
			end, tuningClearAntiduplicate)

			-- Check if this should actually be ACKed
			if tp ~= 0x01 then return end
			if nto ~= node.hostname then return end
			node.output(nto, nfrom, data:sub(1, 6) .. "\x02")
		end
		if (tp == 0x02) and needsAck[nfrom .. globalId] then
			needsAck[nfrom .. globalId][1](nfrom)
			killTimer(needsAck[nfrom .. globalId][2])
			needsAck[nfrom .. globalId] = nil
		end
		if nto ~= node.hostname then
			return
		end
	end
	node = culib(hostname, transmit, onReceive, time)

	local relib = {}
	relib.setHostname = function (h)
		node.hostname = h
	end
	relib.getHostname = function ()
		return node.hostname
	end
	relib.refresh = function ()
		node.refresh()
		local i = 1
		local t = time()
		while i <= #timers do
			if timers[i][2] <= t then
				timers[i][1]()
				table.remove(timers, i)
			else
				i = i + 1
			end
		end
	end
	relib.input = node.input
	-- can be reduced to output(nto, port, data) safely
	relib.output = function (nto, port, data, unreliable, onSucceed, onFailure)
		onSucceed = onSucceed or (function () end)
		onFailure = onFailure or (function () end)
		local gid = genGlobalId(port)
		local tp = "\x01"
		-- Unreliable packets:
		-- 1. Can't be ACKed (not in the needsAck table)
		-- 2. Are otherwise subject to the same rules as regular packets
		if unreliable then
			tp = "\x00"
		end
		local na = {onSucceed}
		local attempt = -1
		local doAttempt
		doAttempt = function ()
			attempt = attempt + 1
			if attempt == tuningAttempts then
				if not unreliable then
					needsAck[nto .. gid] = nil
					onFailure()
				end
				return
			end
			node.output(node.hostname, nto, gid .. string.char(attempt) .. tp .. data)
			na[2] = addTimer(doAttempt, tuningAttemptTime)
			if not na[2] then
				needsAck[nto .. gid] = nil
				if not unreliable then
					onFailure()
				end
			end
		end
		if not unreliable then
			needsAck[nto .. gid] = na
		end
		doAttempt()
	end
	return relib
end
