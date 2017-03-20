-- I, 20kdc, release this into the public domain.
-- No warranty is provided, implied or otherwise.

-- 'Copper' networking implementation - encode/decode
-- Notably, it's fine that culib relies on the hops byte being the first byte,
--  because culib is supposed to know the protocol anyway,
--  and thus can rely on things like that.
-- YOU, on the other hand, cannot -
--  relib doesn't know or care about protocol internals, for example,
--  short of some "convenient" nudging of relib header size and maximum Copper data packet size.

local function encodeName(name)
	if name:len() > 256 then error("Bad name (l>256)") end
	if name == "" then error("No name") end
	return string.char(name:len() - 1) .. name
end
local function decodeName(message)
	if message:len() < 2 then return end
	local nlen = message:byte(1) + 1
	local fnam = message:sub(2, nlen + 1)
	return fnam, message:sub(nlen + 2)
end

local function decodeNoHops(data)
	local src, data = decodeName(data)
	if not src then return end
	local dst, data = decodeName(data)
	if not dst then return end
	return src, dst, data
end

return {
	encode = function (hops, src, dst, data)
		return string.char(hops) .. encodeName(src) .. encodeName(dst) .. data
	end,
	decode = function (d)
		if d:len() < 3 then return end
		return d:byte(1), decodeNoHops(d:sub(2))
	end,
	decodeNoHops = decodeNoHops
}
