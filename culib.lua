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
	local tuningMaxSeenBeforeCountBeforeEmergencyFlush = 0x100

	-- Expect a response by this many seconds,
	-- or else clear the known receivers cache and resend.
	local tuningExpectResponse = 20

	-- Flush the loop detector every so often.
	-- This is not a complete clear.
	local tuningFlushLoopDetector = 120

	-- Do not change this value. I mean it. Don't. Just. Don't.
	local tuningAutorejectLen = 4000

	local loopDetectorNext = time() + tuningFlushLoopDetector

	-- Packets that have been seen before.
	-- The values are the amount of times a packet has been seen.
	-- This is flushed every tuningFlushLoopDetector seconds -
	--  the flushing decrements the value until it reaches 0,
	--  so packets which have looped before get a longer timeout.
	local seenBefore = {}
	local seenBeforeCount = 0

	-- Unacknowledged packets.
	-- Can cause an earlier cache flush.
	-- [address] = giveupTime
	-- (These are just forgotten after a while)
	--local sentBNR = {}--NYI

	-- [address] = {
	--      node,
	--      expiry
	-- }
	--local lastKnownReceiver = {}--NYI

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
			loopDetectorNext = time() + tuningFlushLoopDetector
		end
	end

	local culib = {}

	-- Can be changed.
	culib.hostname = hostname
	culib.input = function (node, message)
		if message:len() > tuningAutorejectLen then
			return
		end
		if seenBefore[message] then
			seenBefore[message] = seenBefore[message] + 1
			return
		else
			seenBefore[message] = 0
			seenBeforeCount = seenBeforeCount + 1
			if seenBeforeCount > tuningMaxSeenBeforeCountBeforeEmergencyFlush then
				-- Panic
				seenBeforeCount = 0
				seenBefore = {}
			end
		end
		if message:len() < 2 then return end
		local nlen = message:byte(1) + 1
		local fnam = message:sub(1, nlen)
		message = message:sub(nlen + 1)
		if message:len() < 2 then return end
		local nlen = message:byte(1) + 1
		local tnam = message:sub(1, nlen)
		message = message:sub(nlen + 1)
		if message:len() < 1 then return end
		onReceive(fnam, tnam, message)
		if culib.hostname == tnam then return end
		-- Redistribution of messages not aimed here
		transmit(nil, message)
	end
	culib.output = function (fnam, tnam, message)
		onReceive(fnam, tnam, message)
		if tnam == culib.hostname then return end
		transmit(nil, encodeName(fnam) .. encodeName(tnam) .. message)
	end
	return culib
end
