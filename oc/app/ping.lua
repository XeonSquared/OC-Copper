local occure = require("occure")
local computer = require("computer")
local event = require("event")

local args = {...}
local startTime = computer.uptime()
local completed = 0
for _, v in ipairs(args) do
	occure.output(v, 0, "", false, function ()
		print("Ping response from " .. v .. " @ " .. (computer.uptime() - startTime))
		completed = completed + 1
	end, function ()
		print("Gave up trying to ping " .. v)
		completed = completed + 1
	end)
end

while completed < #args do
	event.pull(5)
end
