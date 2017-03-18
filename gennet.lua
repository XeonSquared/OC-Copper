-- Generate connected network where all nodes are connected.
-- Saves graph to "netref.dot", outputs lua tables to stdout.

local nodes = {}
local wordsA = {
	"changing",
	"ponderous",
	"intriguing",
	"bright",
	"solitudial",
	"nuanced"
}
local wordsB = {
	"fontaine",
	"marple",
	"poirot",
	"pinkie",
	"sparks",
	"twi"
}
for i = 1, #wordsA do
	for j = 1, #wordsB do
		table.insert(nodes, wordsA[i] .. "_" .. wordsB[j])
	end
end

local connections = {}
for i = 1, #nodes do
	connections[i] = {}
	connections[i][i] = true
end

-- Recursive algorithm.
-- It will always come to the right answer, though.
-- (But definitely wouldn't ever return the fastest route.)
local function canRoute(i, j, avoid)
	if i == j then return true end
	if avoid[i] then return false end
	avoid[i] = true
	for p = 1, #nodes do
		if connections[i][p] then
			if canRoute(p, j, avoid) then
				return true
			end
		end
	end
	return false
end

local function ensureRoute(i, j)
	while not canRoute(i, j, {}) do
		local a, b = math.random(#nodes), math.random(#nodes)
		connections[a][b] = true
		connections[b][a] = true
	end
end

print("return function (declare, connect)")
for i = 1, #nodes do
	-- Perform declaration here so next pass can do connections
	print(" declare(\"" .. nodes[i] .. "\")")
	for j = i + 1, #nodes do
		ensureRoute(i, j)
	end
end

local dot = io.open("netref.dot", "w")
dot:write("graph \"Test Network Reference Graph\" {\n")
-- Notably this is a destructive process (to prevent backwards links)
for i = 1, #nodes do
	for p = 1, #nodes do
		if (p ~= i) and connections[i][p] then
			print(" connect(" .. i .. ", " .. p .. ")")
			dot:write(" " .. nodes[i] .. " -- " .. nodes[p] .. ";\n")
			connections[p][i] = false
		end
	end
end
dot:write("}")
dot:close()
print("end")
