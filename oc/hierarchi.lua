-- I, 20kdc, release this into the public domain.
-- No warranty is provided, implied or otherwise.

-- Copper Hierarchial Gateway implementation for OpenComputers.
-- Best run in a Server with two modems,
--  but can be run with a support program on another computer with a modem,
--  one modem in the main computer, and a LC pair.

-- The only reason this isn't run on two microcontrollers is because 
--  they're inconvenient to use and cdlib needs to be there -
-- I'm sure you can port it yourself.

local args = {...}

if #args ~= 2 then
	error("Expecting args: outboundModem (or 'relay' to use Linked Cards), network-name") 
end

-- What is the name of this division, including forward-slash?
local netname = args[2] .. "/"

local outboundModemAdr = args[1]

-- These names are chosen by sending direction.
local outboundModem, inboundModem

if outboundModemAdr == "relay" then outboundModemAdr = nil end

local event = require("event")
local component = require("component")
local cdlib = require("cdlib")

for a, _ in component.list("modem") do
	if outboundModemAdr and (a:sub(1, outboundModemAdr:len()) == outboundModemAdr) then
		if outboundModem then error("Outbound modem ambiguous.") end
		outboundModem = component.proxy(a)
	else
		if inboundModem then error("More than one internal-side modem.") end
		inboundModem = component.proxy(a)
	end
end

inboundModem.open(4957)
if not outboundModemAdr then
	local tunnel = component.tunnel
	-- Implement just enough of an outbound modem to be useful.
	outboundModem = {
		address = tunnel.address,
		broadcast = function (port, ...)
			tunnel.send(...)
		end
	}
else
	outboundModem.open(4957)
end

------ By this point, inboundModem and outboundModem must be:
-- 1. non-nil
-- 2. have the address and broadcast(port, ...) fields
-- (Also, if outboundModemAdr == nil then the port will be ignored for it.)

-- Rules used on messages coming in from the 'modem' side.
-- (This implies Tunnel packets are trusted absolutely - which is correct.)
local processFrom, processTo

-- Implementation of the rules described in protocol.1 for more or 
--  less unambiguous name translation.
-- "incoming" is parent-side, incoming being false means child-side.
processFrom = function (incoming, from)
	if incoming then
		if from:sub(1, netname:len()) == netname then
			return
		end
		return "^" .. from
	else
		if from:sub(1, 1) == "^" then
			return
		end
		return netname .. from
	end
end
processTo = function (incoming, nto)
	if incoming then
		if nto:sub(1, netname:len()) ~= netname then
			return
		end
		return nto:sub(netname:len() + 1)
	else
		if nto:sub(1, 1) ~= "^" then
			return
		end
		return nto:sub(2)
	end
end

local function checkLen(s)
	if not s then return end
	if s:len() == 0 then return end
	if s:len() > 256 then return end
	return s
end

local function handlePacket(incoming, dat)
	local hops, nfrom, nto, data = cdlib.decode(dat)
	if not data then return end -- corrupt packet
	if hops == 255 then return end

	local tfrom, tto = checkLen(processFrom(incoming, nfrom)), checkLen(processTo(incoming, nto))
	if tfrom and tto then
		local resdata = cdlib.encode(hops + 1, tfrom, tto, data)
		if incoming then
			inboundModem.broadcast(4957, "copper", resdata)
		else
			outboundModem.broadcast(4957, "copper", resdata)
		end
	end
end

while true do
	local e = {event.pull("modem_message")}
	if e[1] == "modem_message" then
		-- type, receiver, sender, port, dist, magic, data
		if (e[2] == inboundModem.address) or (e[2] == outboundModem.address) then
			local incoming = e[2] == outboundModem.address
			if (e[4] == 4957) or (incoming and (outboundModemAdr == nil)) then
				if (e[6] == "copper") and e[7] then
					handlePacket(incoming, e[7])
				end
			end
		end
	end
end
