-- I, 20kdc, release this into the public domain.
-- No warranty is provided, implied or otherwise.

-- 'Copper' networking - "The Routing Library".
-- This is meant as a portable (even into OC) library for networking.
-- This 'outer function' is the instantiator.

-- Note that it is probably possible to cause this code to run out of 
--  memory in several hilarious ways.
-- I've taken the approach that reduction of code .

-- Interfaces have no meaning, since addresses are names.
-- Which "side" a system is on is irrelevant.
-- (Unless you're developing a hierarchial gateway, in which case this library isn't for you
--   as it follows a default set of routing rules. Switch to cdlib for fine-grained control.)

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

local cdlib = require("cdlib")

return function (hostname, transmit, onReceive, time)

	-- How many packets need to be stored in seenBefore's keyspace
	--  before 'panic' is the best response?
	local tuningMaxSeenBeforeCountBeforeEmergencyFlush = 0x100

	-- Prevents OOM by LKR cache flooding - how many entries can the LKR have, max?
	-- (Though spamming packets from many sources is now a viable method for dropping LKR,
	--  it used to be a viable OOM method.)
	-- Note that setting this to 0 or less will effectively result in a value of 1.
	local tuningMaxLKREntries = 0x200

	-- Expect another packet after this amount of time,
	--  or else clear the known receivers cache entry.
	-- Minimum should be less or equal to tuningAttempts * 
	--  tuningAttemptTime in relib.
	local tuningExpectContinue = 15 + math.random(15)

	-- Flush the loop detector every so often.
	-- This is not a complete clear.
	local tuningFlushLoopDetector = 60

	-- Do not change this value unless protocol has changed accordingly.
	local tuningAutorejectLen = 1507

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
	-- How many LKR entries are there?
	local lkrCacheCount = 0

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
				lastKnownReceiver[k] = nil
			end
		end
	end

	-- Used to clean up LKR entries to prevent OOM.
	local function removeOldestLKR()
		local lowest = nil
		local lowestExpiry = math.huge
		for k, v in pairs(lastKnownReceiver) do
			if v[2] < lowestExpiry then
				lowest = k
			end
		end
		if lowest then
			lastKnownReceiver[lowest] = nil
			lkrCacheCount = lkrCacheCount - 1
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

		local fnam, tnam, data = cdlib.decodeNoHops(message)
		if not data then
			return
		end

		if data:len() > tuningAutorejectLen then
			return
		end

		if fnam ~= "*" then
			if not lastKnownReceiver[fnam] then
				-- if, not while, because if someone ignores my note above
				-- and sets the tuning to 0 it would crash otherwise. *sigh*
				if lkrCacheCount >= tuningMaxLKREntries then
					removeOldestLKR()
				end
				lkrCacheCount = lkrCacheCount + 1
			end
			lastKnownReceiver[fnam] = {node, t + tuningExpectContinue}
		end
		
		onReceive(fnam, tnam, data)
		if culib.hostname == tnam then return end

		-- Redistribution of messages not aimed here
		if hops == 255 then
			-- Don't redistribute
			return
		else
			-- Prepend the hops byte that got removed earlier
			message = string.char(hops + 1) .. message
		end

		local lkr = lastKnownReceiver[tnam]
		if lkr then
			culib.lkrCacheHits = culib.lkrCacheHits + 1
			transmit(lkr[1], message)
		else
			culib.lkrCacheMisses = culib.lkrCacheMisses + 1
			transmit(nil, message)
		end
	end
	culib.refresh = refresh
	culib.output = function (fnam, tnam, message)
		if message:len() > tuningAutorejectLen then error("Attempted to send too long packet") end
		onReceive(fnam, tnam, message)
		if tnam == culib.hostname then return end
		local m = cdlib.encode(0, fnam, tnam, message)
		transmit(nil, m)
	end
	return culib
end
