-- I, 20kdc, release this into the public domain.
-- No warranty is provided, implied or otherwise.

-- Light Copper Base node that communicates to a server via an 
--  Internet Card.
-- Only handles one modem for now.

local args = {...}
if #args ~= 3 then error("name, tcphost, tcpport") end

local component = require("component")
local cdlib = require("cdlib")
local event = require("event")

-- Adjust to taste.
local tcp = require("internet").open(tostring(args[2]), tonumber(args[3]))

local md = component.modem
md.open(4957)

tcp:setTimeout(0.05)
tcp:write(string.char((#(args[1])) - 1) .. args[1])
tcp:flush()

print("TCP up")

local function verify(d)
	local hops, src, dst, data = cdlib.decode(d)
	if not data then return end
	-- Just a bit of filtering
	if dst:sub(1, 1) ~= "^" then return end
	if d:len() > 2022 then return end
	return true
end

local function readByte()
	while true do
		local ok, err = pcall(tcp.read, tcp, 1)
		if ok then return err end
		-- not nice :(
		if err:find("timeout") then
			coroutine.yield()
		else
			error(err)
		end
	end
end
local function readerRoutine()
	while true do
		local h = readByte()
		local l = readByte()
		local sz = string.byte(l) + (string.byte(h) * 256)
		print("Incoming packet size " .. sz)
		local dat = ""
		for i = 1, sz do
			dat = dat .. readByte()
		end
		if dat ~= "" then
			md.broadcast(4957, "copper", dat)
		end
	end
end

event.timer(10, function ()
	tcp:write("\x00\x00")
	tcp:flush()
end, math.huge)

local primary = coroutine.create(readerRoutine)
while true do
	local et, _, _, p, _, m, d = event.pull(0.1)
	local ok, o = coroutine.resume(primary)
	if not ok then error(o) end
	if et == "modem_message" and p == 4957 then
		if m == "copper" then
			-- Incoming Copper packet.
			if verify(d) then
				local h = math.floor(d:len() / 256)
				local l = d:len() % 256
				tcp:write(string.char(h, l) .. d)
				tcp:flush()
			end
		end
	end
end
