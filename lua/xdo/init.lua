---@module 'xdo'

local M = {}

--- hello_world example as starting point
---
--- @param content string the content to print out.
--- @return boolean res if print finished
function M.hello_world(content)
  print(content)
  return true
end

return M
