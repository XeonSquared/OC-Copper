-- 'Copper' networking test implementation.
-- This is meant as a portable (even into OC) library for networking.
-- This 'outer function' is the instantiator.

-- Note that it is probably possible to cause this code to run out of 
--  memory in several hilarious ways.

-- Interfaces have no meaning, since addresses are names.
-- Which "side" a system is on is irrelevant.
-- For sending, the following function is used:
--  transmit(nodeId, message)
-- The nodeId is a string or number that has been given via culib.input,
--  or nil for broadcast.
-- It's more of a suggestion than a requirement to check nodeId.

-- The message is always a string.
-- This mirrors the message format usable by sendPacket and onReceive.

-- "onReceive" is a function which is called when a packet is decoded.
--  onReceive(namefrom, nameto, data)

-- "time" is a function which returns the real time, in seconds.
-- It need not be precise.
-- (This is used for caches.)
return function (hostname, transmit, onReceive, time)

	-- How many packets need to be stored in seenBefore's keyspace
	--  before 'panic' is the best response?
	local tuningMaxSeenBeforeCountBeforeEmergencyFlush = 0x300

	-- Expect another packet after this amount of time,
	--  or else clear the known receivers cache entry.
	local tuningExpectContinue = 600 + math.random(1200)

	-- Flush the loop detector every so often.
	-- This is not a complete clear.
	local tuningFlushLoopDetector = 60

	local tuningRandomPathwarming = 0.1

	-- Do not change this value unless protocol has changed accordingly.
	local tuningAutorejectLen = 1506

	local loopDetectorNext = time() + tuningFlushLoopDetector

	-- Packets that have been seen before.
	-- The values are the amount of times a packet has been seen.
	-- This is flushed every tuningFlushLoopDetector seconds -
	--  the flushing decrements the value until it reaches 0,
	--  so packets which have looped before get a longer timeout.
	local seenBefore = {}
	local seenBeforeCount = 0

	-- [address] = {
	--      node, -- the node that a message was received from
	--      expiry
	-- }
	local lastKnownReceiver = {}

	local function encodeName(name)
		if name:len() > 256 then error("Bad name (l>256)") end
		if name == "" then error("No name") end
		return string.char(name:len() - 1) .. name
	end

	local function refresh()
		local t = time()
		if t >= loopDetectorNext then
			for k, v in pairs(seenBefore) do
				local n = v - 1
				if n > 0 then
					seenBefore[k] = n
				else
					seenBefore[k] = nil
					seenBeforeCount = seenBeforeCount - 1
				end
			end
			loopDetectorNext = t + tuningFlushLoopDetector
		end
		for k, v in pairs(lastKnownReceiver) do
			if t >= v[2] then
				--print("It was decided LKV[" .. k .. "] was out of date @ " .. v[2] .. " by " .. hostname)
				-- Keep the transmission path 'warm' with a null packet
				if math.random() < tuningRandomPathwarming then
					transmit(nil, "\xFF" .. encodeName(hostname) .. encodeName(k))
				end
				lastKnownReceiver[k] = nil
			end
		end
	end

	local culib = {}

	-- Can be changed.
	culib.hostname = hostname

	-- Stats.
	culib.lkrCacheMisses = 0
	culib.lkrCacheHits = 0

	culib.input = function (node, message)
		local t = time()

		-- Eliminate the hops value first of all.
		local hops = message:byte(1)
		message = message:sub(2)

		if seenBefore[message] then
			seenBefore[message] = seenBefore[message] + 1
			return
		else
			seenBefore[message] = 2
			seenBeforeCount = seenBeforeCount + 1
			if seenBeforeCount > tuningMaxSeenBeforeCountBeforeEmergencyFlush then
				-- Panic
				seenBeforeCount = 0
				seenBefore = {}
			end
		end
		-- Begin parsing.

		local rawmessage = message

		if message:len() < 2 then return end
		local nlen = message:byte(1) + 1
		local fnam = message:sub(2, nlen + 1)
		message = message:sub(nlen + 2)

		if message:len() < 2 then return end
		local nlen = message:byte(1) + 1
		local tnam = message:sub(2, nlen + 1)
		message = message:sub(nlen + 2)

		if message:len() > tuningAutorejectLen then
			return
		end

		lastKnownReceiver[fnam] = {node, t + tuningExpectContinue}
		
		onReceive(fnam, tnam, message)
		if culib.hostname == tnam then return end

		-- Redistribution of messages not aimed here
		if hops == 255 then
			return
		else
			rawmessage = string.char(hops + 1) .. rawmessage
		end

		local lkr = lastKnownReceiver[tnam]
		if lkr then
			culib.lkrCacheHits = culib.lkrCacheHits + 1
			transmit(lkr[1], rawmessage)
		else
			culib.lkrCacheMisses = culib.lkrCacheMisses + 1
			transmit(nil, rawmessage)
		end
	end
	culib.refresh = refresh
	culib.output = function (fnam, tnam, message)
		onReceive(fnam, tnam, message)
		if tnam == culib.hostname then return end
		local m = "\x00" .. encodeName(fnam) .. encodeName(tnam) .. message
		transmit(nil, m)
	end
	return culib
end
