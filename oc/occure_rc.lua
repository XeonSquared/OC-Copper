--[[
To the extent possible under law, Skye has waived all copyright and related or neighboring rights to this file. This file is published from: United Kingdom. 
--]]

-- This file goes into /etc/rc.d
-- To set this to autostart, it must be added to the enabled list
-- The hostname must be set using `occure = "your_hostname_here"`

function start(hostname)
  if type(hostname) == 'table' then
    hostname = hostname[1]
  end
  
  local shell = require('shell')
  local occure = shell.resolve('occure', 'lua')
  if occure then
    local ok, res = shell.execute(occure, _G, args)
    if not ok then
      error(res)
    end
  end
end
