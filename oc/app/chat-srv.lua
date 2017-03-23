-- I, 20kdc, release this into the public domain.
-- No warranty is provided, implied or otherwise.
-- Chat server.
local occure = require("occure")
local event = require("event")

local subscriberPool = {}
local maxSubscribers = 100
local function removeSubscriber(a)
	for i = 1, #subscriberPool do
		if subscriberPool[i] == a then
			table.remove(subscriberPool, i)
			return true
		end
	end
	return false
end
local function addSubscriber(a)
	if removeSubscriber(a) then
		table.insert(subscriberPool, a)
		return
	end
	table.insert(subscriberPool, a)
	if #subscriberPool > maxSubscribers then
		table.remove(subscriberPool, 1)
	end
end
local repeatMessage = nil
function repeatMessage(msg)
	print(msg)
	for _, v in ipairs(subscriberPool) do
		occure.output(v, 3, msg)
	end
end
while true do
	-- Null packets: "subscribe me"
	local tp, nfrom, nto, nport, data = event.pull("copper_packet")
	if tp == "copper_packet" then
		if nto == occure.getHostname() then
			if nport == 2 then
				if data == "" then
					addSubscriber(nfrom)
				else
					repeatMessage("<" .. nfrom .. "> " .. data)
				end
			end
		end
	end
end
