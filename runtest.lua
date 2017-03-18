-- Load testnet
local culib = require("culib")

local nodes = {}
local nodeconnect = {}
local nodenames = {}

local systime = 0
local function getsystime()
	return systime / 10
end

local queuedCalls = {}
local function queueSend(n, v, data)
	--print("transmit", n, v, data)
	table.insert(queuedCalls, function ()
		nodes[v].input(n, data)
	end)
end

local statSD = 0
local statPT = 0

loadfile("testnet.lua")()(function (n)
	local conn = {}
	local nodeidx = (#nodes) + 1
	table.insert(nodes, culib(n, function (node, data)
		if node then
			for _, v in ipairs(conn) do
				if v == node then
					queueSend(nodeidx, v, data)
					return
				end
			end
			error(nodeidx .. " -> " .. node .. " not directly possible")
		else
			for _, v in ipairs(conn) do
				queueSend(nodeidx, v, data)
			end
		end
	end, function (nfrom, nto, data)
		if nto == n then
			if data:sub(1, 1) == "T" then
				nodes[nodeidx].output(n, nfrom, "R" .. data)
			else
				statSD = statSD + 1
			end
		else
			statPT = statPT + 1
		end
	end, getsystime))
	table.insert(nodeconnect, conn)
	table.insert(nodenames, n)
end, function (a, b)
	table.insert(nodeconnect[a], b)
	table.insert(nodeconnect[b], a)
end)

-- Start testing

local targetables = {}
local targetableCount = 10
for i = 1, targetableCount do
	targetables[i] = math.random(#nodes)
end

local function generateMessage()
	local na = 1
	local nb = 1
	while na == nb do
		na = targetables[math.random(#targetables)]
		nb = targetables[math.random(#targetables)]
	end
	nodes[na].output(nodenames[na], nodenames[nb], "T" .. tostring(math.random()))
end

-- ~Once every 5 seconds, think a polling script
local generateEvery = math.floor(50 / targetableCount)
local generateCount = 10000
while (generateCount > 0) or (#queuedCalls > 0) do
	if (systime % generateEvery) == 0 then
		if generateCount > 0 then
			generateMessage()
			generateCount = generateCount - 1
		end
	end
	local qc = queuedCalls
	queuedCalls = {}
	for _, v in ipairs(nodes) do
		v.refresh()
	end
	for _, v in ipairs(qc) do
		v()
	end
	--print("run iteration, " .. #qc .. " calls")
	systime = systime + 1
end

print(#nodes, statSD, statPT)
