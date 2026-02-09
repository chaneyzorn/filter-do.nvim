local M = {}
local C = require("filter_do.config")

--- wrapping vim.ui.select as async function
---@async
---@generic T
---@param items T[]
---@param opts table
---@return T | nil
function M.ui_select(items, opts)
  opts = opts or { prompt = "Select" }
  local co = coroutine.running()
  local ui_select_fn = C.ui_select_fn

  ui_select_fn(items, opts, function(choice, _)
    if coroutine.status(co) == "suspended" then
      coroutine.resume(co, choice)
    end
  end)

  return coroutine.yield()
end

return M
