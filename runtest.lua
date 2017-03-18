-- Load testnet
local nodes = {}
local nodenames = {}
loadfile("testnet.lua")(function (n)
	table.insert(nodes, {})
	table.insert(nodenames, n)
end, function (a, b)
	table.insert(nodes[a], b)
	table.insert(nodes[b], a)
end)

-- Start testing
require("culib")
