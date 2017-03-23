-- I, 20kdc, release this into the public domain.
-- No warranty is provided, implied or otherwise.

-- Controller for objects following the 'IoT protocol'
-- (see provided microcontroller source for a lightweight OC implementation)

local occure = require("occure")
local event = require("event")
local args = {...}
local cmdinfo = {
	["help"] = {"Lists the commands"},
	["discover"] = {"Sends a packet on the discovery port to a given address", "target"},
	["get"] = {"Gets a value", "target", "index"},
	["set"] = {"Sets a value", "target", "index", "data"},
	["invoke"] = {"Runs an action", "target", "index", "data"}
}

local function packet(tp, idx, data)
	return string.char(idx + (tp * 64)) .. data
end

local didGet = false
local getTarg = 0
local function getHelper(tp, tfrom, tto, p, d, u)
	if tp ~= "copper_packet" then return end
	if p == 4 then
		if tto == occure.getHostname() then
			if d:sub(1, 1) == packet(3, getTarg, "") then
				print(d:sub(2))
				didGet = true
			end
		end
	end
end

local function displayDisc(d)
	local types = {
		[0] = "void",
		[0x40] = "void=",
		[0x80] = "action(void)",
		[1] = "string",
		[0x41] = "string=",
		[0x81] = "action(string)",
		[2] = "boolean",
		[0x42] = "boolean=",
		[0x82] = "action(boolean)",
		[3] = "float",
		[0x43] = "float=",
		[0x83] = "action(float)",
		[4] = "descriptor",
		[0x44] = "descriptor=",
		[0x84] = "action(descriptor)",
	}
	while #d > 7 do
		local tp = d:byte()
		local n = types[tp] or ("unknown " .. tp)
		print(" " .. d:sub(2, 8) .. ": " .. n)
		d = d:sub(9)
	end
end
local function discHelper(tp, tfrom, tto, p, d, u)
	if tp ~= "copper_packet" then return end
	if p == 4 then
		if tto == occure.getHostname() then
			if d:byte() == 0xC0 then
				-- Discovery response.
				print("\"" .. tfrom .. "\"")
				displayDisc(d:sub(2))
			end
		end
	end
end

local commands = {
	["help"] = function ()
		for k, v in pairs(cmdinfo) do
			print(k .. ": " .. v[1])
			for i = 2, #v do
				print(" " .. v[i])
			end
		end
	end,
	["discover"] = function (target)
		occure.output(target, 1, "", true)
		event.listen("copper_packet", discHelper)
		pcall(os.sleep, 10)
		event.ignore("copper_packet", discHelper)
	end,
	["get"] = function (target, index)
		index = tonumber(index)
		local ack = false
		getTarg = index
		didGet = false
		occure.output(target, 4, packet(0, index, ""), false, function() ack = true end)
		event.listen("copper_packet", getHelper)
		local safety = 0
		while (not didGet) and (safety < 30) do
			os.sleep(1)
			safety = safety + 1
		end
		event.ignore("copper_packet", getHelper)
		if not didGet then
			if ack then
				print("ACK'd but no response - bad parameters likely.")
			else
				print("Didn't get any response, not even an ACK.")
			end
		end
	end,
	["set"] = function (target, index, data)
		index = tonumber(index)
		local complete = nil
		occure.output(target, 4, packet(1, index, data), false, function() complete = "acknowledged!" end, function() complete = "unacknowledged :(" end)
		while not complete do
			os.sleep(1)
		end
		print(complete)
	end,
	["invoke"] = function (target, index, data)
		index = tonumber(index)
		local complete = nil
		occure.output(target, 4, packet(2, index, data), false, function() complete = "acknowledged!" end, function() complete = "unacknowledged :(" end)
		while not complete do
			os.sleep(1)
		end
		print(complete)
	end
}
if not commands[args[1]] then error("No such command - try 'iot-mgr help'") end
if #args ~= #cmdinfo[args[1]] then error("Parameter count mismatch.") end
commands[args[1]](select(2, table.unpack(args)))
