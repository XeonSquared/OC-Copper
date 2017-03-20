-- I, 20kdc, release this into the public domain.
-- No warranty is provided, implied or otherwise.

-- Copper Hierarchial Gateway implementation for OpenComputers.
-- Should be run in a Server Rack, with two servers, connected by Linked Cards.
-- Each should be responsible for "it's" side.
-- This is a piece of dedicated hardware for a specific purpose.
-- The only reason it's not run on two microcontrollers is because 
--  they're inconvenient to use and cdlib needs to be there -
-- I'm sure you can port it yourself.

local args = {...}

-- Does the single modem connected to this server connect to the outside world?
local outbound = false

if #args ~= 2 then error("Expecting args: outbound ('true'/'false'), network-name") end

if args[1] == "true" then
	outbound = true
elseif args[1] ~= "false" then
	error("Only 'true' or 'false' are allowed for the 'outbound' argument.")
end

-- What is the name of this division, including forward-slash?
local netname = args[2] .. "/"

local event = require("event")
local component = require("component")
local cdlib = require("cdlib")

local modem = component.modem
local tunnel = component.tunnel

-- It is possible that this is meant to be used
--  on public wireless infrastructure -
-- for example, if this was a server-level domain,
--  perhaps solely connected via wireless...
-- Oh well. It's the sysadmin's decision to connect it this way.
-- Any wireless-abuse is the local regulator's decision.
if modem.isWireless() then
	modem.setStrength(400)
end
modem.open(4957)

-- Rules used on messages coming in from the 'modem' side.
-- (This implies Tunnel packets are trusted absolutely - which is correct.)
local processFrom, processTo

-- Implementation of the rules described in protocol.1 for more or 
--  less unambiguous name translation.
if outbound then
	processFrom = function (from)
		if from:sub(1, netname:len()) == netname then
			return
		end
		return "<" .. from
	end
	processTo = function (nto)
		if from:sub(1, netname:len()) ~= netname then
			return
		end
		return from:sub(netname:len() + 1)
	end
else
	processFrom = function (from)
		if from:sub(1, 1) == "<" then
			return
		end
		return netname .. from
	end
	processTo = function (nto)
		if from:sub(1, 1) ~= "<" then
			return
		end
		return from:sub(2)
	end
end

local function checkLen(s)
	if s:len() == 0 then return end
	if s:len() > 256 then return end
	return s
end

while true do
	local e = {event.pull("modem_message")}
	if e[1] == "modem_message" then
		-- type, to, from, port, dist, data
		if ((e[2] == tunnel.address) or (e[4] == 4957)) then
			local hops, nfrom, nto, data = cdlib.decode(e[6])
			if data then
				if e[2] == tunnel.address then
					-- Pass it on as given.
					modem.broadcast(4957, e[6])
				elseif e[2] == modem.address then
					-- Process it, then give to tunnel
					if hops ~= 255 then
						local tfrom, tto = checkLen(processFrom(nfrom)), checkLen(processTo(nto))
						if tfrom and tto then
							tunnel.send(cdlib.encode(hops + 1, tfrom, tto, data))
						end
					end
				end
			end
		end
	end
end
