-- TCP-based 'absolute root' node
-- Used to connect servers together.
-- A smart routing node which includes hierarchial gateways.
-- (Note: Multiple "absolute root" nodes can be used at once,
--   and things should work as long as there are no conflicts and
--   everybody who wants to communicate has a common root node.
--  A less efficient but potentially better approach would be to just 
--   have TCP-based Copper meshnet nodes
--   and run the gateways on the MC servers.)

local socket = require("socket")
local t = socket.bind("*", 4957)

local cdlib = require("cdlib")

local sockets = {}

local function getbyte(s)
	s:settimeout(0.05)
	while true do
		local d, e = s:receive(1)
		if not d then
			if e ~= "timeout" then
				return
			end
			coroutine.yield()
		else
			return d
		end
	end
end
local function getpacket(s)
	local h = getbyte(s)
	if not h then error("connection failed") end
	local l = getbyte(s)
	if not l then error("framing bad") end
	local sz = string.byte(l) + (string.byte(h) * 256)
	if sz > 2022 then error("packet too large") end
	local data = ""
	for i = 1, sz do
		local dbt = getbyte(s)
		if not dbt then error("terminated early") end
		data = data .. dbt
	end
	if data == "" then
		return false
	end
	return true, cdlib.decode(data)
end

local function checkLen(name)
	if name:len() == 0 then return end
	if name:len() > 256 then return end
	return name
end

local function translateSend(hops, src, dst, data, srname, tgsock, tgname)
	if src:sub(1, 1) == "^" then return end
	if dst:sub(1, tgname:len() + 2) ~= "^" .. tgname .. "/" then return end
	-- Ok, all rejection rules have been handled
	src = "^" .. srname .. "/" .. src
	dst = dst:sub(tgname:len() + 3)
	src, dst = checkLen(src), checkLen(dst)
	if src and dst then
		local enc = cdlib.encode(hops, src, dst, data)
		local h = math.floor(enc:len() / 256)
		local l = enc:len() % 256
		local frame = string.char(h, l)
		tgsock:send(frame .. enc)
	end
end

-- The main coroutine.
-- Moves messages around the system.
local function messageroutine(tbl)
	local b = getbyte(tbl[2])
	if not b then error("Didn't even send name") end
	local name = ""
	-- 0 is not a typo, this follows Copper name format.
	for i = 0, string.byte(b) do
		local b2 = getbyte(tbl[2])
		if not b2 then error("Didn't even complete name") end
		name = name .. b2
	end
	print("confirmed name " .. name)
	tbl[3] = name
	while true do
		local rcv, hops, src, dst, data = getpacket(tbl[2])
		if rcv then
			if not data then
				error("Bad Copper packet")
			end
			print("packet", src, dst)
			if hops ~= 255 then
				for _, v in ipairs(sockets) do
					if v[3] then
						if v ~= tbl then
							translateSend(hops + 1, src, dst, data, name, v[2], v[3])
						end
					end
				end
			end
		else
			-- Ping response
			tbl[2]:send("\x00\x00")
		end
	end
end
while true do
	t:settimeout(0.05)
	local ns = t:accept()
	if ns then
		-- Note: packets are ~500 bytes, Copper data can be ~2KB
		--  but it isn't USUALLY that way.
		-- ns:setoption("tcp-nodelay", true)
		ns:setoption("keepalive", true)
		print("incoming")
		local co = coroutine.create(messageroutine)
		local tbl = {co, ns}
		table.insert(sockets, tbl)
		local ok, r = coroutine.resume(co, tbl)
		if not ok then
			-- do cleanup later
			print("connection died quick", r)
		end
	end
	local i = 1
	while i <= #sockets do
		local ok, r = coroutine.resume(sockets[i][1])
		if not ok then
			print("dropping conn", r)
			table.remove(sockets, i)[2]:close()
		else
			i = i + 1
		end
	end
end
