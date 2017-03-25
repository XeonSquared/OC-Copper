-- Postprocessor
local lastchar = " "
local text = io.read("*a")

text = "\n" .. text

-- the most important step: everything assumes \n
text = text:gsub("\r", "")

-- tabs are always useless.
-- get rid of them *before* removing comments so indented comments also get scrubbed.
text = text:gsub("\t", "")

text = text:gsub("\n%-%-[^\n]+", "")

-- This is run after comment removal so that comments can be re-added.
text = text:gsub("\n%%[^\n]+", function(s)
	return "\n" .. s:sub(3)
end)
local otext = text
local function pass()
	text = text:gsub(".\n+.", function(i)
		local l = i:sub(1, 1) .. i:sub(#i)
		if not l:match("[^%(%)%{%}%,].") then
			return l
		end
		return i:sub(1, 1) .. "\n" .. i:sub(#i)
	end)
end
pass()
while otext ~= text do
	otext = text
	pass()
end
-- Final processing
text = text:gsub("^\n+", ""):gsub("\n+$", "")
io.write(text)
